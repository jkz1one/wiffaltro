#!/usr/bin/env python3
"""Restore the inactive draft into an isolated project and test real Godot persistence.
Never launches the source checkout or reads/writes the owner's Godot user data.
The temporary evidence directory is retained, printed, and must never be published.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--expect-broken', action='store_true')
    parser.add_argument('--flow', action='store_true', help='Run draft UI and one actual native match instead of the signature-only suite')
    parser.add_argument('--round', action='store_true', help='Run actual three-game round and earned pack purchase suite')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    stage = Path(tempfile.mkdtemp(prefix='wiffaltro-signature-'))
    project = stage / 'project'
    project.mkdir()
    shutil.copytree(root / 'src', project / 'src')
    shutil.copy2(root / 'project.godot', project / 'project.godot')
    (project / 'tests').mkdir()
    names = ['successor_signature.gd', 'successor_signature.tscn']
    if args.flow or args.round:
        names += ['successor_flow.gd', 'successor_flow.tscn']
    if args.round:
        names += ['successor_round.gd', 'successor_round.tscn']
    for name in names:
        shutil.copy2(root / 'tests' / (name + '.txt'), project / 'tests' / name)
    manifest = json.loads((root / 'drafts/successor-v7/DRAFT_MANIFEST.json').read_text())
    assert len(manifest['files']) == 47
    for entry in manifest['files']:
        source = root / entry['backup_path']
        data = source.read_bytes()
        assert len(data) == entry['bytes']
        assert hashlib.sha256(data).hexdigest() == entry['sha256'], source
        target = project / entry['restore_path']
        assert target.is_relative_to(project) and not target.exists(), target
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    env = dict(os.environ, WIFFALTRO_ISOLATED_TEST='1')
    for key, directory in [('HOME', 'home'), ('XDG_DATA_HOME', 'data'),
                           ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        env[key] = str(stage / directory)
        Path(env[key]).mkdir()
    print(f'Isolated test evidence: {stage}', flush=True)
    def run(label, switches, timeout=300):
        command = [args.godot, '--headless', '--path', str(project), *switches]
        with (stage / f'{label}.log').open('w') as log:
            result = subprocess.run(command, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        output = (stage / f'{label}.log').read_text()
        if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output or 'FAIL:' in output:
            raise RuntimeError(f'{label} failed (exit {result.returncode}):\n{output[-6000:]}')
        if label != 'import' and 'PASS:' not in output:
            raise RuntimeError(f'{label} produced no success marker: {output}')
        print(f'{label}: ' + '\n'.join(line for line in output.splitlines() if 'PASS:' in line), flush=True)
    run('import', ['--editor', '--import', '--quit'])
    script = ['res://tests/successor_signature.tscn', '--']
    if args.round:
        flow = ['--fixed-fps', '60', 'res://tests/successor_round.tscn', '--']
        run('actual-round-shop', flow, timeout=1200)
        run('round-shop-cold', flow + ['reopen'], timeout=600)
    elif args.flow:
        flow = ['--fixed-fps', '60', 'res://tests/successor_flow.tscn', '--']
        run('draft-physical-flow', flow, timeout=900)
        run('draft-cold-reopen', flow + ['reopen'])
    elif args.expect_broken:
        run('original-failure', script + ['broken'])
    else:
        run('create-save', script)
        run('cold-reopen', script + ['reopen'])


if __name__ == '__main__':
    main()
