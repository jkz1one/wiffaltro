#!/usr/bin/env python3
"""Audit the exact rendered Linux Dynasty round; never writes a save or runs a game."""
import argparse
import hashlib
import json
from pathlib import Path

ELF = '2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0'
PCK = 'fd15da2febe465c2fb8e42f6642dfde1886ddc6e83cd66b7869a7c2d04829617'
PENDING = '7209d7658f1bb92f1e5c459896e2e9794cabe96de4f33436a2be04e4ed5e96ac'
PAID = '99833b911cebd56d269b78ca0a641ded20d18a5495faefe9085cbd24ee931d67'
SLOT = 'wiffaltro-common-career-v4.json'


def verify(path, expected):
    assert path.is_file() and not path.is_symlink(), path.name
    value = path.read_bytes()
    assert hashlib.sha256(value).hexdigest() == expected, path.name
    return value


def rewards(dynasty):
    clubs = {0: dynasty['build']}
    clubs.update({int(c): v['build'] for c, v in dynasty['opponents']['clubs'].items()})
    return {c: b['bank']['_state']['rewards'] for c, b in clubs.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True, help='Exact audited Linux two-file build')
    parser.add_argument('--source-slots', type=Path, required=True,
                        help='Original isolated synthetic carried Dynasty source proof')
    parser.add_argument('--rendered-slots', type=Path, required=True,
                        help='Separate engineering profile after rendered settlement and cold reopen')
    args = parser.parse_args()
    assert args.source_slots.resolve() != args.rendered_slots.resolve()
    verify(args.package / 'Wiffaltro.x86_64', ELF)
    verify(args.package / 'Wiffaltro.pck', PCK)
    source = verify(args.source_slots / SLOT, PAID)
    pending = verify(args.source_slots / (SLOT + '.bak'), PENDING)
    assert verify(args.rendered_slots / SLOT, PAID) == source
    assert verify(args.rendered_slots / (SLOT + '.bak'), PENDING) == pending
    assert not (args.rendered_slots / (SLOT + '.tmp')).exists()
    before, after = map(json.loads, (pending, source))
    assert {k: v for k, v in before.items() if k != 'dynasty'} == {
        k: v for k, v in after.items() if k != 'dynasty'
    }
    assert before['active'] == after['active'] == 'dynasty'
    assert before['ordinal'] == after['ordinal'] == 2
    old, new = before['dynasty'], after['dynasty']
    assert old['state']['round_index'] == 0 and old['state']['results'] == []
    assert rewards(old) == {i: {} for i in range(6)}
    assert new['state']['round_index'] == 1 and len(new['state']['player_results']) == 1
    assert new['physical']['pending'] == {} and new['physical']['cursor'] == 2
    reports = old['physical']['pending']['reports']
    assert len(reports) == 2 and new['physical']['reports'] == reports
    expected = {}
    results = []
    for match in new['state']['results']:
        ident = str(int(match['id']))
        away, home = (int(match[k]) for k in ('away', 'home'))
        runs = tuple(int(match[key]) for key in ('away_runs', 'home_runs'))
        assert away not in expected and home not in expected and away != home and runs[0] != runs[1]
        expected[away] = {ident: runs[0] > runs[1]}
        expected[home] = {ident: runs[1] > runs[0]}
        results.append((int(ident), away, home, *runs))
    assert results == [(0, 0, 5, 9, 6), (1, 4, 1, 2, 4), (2, 2, 3, 7, 9)]
    assert set(expected) == set(range(6)) and rewards(new) == expected
    print('PASS: packaged Dynasty Season 2 advances to Round 2 with exact reports and one payout per club.')
    print('PASS: paid primary matches source, backup matches original pending, parked ordinary unchanged.')


if __name__ == '__main__':
    main()
