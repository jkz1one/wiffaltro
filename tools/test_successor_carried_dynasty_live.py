#!/usr/bin/env python3
"""Drive one real carried Dynasty round, retaining authentic per-game checkpoints."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
import assemble_successor
from test_successor_dynasty_post_purchase import SLOT, digest, install, read_slots
from test_successor_schedule_wiring import environment

TEST = 'successor_carried_dynasty_live'
FIXTURE = ('086d458dacb9aad63307c0217545889a50b69559820dadecad3503c75234fc4a',
           'e5748c3fc33da6702e5ced51a38a58796f5a03e1cfbd05642a0eef915da88f27')
PHASES = ('human', 'npc-one', 'npc-two', 'settle', 'cold')
SHAPE = ((0, 0, -1), (0, 0, 0), (0, 0, 1), (0, 0, 2), (3, 2, -1), (3, 2, -1))
EXPECTED_ACTION = ('human-', 'npc-', 'npc-', 'settlement-', 'carried-cold-complete')
SOURCE = 'source-dynasty-owner.json'


def run(project, godot, home, args, path, limit):
    command = [godot, '--headless', '--fixed-fps', '60', '--path', str(project), *args]
    with path.open('xb') as log:
        result = subprocess.run(command, env=environment(home), stdout=log,
                                stderr=subprocess.STDOUT, timeout=limit, check=False)
    output = path.read_text()
    for line in output.splitlines():
        if line.startswith(('Godot Engine', 'FAIL:', 'SCRIPT ERROR', 'ERROR:', 'OWNED_CAREER_PLAY_STEP_DONE')):
            print(line, flush=True)
    assert result.returncode == 0 and 'SCRIPT ERROR:' not in output
    return output


def consistent(payload, original, shape):
    assert payload['active'] == 'dynasty' and payload['ordinal'] == 2 and payload['status'] == 'active'
    assert {k: v for k, v in payload.items() if k != 'dynasty'} == {
        k: v for k, v in original.items() if k != 'dynasty'
    }
    state, physical = payload['dynasty']['state'], payload['dynasty']['physical']
    pending = physical['pending']
    results, archived, pending_count = shape
    assert (len(state['results']), len(physical['reports']),
            len(pending['reports']) if pending else -1) == shape
    assert len(state['player_results']) == results // 3 and state['round_index'] == results // 3
    if results:
        assert len({row['id'] for row in state['results']}) == results
    if pending_count > 0:
        assert len({row['fixture'] for row in pending['reports']}) == pending_count
    return archived


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--carried-home', type=Path, required=True, help='Exact isolated output of the earlier abandon/carry fixture test')
    parser.add_argument('--stage-dir', type=Path, required=True, help='Dedicated resumable destination; never choose a real save directory')
    parser.add_argument('--through', choices=PHASES, default='cold')
    parser.add_argument('--godot', default='godot')
    opts = parser.parse_args()
    godot = shutil.which(opts.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo, root = Path(__file__).resolve().parents[1], opts.stage_dir.resolve()
    origin = read_slots(opts.carried_home.resolve())
    assert all(origin) and tuple(map(digest, origin)) == FIXTURE
    original = json.loads(origin[0])
    consistent(original, original, SHAPE[0])
    project, career = root / 'project', root / 'career'
    installed_source = (career / SLOT).parent / SOURCE
    if not root.exists():
        root.mkdir(mode=0o700)
        install(career, *origin)
        with installed_source.open('xb') as stream:
            stream.write(origin[0])
        dependencies = ('tests/successor_dynasty_play.gd', 'tests/successor_dynasty_carried_play.gd')
        assemble_successor.assemble(repo, project, tests=dependencies, dynasty_owner=True)
        (project / 'tests' / (TEST + '.gd')).write_bytes((repo / 'tests' / (TEST + '.gd.txt')).read_bytes())
        (project / 'tests' / (TEST + '.tscn')).write_text(
            '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
            + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
        run(project, godot, root / 'import', ['--editor', '--quit'], root / 'import.log', 240)
        (root / 'source.sha256').write_text(digest((repo / 'tests' / (TEST + '.gd.txt')).read_bytes()) + '\n')
    assert (root / 'source.sha256').read_text().strip() == digest((repo / 'tests' / (TEST + '.gd.txt')).read_bytes())
    assert installed_source.read_bytes() == origin[0]
    previous = FIXTURE
    for index, phase in enumerate(PHASES):
        stamp = root / (phase + '.pass.json')
        if stamp.exists():
            record = json.loads(stamp.read_bytes())
            assert record['before'] == list(previous) and record['phase'] == phase
            previous = tuple(record['after'])
            if phase == opts.through:
                return
            continue
        before = read_slots(career)
        assert tuple(map(digest, before)) == previous, 'Unstamped write: preserve and inspect before resuming'
        consistent(json.loads(before[0]), original, SHAPE[index])
        capture_directory = (career / SLOT).parent
        count = len(list(capture_directory.glob('actual120-human.json'))) + len(list(capture_directory.glob('actual120-npc-*.json')))
        assert count == min(index, 3), 'Unadmitted capture: use original authenticated recovery instead of replay'
        out = run(project, godot, career, ['res://tests/' + TEST + '.tscn', '--', 'cold' if phase == 'cold' else 'step'],
                  root / (phase + '.log'), 600)
        records = [json.loads(line.partition(': ')[2]) for line in out.splitlines()
                   if line.startswith('OWNED_CAREER_PLAY_STEP_DONE: ')]
        assert len(records) == 1 and records[0]['action'].startswith(EXPECTED_ACTION[index])
        assert 'PASS: actual carried ordinal2 ' in out
        after = read_slots(career)
        if phase == 'cold':
            assert after == before
        else:
            assert after[0] != before[0] and after[1] == before[0]
        consistent(json.loads(after[0]), original, SHAPE[index + 1])
        assert installed_source.read_bytes() == origin[0] and read_slots(opts.carried_home.resolve()) == origin
        current = tuple(map(digest, after))
        with stamp.open('x') as file:
            json.dump({'phase': phase, 'before': previous, 'after': current, 'observed': records[0]['action']}, file)
        print('STAGE', phase, records[0]['action'], *current, flush=True)
        previous = current
        if phase == opts.through:
            return


if __name__ == '__main__':
    main()
