#!/usr/bin/env python3
"""One actual private human game and independent cold V4 pending proof."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_schedule_wiring import environment
from test_successor_pair_history_context import execute

BASE = '30ed8b12179f7d23f7d1eab2a6dab3744457f6cf'
TEST = 'successor_hidden_paired_pending'


def native(project, home, mode, godot):
    out = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                   'res://tests/' + TEST + '.tscn', '--', mode],
                  environment(home), 480)
    if 'HIDDEN_PAIRED_PENDING_PASS' not in out:
        raise RuntimeError('Missing focused pending result: ' + mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    draft_source = (repo / 'tests' / (draft.TEST + '.gd.txt')).read_bytes()
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-private-pending-'))
    print("Retained disposable local stage:", root, flush=True)
    project = draft.stage(repo, root / 'current', draft_source, godot)
    (project / 'tests' / (TEST + '.gd')).write_bytes((repo / 'tests' / (TEST + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="PendingProof" type="Node"]\nscript = ExtResource("1")\n')
    case = root / 'paired'
    native(project, case, 'play', godot)
    primary = (case / draft.SLOT).read_bytes()
    backup = Path(str(case / draft.SLOT) + '.bak').read_bytes()
    print("DURABLE PENDING SHA256=", hashlib.sha256(primary).hexdigest(), flush=True)
    native(project, case, 'cold', godot)
    assert (case / draft.SLOT).read_bytes() == primary
    assert Path(str(case / draft.SLOT) + '.bak').read_bytes() == backup
    tampered = root / 'tamper' / draft.SLOT
    tampered.parent.mkdir(parents=True)
    value = json.loads(primary)
    digest = value['ordinary']['physical']['pending']['binding']['request']
    old = ('"request":"' + digest + '"').encode()
    assert primary.count(old) == 1
    tampered.write_bytes(primary.replace(old, ('"request":"' + '0' * 64 + '"').encode(), 1))
    Path(str(tampered) + '.bak').write_bytes(backup)
    native(project, root / 'tamper', 'tamper', godot)
    draft.proof(project, root / 'paired-draft', 'paired', godot)
    current = draft.proof(project, root / 'ordinary', 'standard', godot)
    base = root / 'baseline-source'
    base.mkdir()
    archive = subprocess.check_output(['git', 'archive', '--format=tar', BASE], cwd=repo)
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
        tar.extractall(base, filter='data')
    subprocess.run(['git', 'init', '-q', str(base)], check=True)
    subprocess.run(['git', 'add', '--', 'src', 'project.godot'], cwd=base, check=True)
    prior = draft.stage(base, root / 'baseline', draft_source, godot)
    assert current == draft.proof(prior, root / 'baseline-ordinary', 'standard', godot)
    print('PASS: actual private paired human pending/cold and cp106 Standard byte parity')


if __name__ == '__main__':
    main()
