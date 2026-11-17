#!/usr/bin/env python3
"""Isolated PCK compatibility probe, not a distributable. Never installs templates.
Source stage and authentic QA fixture are read-only inputs; private outputs are retained.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree(path):
    return {str(p.relative_to(path)): digest(p) for p in sorted(path.rglob('*')) if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, required=True)
    parser.add_argument('--evidence-root', type=Path, required=True)
    parser.add_argument('--godot', default='/usr/local/bin/godot')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    source = args.stage.resolve() / 'project'
    fixture = args.fixture.resolve()
    if (source / 'project.godot').read_bytes() != (repo / 'project.godot').read_bytes():
        raise RuntimeError('Staged project.godot differs from audited repository configuration')
    original = tree(source)
    fixture_hash = digest(fixture)
    # Every staged source file must equal a current source file or a verified
    # manifest materialization, not merely a plausible older stage filename.
    allowed = {}
    for p in (repo / 'src').rglob('*'):
        if p.is_file():
            allowed.setdefault(str(p.relative_to(repo)), set()).add(digest(p))
    for manifest in (repo / 'drafts').rglob('*MANIFEST.json'):
        definition = json.loads(manifest.read_text())
        for row in definition.get('files', []) + definition.get('additions', []):
            if not all(k in row for k in ('backup_path', 'restore_path', 'sha256')):
                continue
            p = repo / row['backup_path']
            if not p.is_file() or digest(p) != row['sha256']:
                raise RuntimeError(f'Invalid manifest materialization: {p}')
            allowed.setdefault(row['restore_path'], set()).add(row['sha256'])
    generated_uids = {}
    uid_owners = {}
    for name, sha in original.items():
        if name.endswith('.gd.uid'):
            value = (source / name).read_text().strip()
            if not re.fullmatch(r'uid://[a-z0-9]+', value):
                raise RuntimeError(f'Invalid UID sidecar: {name}')
            if value in uid_owners:
                raise RuntimeError(f'Duplicate UID {value}: {uid_owners[value]} and {name}')
            uid_owners[value] = name
        if name.startswith('src/') and sha not in allowed.get(name, set()):
            companion = name[:-4]
            if not name.endswith('.gd.uid') or original.get(companion) not in allowed.get(companion, set()):
                raise RuntimeError(f'Unmatched staged source: {name}')
            generated_uids[name] = sha
    print(f'Classified generated UID sidecars: {len(generated_uids)}; no duplicate UIDs', flush=True)
    args.evidence_root.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='wiffaltro-export-probe-', dir=args.evidence_root.resolve()))
    print(f'EVIDENCE: {work}', flush=True)
    project = work / 'project'
    project.mkdir()
    shutil.copytree(source / 'src', project / 'src')
    shutil.copy2(source / 'project.godot', project / 'project.godot')
    tests = project / 'tests'
    tests.mkdir()
    for ext in ('gd', 'tscn'):
        shutil.copy2(repo / f'drafts/successor-export-probe-v1/tests/successor_export_probe.{ext}.txt', tests / f'successor_export_probe.{ext}')
    hashes = {'res://' + name: sha for name, sha in original.items() if name.startswith('src/')}
    (project / 'probe-hashes.json').write_text(json.dumps(hashes, sort_keys=True))
    config = (project / 'project.godot').read_text().replace('run/main_scene="res://src/presentation/season/season_app.tscn"', 'run/main_scene="res://tests/successor_export_probe.tscn"')
    config += '\n[editor]\nexport/convert_text_resources_to_binary=false\n'
    (project / 'project.godot').write_text(config)
    (project / 'export_presets.cfg').write_text('''[preset.0]
name="Probe"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter="src/*,probe-hashes.json"
exclude_filter=""
export_path=""
script_export_mode=0
[preset.0.options]
binary_format/embed_pck=false
''')
    empty = work / 'empty'
    empty.mkdir()
    def environment(label):
        base = work / label
        env = os.environ.copy()
        for key, leaf in [('HOME','home'), ('XDG_DATA_HOME','data'), ('XDG_CONFIG_HOME','config'), ('XDG_CACHE_HOME','cache')]:
            p = base / leaf
            p.mkdir(parents=True, exist_ok=True)
            env[key] = str(p)
        env['WIFFALTRO_ISOLATED_TEST'] = '1'
        userdata = base / 'data/godot/app_userdata/Wiffaltro'
        userdata.mkdir(parents=True, exist_ok=True)
        shutil.copy2(fixture, userdata / 'source-general.json')
        return env, userdata
    baseline_env, baseline_user = environment('baseline')
    pack_env, pack_user = environment('packed')
    def run(label, cmd, env, marker=None):
        with (work / (label + '.log')).open('w') as log:
            result = subprocess.run([args.godot, '--headless', '--audio-driver', 'Dummy'] + cmd, cwd=empty, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
        output = (work / (label + '.log')).read_text()
        if result.returncode or 'FAIL:' in output or 'SCRIPT ERROR' in output or 'ERROR:' in output or (marker and marker not in output):
            raise RuntimeError(f'{label} failed; retained {work / (label + ".log")}')
    try:
        run('import', ['--path', str(project), '--editor', '--import'], baseline_env)
        run('baseline', ['--path', str(project), '--', 'baseline'], baseline_env, 'PASS: export probe')
        shutil.copy2(baseline_user / 'baseline.json', pack_user / 'baseline.json')
        pack = work / 'probe.pck'
        run('export', ['--path', str(project), '--editor', '--export-pack', 'Probe', str(pack)], baseline_env)
        if not pack.is_file():
            raise RuntimeError('Export produced no PCK')
        # Both cwd and --path contain no project/source. Only the external PCK supplies res://.
        run('packed', ['--path', str(empty), '--main-pack', str(pack)], pack_env, 'PASS: export probe')
        run('packed-cold', ['--path', str(empty), '--main-pack', str(pack), '--', 'cold'], pack_env, 'PASS: export probe')
        print('PASS: isolated PCK raw identity, paid restore, fresh draft save and cold reopen; NOT a distributable', flush=True)
    finally:
        assert tree(source) == original, 'Original source stage changed'
        assert digest(fixture) == fixture_hash, 'Original fixture changed'
        for name, sha in original.items():
            if name.startswith('src/'):
                assert digest(project / name) == sha, f'Copied engine changed: {name}'
        assert digest(pack_user / 'source-general.json') == fixture_hash
        (work / 'provenance.json').write_text(json.dumps({'fixture_sha256':fixture_hash, 'generated_uid_sidecars':generated_uids, 'generated_uid_count':len(generated_uids), 'src_hashes':hashes, 'original_stage_unchanged':True, 'copied_existing_src_unchanged':True}, indent=2))


if __name__ == '__main__':
    main()
