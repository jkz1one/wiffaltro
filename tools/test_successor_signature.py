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
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--expect-broken', action='store_true')
    mode.add_argument('--flow', action='store_true', help='Run draft UI and one actual native match instead of the signature-only suite')
    mode.add_argument('--round', action='store_true', help='Run actual three-game round and earned pack purchase suite')
    mode.add_argument('--shop-fixture', type=Path, help='Read-only previously earned isolated round save; copied to a new isolated test directory')
    mode.add_argument('--recruit', action='store_true', help='Run controlled build-ledger recruitment and cold replay, not actual-game qualification')
    mode.add_argument('--dugout', action='store_true', help='Run live Dugout admission/request/cold suite, not completed gameplay')
    mode.add_argument('--dugout-round', action='store_true', help='Run actual live Dugout human game, cold pending resume, AI round and earned pack')
    mode.add_argument('--dugout-pending-fixture', type=Path, help='Audit a read-only isolated actual human+one-AI pending checkpoint')
    mode.add_argument('--identity', action='store_true', help='Check local signature helper equivalence and scoped timings')
    mode.add_argument('--career-fixture', type=Path, help='Capture and cold-verify career evidence from an isolated actual settled checkpoint')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    stage = Path(tempfile.mkdtemp(prefix='wiffaltro-signature-'))
    project = stage / 'project'
    project.mkdir()
    shutil.copytree(root / 'src', project / 'src')
    shutil.copy2(root / 'project.godot', project / 'project.godot')
    (project / 'tests').mkdir()
    names = ['successor_signature.gd', 'successor_signature.tscn']
    if args.flow or args.round or args.shop_fixture:
        names += ['successor_flow.gd', 'successor_flow.tscn']
    if args.round or args.shop_fixture:
        names += ['successor_round.gd', 'successor_round.tscn', 'successor_shop.gd', 'successor_shop.tscn']
    if args.recruit:
        names += ['successor_recruit.gd', 'successor_recruit.tscn']
    if args.dugout or args.dugout_round or args.dugout_pending_fixture or args.identity or args.career_fixture:
        names += ['successor_dugout_live.gd', 'successor_dugout_live.tscn', 'successor_dugout_round.gd', 'successor_dugout_round.tscn', 'successor_dugout_integrity.gd', 'successor_dugout_integrity.tscn']
    if args.identity:
        names += ['successor_identity.gd', 'successor_identity.tscn']
    if args.career_fixture:
        names += ['successor_career.gd', 'successor_career.tscn']
    for name in names:
        shutil.copy2(root / 'tests' / (name + '.txt'), project / 'tests' / name)
    manifest = json.loads((root / 'drafts/successor-v7/DRAFT_MANIFEST.json').read_text())
    assert len(manifest['files']) == 47
    entries = manifest['files'] + manifest.get('additions', [])
    if args.dugout or args.dugout_round or args.dugout_pending_fixture or args.identity or args.career_fixture:
        league_manifest = json.loads((root / 'drafts/successor-league-v1/DRAFT_MANIFEST.json').read_text())
        entries += league_manifest['files'] + league_manifest.get('additions', [])
    if args.career_fixture:
        career_manifest = json.loads((root / 'drafts/successor-career-v1/DRAFT_MANIFEST.json').read_text())
        entries += career_manifest['files']
    assert len({entry['restore_path'] for entry in entries}) == len(entries)
    for entry in entries:
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
    if args.career_fixture:
        source = args.career_fixture.resolve()
        assert source.is_file() and source.name == 'successor-dugout-live-v7-r1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-season.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        origin = next(parent for parent in source.parents if parent.name.startswith('wiffaltro-signature-'))
        pending = origin / 'retained-pending-1' / source.name
        if pending.is_file():
            shutil.copy2(pending, destination.with_name('source-pending.json'))
        run('career-evidence', ['res://tests/successor_career.tscn', '--'], timeout=1800)
        run('career-evidence-cold', ['res://tests/successor_career.tscn', '--', 'reopen'], timeout=900)
        return
    if args.identity:
        run('local-identity', ['res://tests/successor_identity.tscn', '--'], timeout=900)
        return
    if args.dugout_pending_fixture:
        source = args.dugout_pending_fixture.resolve()
        assert source.is_file() and source.name == 'successor-dugout-live-v7-r1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        destination = stage / 'data/godot/app_userdata/Wiffaltro' / source.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        run('live-pending-integrity', ['res://tests/successor_dugout_integrity.tscn', '--'], timeout=1200)
        run('live-pending-integrity-cold', ['res://tests/successor_dugout_integrity.tscn', '--', 'reopen'], timeout=900)
        return
    if args.dugout_round:
        scene = ['--fixed-fps', '60', 'res://tests/successor_dugout_round.tscn', '--']
        run('live-dugout-human', scene + ['human-only'], timeout=1200)
        run('live-dugout-resume-round', scene + ['resume-round'], timeout=1800)
        run('live-dugout-round-cold', scene + ['reopen'], timeout=900)
        return
    if args.dugout:
        run('live-dugout', ['res://tests/successor_dugout_live.tscn', '--'], timeout=900)
        run('live-dugout-cold', ['res://tests/successor_dugout_live.tscn', '--', 'reopen'], timeout=600)
        return
    if args.recruit:
        run('controlled-recruit', ['res://tests/successor_recruit.tscn', '--'], timeout=600)
        run('controlled-recruit-cold', ['res://tests/successor_recruit.tscn', '--', 'reopen'], timeout=600)
        return
    if args.shop_fixture:
        source = args.shop_fixture.resolve()
        assert source.is_file() and source.name == 'successor-standard-v7.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts), 'Only explicitly isolated prior test evidence is accepted'
        destination = stage / 'data/godot/app_userdata/Wiffaltro/successor-standard-v7.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        run('full-shop', ['res://tests/successor_shop.tscn', '--'], timeout=1200)
        run('full-shop-cold', ['res://tests/successor_shop.tscn', '--', 'reopen'], timeout=600)
        return
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
