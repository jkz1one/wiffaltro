#!/usr/bin/env python3
"""Qualify real private V4 birth/four picks and cold, without exposing play."""
import argparse
import io
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

sys.dont_write_bytecode = True
import assemble_successor
from test_successor_schedule_wiring import environment
from test_successor_pair_history_context import execute

BASE = '753c068bf7518b5f5fec96686cc643fc4f38eb14'
TEST = 'successor_hidden_paired_draft'
SLOT = 'data/godot/app_userdata/Wiffaltro/wiffaltro-common-career-v4.json'


def stage(repo, path, source, godot):
    project = path / 'project'
    assemble_successor.assemble(repo, project, dynasty_owner=True)
    (project / 'tests').mkdir(exist_ok=True)
    (project / 'tests' / (TEST + '.gd')).write_bytes(source)
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    execute([godot, '--headless', '--editor', '--path', str(project), '--quit'], environment(path / 'import'), 180)
    return project


def proof(project, case, profile, godot):
    result = []
    for mode in ('birth', 'cold'):
        output = execute([godot, '--headless', '--path', str(project),
                          'res://tests/' + TEST + '.tscn', '--', mode, profile],
                         environment(case), 300)
        if 'HIDDEN_DRAFT_PASS' not in output:
            raise RuntimeError('Missing native qualification: ' + profile + ' ' + mode)
        result += [line for line in output.splitlines() if line.startswith('SNAPSHOT ')]
        if mode == 'birth':
            before = (case / SLOT).read_bytes()
        elif (case / SLOT).read_bytes() != before:
            raise RuntimeError('Cold reopen changed slot')
    return result, before


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    source = (repo / 'tests' / (TEST + '.gd.txt')).read_bytes()
    with tempfile.TemporaryDirectory(prefix='wiffaltro-private-draft-') as tmp:
        root = Path(tmp)
        project = stage(repo, root / 'current', source, godot)
        proof(project, root / 'paired', 'paired', godot)
        ordinary = proof(project, root / 'ordinary', 'standard', godot)
        base = root / 'baseline-source'
        base.mkdir()
        archive = subprocess.check_output(['git', 'archive', '--format=tar', BASE], cwd=repo)
        with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
            tar.extractall(base, filter='data')
        subprocess.run(['git', 'init', '-q', str(base)], check=True)
        subprocess.run(['git', 'add', '--', 'src', 'project.godot'], cwd=base, check=True)
        baseline = stage(base, root / 'baseline', source, godot)
        assert ordinary == proof(baseline, root / 'baseline-ordinary', 'standard', godot)
    print('PASS: private authentic V4 draft/cold; unchanged Standard action bytes and zero paired checks')


if __name__ == '__main__':
    main()
