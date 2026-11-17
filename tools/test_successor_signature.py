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
    mode.add_argument('--owner', action='store_true', help='Verify genuine fresh owner, all initial access and draft-only cold replay')
    mode.add_argument('--owner-round', action='store_true', help='Run genuine owned human game, cold pending resume, actual AI settlement and earned shop')
    mode.add_argument('--owner-performance-fixture', type=Path, help='Compare baseline and resource-retaining facade on an isolated actual owned checkpoint')
    mode.add_argument('--completion-fixture', type=Path, help='Verify pure successor metrics and synthetic receipt policy against actual owned-round evidence')
    mode.add_argument('--assets-fixture', type=Path, help='Verify successor asset basis and synthetic award policies against isolated actual owned evidence')
    mode.add_argument('--terminal-policy', action='store_true', help='Synthetic terminal outcome policy checks; not physical completion')
    mode.add_argument('--terminal-birth', action='store_true', help='Verify additive terminal owner birth and cold draft replay only')
    mode.add_argument('--terminal-round', action='store_true', help='Verify actual round/shop under additive terminal owner; not full-season completion')
    mode.add_argument('--terminal-season', action='store_true', help='Play a full actual first owned season, one cold durable boundary per process')
    mode.add_argument('--recapture-fixture', type=Path, help='Measure private transaction-local row reuse against isolated actual112 evidence')
    mode.add_argument('--history-fixture', type=Path, help='Verify pure closed-prefix legacy109 exotic history; no owner admission')
    mode.add_argument('--general-build', action='store_true', help='Structural generalized Build matrix only; public Game114 season admission remains closed')
    mode.add_argument('--general-physical', action='store_true', help='Ordinary single-game physical context tests only; no owned season admission')
    mode.add_argument('--general-birth', action='store_true', help='General ordinary season birth/draft exact cold replay')
    mode.add_argument('--general-round', action='store_true', help='General actual ordinary season round/earned shop/cold replay')
    parser.add_argument('--resolve-benchmark', action='store_true', help='After a fresh general round, compare immediate report reuse against full validation')
    parser.add_argument('--general-profile', choices=['standard', 'dugout'], default='standard')
    parser.add_argument('--terminal-resume-stage', type=Path, help='Resume only an exact-source isolated --terminal-season stage')
    parser.add_argument('--facade', action='store_true', help='Use the additive resource-retaining UI facade during --owner-round')
    args = parser.parse_args()
    if args.resolve_benchmark and not args.general_round:
        parser.error('--resolve-benchmark requires a fresh --general-round')
    if args.facade and not args.owner_round:
        parser.error('--facade requires --owner-round')
    if args.terminal_resume_stage and not args.terminal_season:
        parser.error('--terminal-resume-stage requires --terminal-season')
    root = Path(__file__).resolve().parents[1]
    stage = args.terminal_resume_stage.resolve() if args.terminal_resume_stage else Path(tempfile.mkdtemp(prefix='wiffaltro-signature-'))
    assert stage.is_dir() and stage.name.startswith('wiffaltro-signature-')
    project = stage / 'project'
    if args.terminal_resume_stage:
        assert (project / 'project.godot').read_bytes() == (root / 'project.godot').read_bytes()
        for source in (root / 'src').rglob('*'):
            if source.is_file():
                assert (project / source.relative_to(root)).read_bytes() == source.read_bytes(), source
    else:
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
    if args.dugout or args.dugout_round or args.dugout_pending_fixture or args.identity or args.career_fixture or args.owner or args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        names += ['successor_dugout_live.gd', 'successor_dugout_live.tscn', 'successor_dugout_round.gd', 'successor_dugout_round.tscn', 'successor_dugout_integrity.gd', 'successor_dugout_integrity.tscn']
    if args.identity:
        names += ['successor_identity.gd', 'successor_identity.tscn']
    if args.owner_performance_fixture:
        names += ['successor_owner_performance.gd', 'successor_owner_performance.tscn']
    if args.owner_round:
        names += ['successor_owner_round.gd', 'successor_owner_round.tscn']
    if args.owner:
        names += ['successor_owner.gd', 'successor_owner.tscn']
    if args.career_fixture:
        names += ['successor_career.gd', 'successor_career.tscn']
    for name in names:
        if args.terminal_resume_stage:
            assert (project / 'tests' / name).read_bytes() == (root / 'tests' / (name + '.txt')).read_bytes()
            continue
        shutil.copy2(root / 'tests' / (name + '.txt'), project / 'tests' / name)
    manifest = json.loads((root / 'drafts/successor-v7/DRAFT_MANIFEST.json').read_text())
    assert len(manifest['files']) == 47
    entries = manifest['files'] + manifest.get('additions', [])
    if args.dugout or args.dugout_round or args.dugout_pending_fixture or args.identity or args.career_fixture or args.owner or args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        league_manifest = json.loads((root / 'drafts/successor-league-v1/DRAFT_MANIFEST.json').read_text())
        entries += league_manifest['files'] + league_manifest.get('additions', [])
    if args.career_fixture or args.owner or args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        career_manifest = json.loads((root / 'drafts/successor-career-v1/DRAFT_MANIFEST.json').read_text())
        entries += career_manifest['files']
    if args.owner or args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        owner_manifest = json.loads((root / 'drafts/successor-owner-v1/DRAFT_MANIFEST.json').read_text())
        entries += owner_manifest['files']
    if args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        live_owner_manifest = json.loads((root / 'drafts/successor-owner-live-v1/DRAFT_MANIFEST.json').read_text())
        entries += live_owner_manifest['files'] + live_owner_manifest.get('additions', [])
    if args.owner_performance_fixture or args.facade:
        facade_manifest = json.loads((root / 'drafts/successor-owner-ui-v1/DRAFT_MANIFEST.json').read_text())
        entries += facade_manifest['files']
    if args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        completion_manifest = json.loads((root / 'drafts/successor-career-completion-v1/DRAFT_MANIFEST.json').read_text())
        entries += completion_manifest['files']
    if args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        entries += json.loads((root / 'drafts/successor-career-assets-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.terminal_birth or args.terminal_round or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        entries += json.loads((root / 'drafts/successor-owner-terminal-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.recapture_fixture:
        entries += json.loads((root / 'drafts/successor-owner-recapture-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round:
        entries += json.loads((root / 'drafts/successor-career-history-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.general_build or args.general_physical or args.general_birth or args.general_round:
        entries += json.loads((root / 'drafts/successor-league-general-v2/DRAFT_MANIFEST.json').read_text())['files']
    assert len({entry['restore_path'] for entry in entries}) == len(entries)
    for entry in entries:
        source = root / entry['backup_path']
        data = source.read_bytes()
        assert len(data) == entry['bytes']
        assert hashlib.sha256(data).hexdigest() == entry['sha256'], source
        target = project / entry['restore_path']
        assert target.is_relative_to(project), target
        if args.terminal_resume_stage:
            assert target.read_bytes() == data, target
            continue
        assert not target.exists(), target
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    env = dict(os.environ, WIFFALTRO_ISOLATED_TEST='1')
    env['WIFFALTRO_TEST_FACADE'] = '1' if args.facade else '0'
    for key, directory in [('HOME', 'home'), ('XDG_DATA_HOME', 'data'),
                           ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        env[key] = str(stage / directory)
        Path(env[key]).mkdir(exist_ok=bool(args.terminal_resume_stage))
    print(f'Isolated test evidence: {stage}', flush=True)
    def run(label, switches, timeout=300):
        is_import = label == 'import'
        while (stage / f'{label}.log').exists():
            label += '-resume'
        command = [args.godot, '--headless', '--path', str(project), *switches]
        with (stage / f'{label}.log').open('w') as log:
            result = subprocess.run(command, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        output = (stage / f'{label}.log').read_text()
        if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output or 'FAIL:' in output:
            raise RuntimeError(f'{label} failed (exit {result.returncode}):\n{output[-6000:]}')
        if not is_import and 'PASS:' not in output:
            raise RuntimeError(f'{label} produced no success marker: {output}')
        print(f'{label}: ' + '\n'.join(line for line in output.splitlines() if 'PASS:' in line), flush=True)
        return output
    run('import', ['--editor', '--import', '--quit'])
    script = ['res://tests/successor_signature.tscn', '--']
    if args.completion_fixture or args.assets_fixture:
        source = (args.completion_fixture or args.assets_fixture).resolve()
        assert source.is_file() and source.name == 'successor-fresh-owner-live-v1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        source_before = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source_before)
        if args.assets_fixture:
            for suite in ['stadium_progress', 'plaque_adapter', 'asset_basis']:
                run('assets-' + suite, ['res://tests/successor_' + suite + '.tscn'], timeout=900)
            assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
            return
        run('completion-policy', ['res://tests/successor_completion_policy.tscn'], timeout=600)
        run('completion-metrics', ['res://tests/successor_player_metrics.tscn'], timeout=900)
        assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
        return
    if args.owner_performance_fixture:
        source = args.owner_performance_fixture.resolve()
        assert source.is_file() and source.name == 'successor-fresh-owner-live-v1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        source_before = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source_before)
        for trial in ['baseline', 'facade', 'facade-repeat', 'baseline-repeat', 'facade-failure']:
            run('owner-performance-' + trial, ['res://tests/successor_owner_performance.tscn', '--', trial], timeout=1800)
        run('owner-performance-cold', ['res://tests/successor_owner_performance.tscn', '--', 'reopen'], timeout=1200)
        assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
        return
    if args.general_birth or args.general_round:
        selected = ['dugout'] if args.general_profile == 'dugout' else []
        if args.general_birth:
            scene = ['res://tests/successor_general_birth.tscn', '--', *selected]
            run('general-birth', scene, timeout=1800)
            run('general-birth-cold', scene + ['reopen'], timeout=900)
        else:
            scene = ['--fixed-fps', '60', 'res://tests/successor_general_round.tscn', '--', *selected]
            run('general-human', scene + ['human-only'], timeout=2400)
            run('general-ai-first', scene + ['resume-round', 'one-ai'], timeout=2400)
            run('general-ai-second', scene + ['resume-round', 'one-ai'], timeout=2400)
            run('general-settle-shop', scene + ['resume-round'], timeout=2400)
            run('general-round-cold', scene + ['reopen'], timeout=1800)
            if args.resolve_benchmark:
                run('general-resolve', ['res://tests/successor_general_resolve.tscn', '--', *selected], timeout=2400)
        return
    if args.general_physical:
        run('general-physical', ['--fixed-fps', '60', 'res://tests/successor_general_physical.tscn'], timeout=3600)
        run('general-physical-cold', ['res://tests/successor_general_physical.tscn', '--', 'reopen'], timeout=1800)
        return
    if args.general_build:
        run('general-build', ['res://tests/successor_general_matrix.tscn'], timeout=2400)
        return
    if args.history_fixture:
        source = args.history_fixture.resolve()
        assert source.is_file() and source.name == 'successor-fresh-owner-terminal-v1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        source_before = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned112.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source_before)
        run('exotic-history', ['res://tests/successor_exotic_history.tscn'], timeout=1200)
        assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
        return
    if args.recapture_fixture:
        source = args.recapture_fixture.resolve()
        assert source.is_file() and source.name == 'successor-fresh-owner-terminal-v1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        source_before = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned112.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source_before)
        run('recapture-equivalence', ['res://tests/successor_recapture.tscn'], timeout=3600)
        run('recapture-cold', ['res://tests/successor_recapture.tscn', '--', 'reopen'], timeout=1800)
        assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
        return
    if args.terminal_policy:
        run('terminal-policy', ['res://tests/successor_terminal_policy.tscn'], timeout=1200)
        return
    if args.terminal_season:
        scene = ['--fixed-fps', '60', 'res://tests/successor_terminal_season.tscn', '--']
        for step in range(80):
            label = f'terminal-season-step-{step:03}'
            while (stage / (label + '.log')).exists():
                label += '-resume'
            output = run(label, scene + ['step'], timeout=3600)
            records = [json.loads(line.split('STEP_DONE: ', 1)[1]) for line in output.splitlines() if line.startswith('STEP_DONE: ')]
            assert len(records) == 1, 'Missing unique durable boundary record'
            if records[0]['complete']:
                run('terminal-season-cold', scene + ['verify-terminal'], timeout=3600)
                return
        raise RuntimeError('Season exceeded bounded steps; retained checkpoints are available')
    if args.terminal_birth:
        run('terminal-birth', ['res://tests/successor_terminal_birth.tscn', '--'], timeout=1200)
        run('terminal-birth-cold', ['res://tests/successor_terminal_birth.tscn', '--', 'reopen'], timeout=900)
        return
    if args.owner_round or args.terminal_round:
        scene = ['--fixed-fps', '60', 'res://tests/successor_terminal_round.tscn' if args.terminal_round else 'res://tests/successor_owner_round.tscn', '--']
        run('owned-human', scene + ['human-only'], timeout=1800)
        run('owned-first-ai', scene + ['resume-round', 'first-ai-only'], timeout=1800)
        run('owned-second-ai', scene + ['resume-round', 'second-ai-only'], timeout=1800)
        run('owned-resume-round', scene + ['resume-round', 'settle-only'], timeout=2400)
        run('owned-round-cold', scene + ['reopen'], timeout=1200)
        return
    if args.owner:
        run('fresh-owner', ['res://tests/successor_owner.tscn', '--'], timeout=1200)
        run('fresh-owner-cold', ['res://tests/successor_owner.tscn', '--', 'reopen'], timeout=900)
        return
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
