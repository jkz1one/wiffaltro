#!/usr/bin/env python3
"""Build an isolated, gated Linux candidate with exact reviewed source bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

sys.dont_write_bytecode = True
import assemble_successor
from test_successor_dynasty_post_purchase import evidence
from test_successor_schedule_wiring import environment

VERSION = '4.6.3.stable.official.7d41c59c4'
EDITOR_SHA = 'f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3'
TEMPLATE_ARCHIVE_SHA = 'da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68'
PROFILE_SHA = 'c519442994b2ec1f2defc18dac5534b5c74b1823493efc104fb6eda39e3199fe'
PINNED_CONFIG_SHA = '9650ccc2ce6957eda9f088663597bd754098dc05d42d0a00c9fa25c7085e35fd'
TEMPLATE = 'templates/linux_release.x86_64'
USER_DIR = 'WiffaltroEngineeringQA-v1'
BOOTSTRAP = 'res://engineering_bootstrap/entry.tscn'
PACK_BROAD_SHA = '106b8a4ad667984a89d2333505f884a4f98d271e0ca93fe0da5d8827172f9a52'
TITLE = 'Wiffaltro Linux Engineering'
EXTRA_SUPPORT = {
    'src/tests/helpers/pool_active_receipt.gd',
    'src/tests/helpers/pool_controller_writer_ledger.gd',
    'src/tests/ownership_fixtures.gd',
    'src/tests/opponent_recovery_probe.gd',
    'src/tests/opponent_tactical_probe.gd',
    'src/tests/test_audio_drain.gd',
}


def digest(path, algorithm='sha256'):
    with path.open('rb') as f:
        return hashlib.file_digest(f, algorithm).hexdigest()


def extract(archive, destination):
    assert digest(archive, 'sha512') == TEMPLATE_ARCHIVE_SHA
    with zipfile.ZipFile(archive) as z:
        assert z.read('templates/version.txt').decode().strip() == '4.6.3.stable'
        assert z.namelist().count(TEMPLATE) == 1 and z.getinfo(TEMPLATE).file_size == 71_075_864
        with z.open(TEMPLATE) as src, destination.open('xb') as dest:
            shutil.copyfileobj(src, dest)
    destination.chmod(0o700)


def run(cmd, cwd, env, logfile, marker=None, expected=0):
    with logfile.open('xb') as out:
        result = subprocess.run(cmd, cwd=cwd, env=env, stdout=out, stderr=subprocess.STDOUT, timeout=300)
    text = logfile.read_text()
    if result.returncode != expected or (marker is not None and marker not in text) or 'SCRIPT ERROR' in text \
            or (expected == 0 and re.search(r'(?m)^(?:ERROR|USER ERROR):', text)):
        raise RuntimeError(f'{logfile.name}: exit {result.returncode}, expected {expected}; qualification stopped')
    return text


def prune_tests(project, reviewed):
    keep = {p.removeprefix('res://') for p in reviewed if p.startswith('res://src/tests/')} | EXTRA_SUPPORT
    remaining = set(keep)
    while remaining:
        path = remaining.pop()
        for needed in re.findall(r'res://(src/tests/[a-zA-Z0-9_/.-]+\.(?:gd|tscn))',
                                 (project/path).read_text()):
            if needed not in keep and (project/needed).is_file():
                keep.add(needed)
                remaining.add(needed)
    keep |= {p+'.uid' for p in keep if (project/(p+'.uid')).is_file()}
    assert len(keep) == 32 and all(x.endswith(('.gd','.gd.uid','.tscn')) for x in keep)
    for p in (project/'src/tests').rglob('*'):
        if p.is_file() and p.relative_to(project).as_posix() not in keep:
            p.unlink()
    return keep


def qualify(repo, root, editor, templates, paid=None, backup=None):
    no_save = paid is None
    assert no_save == (backup is None)
    revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
    if no_save:
        assert not subprocess.check_output(['git','status','--porcelain','--untracked-files=no','--',
                                            'src','project.godot','drafts'],cwd=repo,text=True), 'tracked source differs from revision'

    def build_environment(path):
        env = environment(path)
        if no_save:
            for name in list(env):
                if name.startswith('WIFFALTRO_') and name not in {
                    'WIFFALTRO_DYNASTY_ENGINEERING','WIFFALTRO_ISOLATED_TEST',
                }:
                    env.pop(name)
        return env
    assert digest(editor) == EDITOR_SHA
    project, package, empty = (root/x for x in ('project','package','empty'))
    package.mkdir(); empty.mkdir()
    audited = assemble_successor.assemble(repo, project, dynasty_owner=True,
                                           preserve_authored_project=no_save)
    config = project/'project.godot'
    original = (repo/'project.godot').read_bytes()
    assert hashlib.sha256(original).hexdigest() == PINNED_CONFIG_SHA
    config.write_bytes(original)
    pinned = root/'authored-project.godot'
    pinned.write_bytes(original)
    audit = root/'audit.gd'
    audit.write_bytes((repo/'tests/successor_reviewed_package_audit.gd.txt').read_bytes())
    template = root/'linux_release.x86_64'
    extract(templates, template)
    engine = [str(editor), '--headless', '--audio-driver', 'Dummy']
    env = build_environment(root/'build-home')
    env['WIFFALTRO_PACK_PINNED_PROJECT'] = str(pinned)
    assert subprocess.check_output([*engine,'--version'],env=env,text=True,timeout=30).strip() == VERSION
    project_engine = [*engine,'--path',str(project)]
    run([*project_engine,'--editor','--import'],empty,env,root/'source-import.log')
    pins = root/'reviewed.json'
    run([*project_engine,'--script',str(audit),'--','source',str(pins)],
        empty,env,root/'source-probe.log','REVIEWED_SOURCE_PROFILE_PASS 1246')
    profile = json.loads(pins.read_bytes())
    reviewed = profile['reviewed']
    review_bytes = ''.join(f'{p}:{reviewed[p]}\n' for p in sorted(reviewed)).encode()
    assert len(reviewed) == 1246 and hashlib.sha256(review_bytes).hexdigest() == PROFILE_SHA
    support = prune_tests(project, reviewed)
    # No class/import cache from the unpruned source may leak into the artifact.
    shutil.rmtree(project/'.godot')
    plugin = project/'addons/wiffaltro_exact_export'
    plugin.mkdir(parents=True)
    (plugin/'plugin.gd').write_bytes((repo/'tools/successor_reviewed_export_plugin.gd.txt').read_bytes())
    (plugin/'plugin.cfg').write_text('''[plugin]
name="Wiffaltro reviewed raw configuration"
description="Export-time source bytes only"
author="Wiffaltro"
version="1"
script="plugin.gd"
''')
    bootstrap_dir = project/'engineering_bootstrap'
    bootstrap_dir.mkdir()
    bootstrap_script = bootstrap_dir/'entry.gd'
    bootstrap_script.write_bytes((repo/'tools/successor_engineering_bootstrap.gd.txt').read_bytes())
    bootstrap_scene = bootstrap_dir/'entry.tscn'
    bootstrap_scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" '
                               'path="res://engineering_bootstrap/entry.gd" id="1"]\n'
                               '[node name="EngineeringBootstrap" type="Node"]\nscript = ExtResource("1")\n')
    active = original.decode()
    entry = 'run/main_scene="res://src/presentation/season/season_app.tscn"'
    name = 'config/name="Wiffaltro"'
    assert active.count(entry)==1 and active.count(name)==1 and '[editor]' not in active and '[editor_plugins]' not in active
    active = active.replace(entry, f'run/main_scene="{BOOTSTRAP}"')
    active = active.replace(name, f'config/name="Wiffaltro Engineering QA"\nconfig/use_custom_user_dir=true\n'
                                  f'config/custom_user_dir_name="{USER_DIR}"')
    config.write_text(active+'\n[editor]\nexport/convert_text_resources_to_binary=false\n\n[editor_plugins]\n'
                       'enabled=PackedStringArray("res://addons/wiffaltro_exact_export/plugin.cfg")\n')
    (project/'export_presets.cfg').write_text(f'''[preset.0]
name="{TITLE}"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter="src/*,engineering_bootstrap/*"
exclude_filter="addons/wiffaltro_exact_export/*"
export_path=""
script_export_mode=0
[preset.0.options]
custom_template/release={json.dumps(str(template))}
binary_format/embed_pck=false
binary_format/architecture="x86_64"
''')
    run([*project_engine,'--editor','--import'],empty,env,root/'candidate-import.log')
    inventory = {}
    uids = set()
    for p in sorted((project/'src').rglob('*')):
        if not p.is_file(): continue
        name = p.relative_to(project).as_posix()
        value = digest(p)
        if name.startswith('src/tests/'): assert name in support, name
        if name.endswith('.gd.uid'):
            uid = p.read_text().strip()
            assert re.fullmatch(r'uid://[a-z0-9]+',uid) and uid not in uids
            uids.add(uid)
        if value != audited['files'].get(name):
            assert name.endswith('.gd.uid') and (project/name[:-4]).is_file(), name
        inventory['res://'+name] = value
    for name, sha in reviewed.items():
        assert (PINNED_CONFIG_SHA if name=='res://project.godot' else inventory.get(name)) == sha
    for p in (bootstrap_script,bootstrap_scene):
        inventory['res://'+p.relative_to(project).as_posix()] = digest(p)
    if no_save:
        bootstrap_uid=bootstrap_script.with_suffix('.gd.uid')
        uid=bootstrap_uid.read_text().strip()
        assert re.fullmatch(r'uid://[a-z0-9]+',uid) and uid not in uids
        inventory['res://'+bootstrap_uid.relative_to(project).as_posix()]=digest(bootstrap_uid)
    expected = root/'expected.json'
    expected.write_text(json.dumps({'source':inventory,'broad_sha256':profile['broad_sha256']},sort_keys=True))
    exe, pack = package/'Wiffaltro.x86_64', package/'Wiffaltro.pck'
    run([*project_engine,'--export-release',TITLE,str(exe)],empty,env,root/'export.log','REVIEWED_RAW_CONFIG_ADDED')
    assert set(p.name for p in package.iterdir()) == {exe.name,pack.name}
    with exe.open('rb') as f: header=f.read(20)
    assert header[:6]==b'\x7fELF\x02\x01' and int.from_bytes(header[18:20],'little')==62
    assert digest(exe) == digest(template)
    gate_env=build_environment(root/'no-gate-home')
    gate_env.pop('WIFFALTRO_DYNASTY_ENGINEERING',None)
    boot = [str(exe),'--headless','--audio-driver','Dummy','--verbose','--quit-after','60']
    run(boot,empty,gate_env,root/'gate.log','Private Dynasty engineering route not admitted.',expected=2)
    boot_env=build_environment(root/'standalone-home')
    run([*boot,'--log-file','user://engineering-boot.log'],empty,boot_env,root/'standalone.log',
        'Loading resource: '+audited['launcher'])
    assert (Path(boot_env['XDG_DATA_HOME'])/USER_DIR/'engineering-boot.log').is_file()
    denied = run([*boot,'--','--physical-job=x'],empty,boot_env,root/'malformed-worker.log',
                 'Private packaged worker request refused.',expected=3)
    assert 'WIFFALTRO_PACKAGED_LEGACY_WORKER_ROUTE' not in denied and audited['launcher'] not in denied
    assert not (Path(boot_env['XDG_DATA_HOME'])/'godot/app_userdata/Wiffaltro').exists()
    assert not list(Path(boot_env['XDG_DATA_HOME']).rglob('wiffaltro-common-career-v4.json'))
    inspect_env=build_environment(root/'inspect-home')
    target=Path(inspect_env['XDG_DATA_HOME'])/USER_DIR
    target.mkdir()
    if no_save:
        result=run([*engine,'--path',str(empty),'--main-pack',str(pack),'--script',str(audit),'--','pack-no-save',str(expected)],
            empty,inspect_env,root/'pack-audit.log',f'PACKED_REVIEWED_PROFILE_NO_SAVE_PASS {len(inventory)}')
        # Conservative refusal: a new broad digest must not appear as any exact
        # digest literal in the execution source. This covers frozen broad
        # allowlists without adding or refreshing a runtime stadium pin.
        observed=re.search(r'PACK_BROAD_SHA256 ([0-9a-f]{64})',result)[1]
        for path in (project/'src').rglob('*.gd'):
            assert not re.search(r'["\']'+observed+r'["\']',path.read_text()), f'broad identity already pinned: {path}'
        for stage in ('build-home','no-gate-home','standalone-home','inspect-home'):
            data=root/stage/'data'
            for path in data.rglob('*'):
                if path.is_dir() and not path.is_symlink():
                    continue
                name=path.relative_to(data).as_posix()
                log_dir='(?:godot/app_userdata/Wiffaltro|'+USER_DIR+')' if stage=='build-home' else USER_DIR
                safe_log=path.is_file() and not path.is_symlink() and re.fullmatch(
                    log_dir+r'/logs/godot[^/]*\.log',name)
                boot_log=stage=='standalone-home' and name==USER_DIR+'/engineering-boot.log' and not path.is_symlink()
                assert safe_log or boot_log, f'unexpected data file in {stage}: {name}'
        assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()==revision
        assert not subprocess.check_output(['git','status','--porcelain','--untracked-files=no','--',
                                            'src','project.godot','drafts'],cwd=repo,text=True), 'source changed during packaging'
    else:
        slot=target/'wiffaltro-common-career-v4.json'
        bak=slot.with_suffix('.json.bak')
        slot.write_bytes(paid); bak.write_bytes(backup)
        result=run([*engine,'--path',str(empty),'--main-pack',str(pack),'--script',str(audit),'--','pack',str(expected)],
            empty,inspect_env,root/'pack-audit.log',f'PACKED_REVIEWED_PROFILE_AND_EARNED_SAVE_PASS {len(inventory)}')
        assert slot.read_bytes()==paid and bak.read_bytes()==backup and not slot.with_suffix('.json.tmp').exists()
    metadata={'engine':VERSION,'elf':digest(exe),'pck':digest(pack),'raw_files':len(inventory),
              'reviewed_files':len(reviewed),'reviewed_profile_sha256':PROFILE_SHA,
              'source_broad_sha256':profile['broad_sha256'],
              'pack_broad_sha256':re.search(r'PACK_BROAD_SHA256 ([0-9a-f]{64})',result)[1],
              'scope':'headless Linux engineering; no rendered input, native Mac, legacy worker or broad-stadium qualification'}
    if no_save:
        metadata['revision']=revision
        metadata['scope']='headless Linux engineering; no saves, rendered input, native Mac, worker gameplay or stadium qualification'
    else:
        assert metadata['pack_broad_sha256'] == PACK_BROAD_SHA
    (root/'result.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps(metadata),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True,help='New scratch directory for the engineering package and isolated proof')
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--evidence',type=Path,help='Already backed, exact generated cp88 evidence')
    mode.add_argument('--no-save',action='store_true',help='Current clean source, package/boot checks only; never loads a save')
    parser.add_argument('--templates',type=Path,required=True,help='Verified vendor non-Mono 4.6.3 release template archive')
    parser.add_argument('--godot',type=Path,required=True,help='Verified vendor x86_64 Godot 4.6.3 editor binary')
    o=parser.parse_args()
    if o.no_save and (not sys.platform.startswith("linux") or sys.flags.optimize):
        parser.error("use ordinary Python 3 on Linux with the pinned x86-64 editor")
    paid,backup=(None,None) if o.no_save else evidence(o.evidence)
    root=o.output.resolve()
    root.mkdir(mode=0o700)
    qualify(Path(__file__).resolve().parents[1],root,o.godot.resolve(),o.templates.resolve(),paid,backup)


if __name__=='__main__':
    main()
