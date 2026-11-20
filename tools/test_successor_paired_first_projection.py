#!/usr/bin/env python3
"""Verify inactive pending projection with distinct standalone and V4 inputs."""
import argparse
import hashlib
from pathlib import Path
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import assemble_successor
from test_successor_schedule_wiring import environment
from test_successor_pair_history_context import execute

TEST = 'successor_paired_first_projection'
DIGEST = '4e6de157c90fd52ee71a5092f10b5a683edb88477f423677c3f55836ed6c57a0'
DATA = 'data/godot/app_userdata/Wiffaltro'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    source = args.fixture_stage.resolve()
    if not source.name.startswith('wiffaltro-signature-'):
        parser.error('Requires the retained isolated General stage')
    evidence = source / DATA / 'doubleheader-evidence/0005.json'
    data = evidence.read_bytes()
    if hashlib.sha256(data).hexdigest() != DIGEST:
        parser.error('Not the exact authentic frozen human boundary')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='wiffaltro-first-projection-') as tmp:
        stage = Path(tmp)
        project = stage / 'project'
        record = assemble_successor.assemble(repo, project, dynasty_owner=True)
        assert all(hashlib.sha256((project / p).read_bytes()).hexdigest() == h for p, h in record['files'].items())
        (project / 'tests').mkdir(exist_ok=True)
        (project / 'tests' / (TEST + '.gd')).write_bytes((repo / 'tests' / (TEST + '.gd.txt')).read_bytes())
        (project / 'tests' / (TEST + '.tscn')).write_text(
            '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
            + TEST + '.gd" id="1"]\n[node name="ProjectionProof" type="Node"]\nscript = ExtResource("1")\n')
        execute([godot, '--headless', '--editor', '--path', str(project), '--quit'], environment(stage / 'import'), 180)
        for case in ('first', 'independent'):
            home = stage / case
            target = home / DATA / 'paired-first-projection-0005.json'
            target.parent.mkdir(parents=True)
            target.write_bytes(data)
            output = execute([godot, '--headless', '--path', str(project),
                              'res://tests/' + TEST + '.tscn'], environment(home), 240)
            assert 'PAIRED_FIRST_PROJECTION_PASS' in output
            assert target.read_bytes() == data == evidence.read_bytes()
    print('PASS: exact standalone human projection; typed V4 negative path only, no V4 positive admission')


if __name__ == '__main__':
    main()
