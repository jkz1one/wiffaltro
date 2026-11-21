#!/usr/bin/env python3
"""Check real Dynasty/ordinary switching after a paid pack, from existing generated evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

sys.dont_write_bytecode = True
import assemble_successor
from test_successor_schedule_wiring import environment

TEST = 'successor_dynasty_post_purchase'
SLOT = Path('data/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json')
EVIDENCE_SHA = 'c89191425db3a7f98446f4529e342ff17959b21aa3aa71df01b30bc058750e56'
MEMBER = 'candidate-data/godot/app_userdata/Wiffaltro/dynasty-play-game-evidence/0010.json'
PAID = (1_618_626, '681e74cc286c2a5ab6592f9ca5645cfb970d125c3933bcd9f502cf11705d0165')
PENDING = (1_618_134, 'fe0215435f5a5d20343993225a3ee9a7bbda56fdfb6d14d47f33d7f954803de5')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def evidence(path):
    assert path.stat().st_size == 683_459 and digest(path.read_bytes()) == EVIDENCE_SHA
    with zipfile.ZipFile(path, 'r') as archive:
        pair = []
        for name, (size, sha) in ((MEMBER, PAID), (MEMBER + '.bak', PENDING)):
            assert archive.namelist().count(name) == 1 and archive.getinfo(name).file_size == size
            data = archive.read(name)
            assert digest(data) == sha
            pair.append(data)
    return pair


def read_slots(home):
    slot = home / SLOT
    backup = Path(str(slot) + '.bak')
    assert not Path(str(slot) + '.tmp').exists()
    return slot.read_bytes(), backup.read_bytes() if backup.exists() else None


def install(home, data, backup=None):
    slot = home / SLOT
    slot.parent.mkdir(mode=0o700, parents=True)
    with slot.open('xb') as file:
        file.write(data)
    if backup is not None:
        with Path(str(slot) + '.bak').open('xb') as file:
            file.write(backup)


def assert_preserved(original, updated, active):
    before, after = json.loads(original), json.loads(updated)
    assert after['active'] == active
    # Compare entire persisted reports, lineups, Builds, wallets, histories and
    # shared/individual metadata. JSON whole-number spelling is not state.
    assert {k: v for k, v in before.items() if k != 'active'} == {
        k: v for k, v in after.items() if k != 'active'
    }


def qualify(root, repo, godot, paid, pending):
    project = root / 'project'
    assemble_successor.assemble(repo, project, dynasty_owner=True)
    (project / 'tests').mkdir(exist_ok=True)
    (project / 'tests' / (TEST + '.gd')).write_bytes((repo / 'tests' / (TEST + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')

    def run(home, arguments, label, budget):
        with (root / (label + '.log')).open('xb') as log:
            result = subprocess.run([godot, '--headless', '--path', str(project), *arguments],
                                    env=environment(home), stdout=log, stderr=subprocess.STDOUT,
                                    timeout=budget, check=False)
        output = (root / (label + '.log')).read_text()
        if label != 'import' or result.returncode:
            print(output, end='', flush=True)
        assert result.returncode == 0, label
        assert 'SCRIPT ERROR:' not in output and 'Parse Error:' not in output, label
        if label != 'import':
            assert 'DYNASTY_POST_PURCHASE_PASS ' + label in output

    run(root / 'import', ['--editor', '--quit'], 'import', 240)
    isolated_pending, career = root / 'paid-pending', root / 'career-round-trip'
    install(isolated_pending, pending)
    install(career, paid, pending)
    scene = 'res://tests/' + TEST + '.tscn'
    run(isolated_pending, [scene, '--', 'pending'], 'pending', 120)
    assert read_slots(isolated_pending) == (pending, None)
    run(career, [scene, '--', 'park'], 'park', 180)
    parked, previous = read_slots(career)
    assert previous == paid
    assert_preserved(paid, parked, 'ordinary')
    run(career, [scene, '--', 'resume'], 'resume', 180)
    returned, previous = read_slots(career)
    assert previous == parked
    assert_preserved(paid, returned, 'dynasty')
    run(career, [scene, '--', 'cold'], 'cold', 120)
    assert read_slots(career) == (returned, parked)
    print('PASS: original receipts and both full seasons retained; no game, charge, or award repeated')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True, help='Previously archived generated evidence; opened read-only')
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    paid, pending = evidence(args.evidence)
    with tempfile.TemporaryDirectory(prefix='wiffaltro-dynasty-post-purchase-') as tmp:
        qualify(Path(tmp), Path(__file__).resolve().parents[1], godot, paid, pending)


if __name__ == '__main__':
    main()
