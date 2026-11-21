#!/usr/bin/env python3
"""Recheck exact synthetic v98 reports without replaying either worker game."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
from build_successor_engineering_linux import EDITOR_SHA, PACK_BROAD_SHA, USER_DIR
from test_successor_schedule_wiring import environment

PENDING = 'a13bfe2f5f902506bf502443b9887d82b1b246a32b038e4de4c3416a77cd6a3d'
ONE_REPORT = '3af97047d4e21b6103179c9206e659b0a45d5f534a17c0d294bef5eba501df51'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engineering-build', type=Path, required=True)
    parser.add_argument('--generated-pending', type=Path, required=True,
                        help='Exact native synthetic checkpoint with both accepted worker reports and adjoining .bak')
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    editor = args.godot.resolve()
    assert digest(editor.read_bytes()) == EDITOR_SHA
    build = args.engineering_build.resolve()
    pack = build / 'package/Wiffaltro.pck'
    meta = json.loads((build / 'result.json').read_bytes())
    assert digest(pack.read_bytes()) == meta['pck'] and meta['pack_broad_sha256'] == PACK_BROAD_SHA
    original = args.generated_pending.resolve()
    older = original.with_suffix(original.suffix + '.bak')
    pending, one_report = original.read_bytes(), older.read_bytes()
    assert digest(pending) == PENDING and digest(one_report) == ONE_REPORT
    out = args.output.resolve()
    out.mkdir(mode=0o700)
    empty = out / 'empty'
    empty.mkdir()
    repo = Path(__file__).resolve().parents[1]
    external = out / 'audit.gd'
    external.write_bytes((repo / 'tests/successor_packaged_legacy_settlement.gd.txt').read_bytes())
    ss = repo / 'src/gameplay/season/season_save_operations_1.gd'
    assert ss.read_bytes() == (build / 'project' / ss.relative_to(repo)).read_bytes()
    common = [str(editor), '--headless', '--audio-driver', 'Dummy']
    results = []
    for target, switches in (
        ('source', ['--path', str(build / 'project')]),
        ('pck', ['--path', str(empty), '--main-pack', str(pack)]),
    ):
        env = environment(out / target)
        slotdir = Path(env['XDG_DATA_HOME']) / USER_DIR
        slotdir.mkdir()
        slot = slotdir / 'cp155-generated-season.json'
        bak = slot.with_suffix('.json.bak')
        slot.write_bytes(pending)
        bak.write_bytes(one_report)
        for phase, marker in (
            ('project', 'LEGACY_ROUND_CORRUPT_EVIDENCE_REJECTED'),
            ('cold', 'COLD_LEGACY_ROUND_SIX_PAID_ONCE'),
        ):
            projected = out / f'{target}-projected.json'
            log = out / f'{target}-{phase}.log'
            print(f'Running {target} {phase}', flush=True)
            with log.open('xb') as output:
                result = subprocess.run([*common, *switches, '--script', str(external), '--', phase, str(projected)],
                                        cwd=empty, env=env, stdout=output,
                                        stderr=subprocess.STDOUT, timeout=600)
            reply = log.read_text()
            if result.returncode or 'SCRIPT ERROR:' in reply or 'ERROR:' in reply or marker not in reply:
                raise RuntimeError(f'{target} {phase} failed:\n{reply}')
            assert not slot.with_suffix('.json.tmp').exists()
            if phase == 'project':
                assert slot.read_bytes() == pending and bak.read_bytes() == one_report
                settled = projected.read_bytes()
                slot.write_bytes(settled)
                bak.write_bytes(pending)
            else:
                assert slot.read_bytes() == settled and bak.read_bytes() == pending
        results.append(settled)
    assert results[0] == results[1] and original.read_bytes() == pending and older.read_bytes() == one_report
    print('PASS: original worker reports; three fixtures and one reward per club; strict source/PCK parity and cold reopen.')
    print('Paid checkpoint SHA-256', digest(results[0]))


if __name__ == '__main__':
    main()
