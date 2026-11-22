#!/usr/bin/env python3
"""Build and inspect a private universal Mac bundle offline, without executing it."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import stat
import struct
import subprocess
import sys
import zipfile

sys.dont_write_bytecode = True
import assemble_successor
from build_successor_engineering_linux import (
    BOOTSTRAP, STARTER_BOOTSTRAP, EDITOR_SHA, PINNED_CONFIG_SHA, PROFILE_SHA, clean_identity,
    TEMPLATE_ARCHIVE_SHA, USER_DIR, VERSION, digest, prune_tests, run,
)
from test_successor_schedule_wiring import environment

TITLE = 'Wiffaltro Mac Engineering QA'
BUNDLE_ID = 'com.example.wiffaltro-engineering-qa'
STARTER_TITLE = 'Wiffaltro Starter Beta'
STARTER_BUNDLE_ID = 'com.example.wiffaltro-starter-beta'
STARTER_USER_DIR = 'WiffaltroStarterBeta-Mac-v1'
STARTER_FEATURE = 'wiffaltro_starter_beta'
TEMPLATE = 'templates/macos.zip'
TEMPLATE_RELEASE = 'macos_template.app/Contents/MacOS/godot_macos_release.universal'
NATIVE_CPUS = {0x01000007, 0x0100000C}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def universal(stream, size):
    magic, count = struct.unpack('>II', stream.read(8))
    require(magic == 0xCAFEBABE and count == 2, 'expected two Mach-O slices')
    ranges = []
    for cpu, _, offset, length, alignment in struct.iter_unpack('>IIIII', stream.read(20 * count)):
        require(48 <= offset < offset + length <= size and length >= 32
                and alignment <= 30 and offset % (1 << alignment) == 0, 'invalid Mach-O bounds')
        ranges.append((offset, offset + length, cpu))
    ranges.sort()
    require({row[2] for row in ranges} == NATIVE_CPUS and ranges[0][1] <= ranges[1][0],
            'expected disjoint native arm64 and x86_64 slices')
    for offset, _, cpu in ranges:
        stream.seek(offset)
        require(struct.unpack('<II', stream.read(8)) == (0xFEEDFACF, cpu), 'invalid slice header')


def extract_template(archive, destination):
    require(digest(archive, 'sha512') == TEMPLATE_ARCHIVE_SHA, 'unexpected vendor template SHA-512')
    with zipfile.ZipFile(archive) as z:
        require(z.read('templates/version.txt').strip() == b'4.6.3.stable'
                and z.namelist().count(TEMPLATE) == 1, 'wrong template version or layout')
        with z.open(TEMPLATE) as src, destination.open('xb') as out:
            shutil.copyfileobj(src, out)
    with zipfile.ZipFile(destination) as z, z.open(TEMPLATE_RELEASE) as f:
        universal(f, z.getinfo(TEMPLATE_RELEASE).file_size)


def bundle_contents(app, bundle_id=BUNDLE_ID):
    require(app.is_dir() and not app.is_symlink(), 'missing regular .app bundle')
    contents = app / 'Contents'
    plist = plistlib.loads((contents / 'Info.plist').read_bytes())
    exe = plist.get('CFBundleExecutable')
    require(plist.get('CFBundleIdentifier') == bundle_id and plist.get('CFBundlePackageType') == 'APPL'
            and isinstance(exe, str) and exe and Path(exe).name == exe, 'unexpected bundle identity')
    expected = {'Info.plist', 'PkgInfo', f'MacOS/{exe}', f'Resources/{exe}.pck',
                'Resources/icon.icns', 'Resources/PrivacyInfo.xcprivacy'}
    paths = list(app.rglob('*'))
    require(all(not p.is_symlink() and (p.is_file() or p.is_dir()) for p in paths), 'unsafe bundle entries')
    files = {p.relative_to(contents).as_posix() for p in paths if p.is_file()}
    required = {'Info.plist', f'MacOS/{exe}', f'Resources/{exe}.pck', 'Resources/icon.icns'}
    require(required <= files <= expected, f'unexpected bundle files: {files ^ required}')
    native = contents / 'MacOS' / exe
    pack = contents / 'Resources' / (exe + '.pck')
    require(native.stat().st_mode & stat.S_IXUSR, 'missing executable bit')
    with native.open('rb') as handle:
        universal(handle, native.stat().st_size)
    with pack.open('rb') as handle:
        require(handle.read(4) == b'GDPC', 'missing Godot pack header')
    return native, pack


def build(repo, root, editor, templates, starter=False):
    require(digest(editor) == EDITOR_SHA, 'unexpected official Linux editor SHA-256')
    if starter:
        revision, tree, parent = clean_identity(repo)
    else:
        revision = subprocess.check_output(['git','rev-parse','HEAD'], cwd=repo, text=True).strip()
        dirty = subprocess.check_output(['git','status','--porcelain','--untracked-files=no','--',
                                        'src','project.godot','drafts'], cwd=repo)
        require(not dirty, 'tracked source differs from recorded revision')
    title, bundle_id = (STARTER_TITLE, STARTER_BUNDLE_ID) if starter else (TITLE, BUNDLE_ID)
    entry, user_dir = (STARTER_BOOTSTRAP, STARTER_USER_DIR) if starter else (BOOTSTRAP, USER_DIR)
    folder = 'starter_bootstrap' if starter else 'engineering_bootstrap'
    node = 'StarterBootstrap' if starter else 'EngineeringBootstrap'
    features = f'custom_features="{STARTER_FEATURE}"\n' if starter else ''

    def isolated(path, audit=False):
        env = environment(path)
        if starter:
            for name in list(env):
                if name.startswith('WIFFALTRO_'):
                    env.pop(name)
            if audit:
                env['WIFFALTRO_ISOLATED_TEST'] = '1'
        return env

    empty, project = root/'empty', root/'project'
    empty.mkdir()
    audit = root/'audit.gd'
    audit.write_bytes((repo/'tests/successor_reviewed_package_audit.gd.txt').read_bytes())
    assembled = assemble_successor.assemble(repo, project, dynasty_owner=True)
    config = project/'project.godot'
    original = (repo/'project.godot').read_bytes()
    require(hashlib.sha256(original).hexdigest() == PINNED_CONFIG_SHA, 'reviewed configuration changed')
    config.write_bytes(original)
    pinned = root/'authored-project.godot'
    pinned.write_bytes(original)
    env = isolated(root/'build-home')
    template = Path(env['XDG_DATA_HOME'])/'godot/export_templates/4.6.3.stable/macos.zip'
    template.parent.mkdir(parents=True)
    extract_template(templates, template)
    env['WIFFALTRO_PACK_PINNED_PROJECT'] = str(pinned)
    engine = [str(editor),'--headless','--audio-driver','Dummy']
    require(subprocess.check_output([*engine,'--version'], env=env, text=True, timeout=30).strip()
            == VERSION, 'Godot version mismatch')
    command = [*engine,'--path',str(project)]
    run([*command,'--editor','--import'], empty, env, root/'source-import.log')
    pins = root/'reviewed.json'
    run([*command,'--script',str(audit),'--','source',str(pins)],
        empty, dict(env, WIFFALTRO_ISOLATED_TEST='1'), root/'source-probe.log','REVIEWED_SOURCE_PROFILE_PASS 1246')
    profile = json.loads(pins.read_bytes())
    reviewed = profile['reviewed']
    rows = ''.join(f'{p}:{reviewed[p]}\n' for p in sorted(reviewed)).encode()
    require(len(reviewed) == 1246 and hashlib.sha256(rows).hexdigest() == PROFILE_SHA,
            'reviewed source profile changed')
    keep = prune_tests(project, reviewed)
    shutil.rmtree(project/'.godot')
    plugin = project/'addons/wiffaltro_exact_export'
    plugin.mkdir(parents=True)
    (plugin/'plugin.gd').write_bytes((repo/'tools/successor_reviewed_export_plugin.gd.txt').read_bytes())
    (plugin/'plugin.cfg').write_text('[plugin]\nname="Reviewed raw configuration"\n'
                                     'description="Export bytes only"\nauthor="Wiffaltro"\n'
                                     'version="1"\nscript="plugin.gd"\n')
    boot = project/folder
    boot.mkdir()
    (boot/'entry.gd').write_bytes((repo/'tools'/f'successor_{folder}.gd.txt').read_bytes())
    (boot/'entry.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" '
                                  f'path="res://{folder}/entry.gd" id="1"]\n'
                                  f'[node name="{node}" type="Node"]\n'
                                  'script = ExtResource("1")\n')
    active = original.decode()
    source_entry = 'run/main_scene="res://src/presentation/season/season_app.tscn"'
    if starter:
        require(active.count(source_entry) == 1 and active.count('config/name="Wiffaltro"') == 1
                and '[editor]' not in active and '[editor_plugins]' not in active,
                'unexpected authored config shape')
    active = active.replace(source_entry, f'run/main_scene="{entry}"')
    active = active.replace('config/name="Wiffaltro"', f'config/name="{title}"\n'
                            f'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="{user_dir}"')
    # Universal export requires native Apple Silicon texture imports. This changes
    # only the effective scratch export config, never the raw reviewed resource.
    active = active.replace('[rendering]\n', '[rendering]\ntextures/vram_compression/import_etc2_astc=true\n')
    config.write_text(active + '\n[editor]\nexport/convert_text_resources_to_binary=false\n'
                      '\n[editor_plugins]\nenabled=PackedStringArray('
                      '"res://addons/wiffaltro_exact_export/plugin.cfg")\n')
    (project/'export_presets.cfg').write_text(f'''[preset.0]
name="{title}"
platform="macOS"
runnable=true
{features}export_filter="all_resources"
include_filter="src/*,{folder}/*"
exclude_filter="addons/wiffaltro_exact_export/*"
export_path=""
script_export_mode=0
[preset.0.options]
export/distribution_type=0
binary_format/architecture="universal"
application/bundle_identifier="{bundle_id}"
codesign/codesign=0
notarization/notarization=0
''')
    run([*command,'--editor','--import'], empty, env, root/'candidate-import.log')
    inventory = {}
    for p in sorted((project/'src').rglob('*')):
        if not p.is_file():
            continue
        name = p.relative_to(project).as_posix()
        value = digest(p)
        require(not name.startswith('src/tests/') or name in keep, 'unreviewed test in project')
        require(value == assembled['files'].get(name) or
                (name.endswith('.gd.uid') and (project/name[:-4]).is_file()), 'source drift: '+name)
        inventory['res://'+name] = value
    for p in (boot/'entry.gd', boot/'entry.tscn', *((boot/'entry.gd.uid',) if starter else ())):
        inventory['res://'+p.relative_to(project).as_posix()] = digest(p)
    for name, sha in reviewed.items():
        require(sha == (PINNED_CONFIG_SHA if name == 'res://project.godot' else inventory.get(name)),
                'reviewed path drift: '+name)
    if starter:
        inventory['res://project.godot'] = PINNED_CONFIG_SHA
    expected = root/'expected.json'
    expected.write_text(json.dumps({'source':inventory,'starter':starter,'source_broad_sha256':profile['broad_sha256']},sort_keys=True))
    package = root/'package'
    package.mkdir()
    app = package/('WiffaltroStarterBeta.app' if starter else 'WiffaltroEngineeringQA.app')
    run([*command,'--export-release',title,str(app)], empty, env, root/'export.log',
        'REVIEWED_RAW_CONFIG_ADDED')
    require(list(package.iterdir()) == [app], 'unexpected packaging output')
    exe, pack = bundle_contents(app, bundle_id)
    probe = root/'mac-pack-audit.gd'
    probe.write_bytes((repo/'tests/successor_macos_pack_audit.gd.txt').read_bytes())
    result = run([*engine,'--path',str(empty),'--main-pack',str(pack),'--script',str(probe),
                  '--',str(expected)], empty, isolated(root/'inspect-home', audit=True),
                 root/'pack-audit.log', f'MAC_PACK_STATIC_PASS {len(inventory)} ')
    metadata = {'revision':revision,'engine':VERSION,'native_sha256':digest(exe),
                'pck_sha256':digest(pack),'scope':'offline; unsigned; not launched on macOS',
                'source_broad_sha256':profile['broad_sha256'],
                'pack_broad_sha256':next(line.split()[-1] for line in result.splitlines()
                                         if line.startswith('MAC_PACK_STATIC_PASS '))}
    if starter:
        require(clean_identity(repo) == (revision, tree, parent), 'source identity changed during export')
        metadata.update(tree=tree, parent=parent, feature=STARTER_FEATURE, main_scene=entry,
                        user_dir=user_dir, bundle_identifier=bundle_id, app=app.name,
                        scope='offline Mac Starter candidate; unsigned, unnotarized, no saves or macOS launch')
    (root/'result.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps(metadata))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--templates',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--starter-beta',action='store_true',help='Export the separate no-save Starter candidate')
    args = parser.parse_args()
    if not sys.platform.startswith('linux') or sys.flags.optimize:
        parser.error('use ordinary Python 3 on x86_64 Linux with the pinned editor')
    output = args.output.resolve()
    output.mkdir()
    build(Path(__file__).resolve().parents[1], output, args.godot.resolve(),args.templates.resolve(),starter=args.starter_beta)
