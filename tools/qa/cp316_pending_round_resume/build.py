#!/usr/bin/env python3
"""Official Linux export-template QA of the exact Starter feature, not a release build."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

qa = Path(__file__).resolve().parent
repo = Path(sys.argv.pop(1)).resolve(strict=True)
sys.path.insert(0, str(repo / "tools"))
sys.dont_write_bytecode = True
import build_successor_engineering_linux as official

godot, vendor_release = (Path(x).resolve(strict=True) for x in sys.argv[1:])
assert official.digest(godot) == official.EDITOR_SHA
assert shutil.disk_usage(tempfile.gettempdir()).free >= 126 * 1024**2, "build plus 40 MiB reserve"
root = Path(tempfile.mkdtemp(prefix="wiffaltro-cp314-proof-"))
print(root, flush=True)
project = root / "project"
official.assemble_successor.assemble(repo, project, dynasty_owner=True, preserve_authored_project=True)
shutil.copyfile(repo / "tests/successor_standard_base_journey.gd.txt", project / "qa.gd")
for suffix in ("gd", "tscn"):
    shutil.copyfile(qa / f"probe.{suffix}.txt", project / f"cp314_probe.{suffix}")
raw = repo / "project.godot"
assert official.digest(raw) == official.PINNED_CONFIG_SHA
active = raw.read_text()
entry = 'run/main_scene="res://src/presentation/season/season_app.tscn"'
name = 'config/name="Wiffaltro"'
assert active.count(entry) == active.count(name) == 1
active = active.replace(entry, f'run/main_scene="{official.STARTER_BOOTSTRAP}"')
active = active.replace(name, 'config/name="Wiffaltro Starter Beta"\nconfig/use_custom_user_dir=true\n'
                              f'config/custom_user_dir_name="{official.STARTER_DIR}"')
bootstrap = project / "starter_bootstrap"
bootstrap.mkdir()
starter_script = (repo / "tools/successor_starter_bootstrap.gd.txt").read_text()
args_line = "\tvar args: PackedStringArray=OS.get_cmdline_user_args()\n"
assert starter_script.count(args_line) == 1
# Official Linux builds deliberately disallow --scene on their command line.
# Add a narrowly selected probe in this throwaway PCK after the real feature
# gate; the ordinary app methods still run unmodified.
starter_script = starter_script.replace(
    args_line, args_line + '\tif args.size()==4 and args[0]=="cp314" and args[1] in ["round","cold","resume7"]:\n'
    '\t\tget_tree().change_scene_to_file.call_deferred("res://cp314_probe.tscn")\n'
    '\t\treturn\n')
(bootstrap / "entry.gd").write_text(starter_script)
(bootstrap / "entry.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" '
                                     'path="res://starter_bootstrap/entry.gd" id="1"]\n'
                                     '[node name="StarterBootstrap" type="Node"]\nscript = ExtResource("1")\n')
plugin = project / "addons/wiffaltro_exact_export"
plugin.mkdir(parents=True)
shutil.copyfile(repo / "tools/successor_reviewed_export_plugin.gd.txt", plugin / "plugin.gd")
(plugin / "plugin.cfg").write_text('[plugin]\nname="Reviewed config"\ndescription="QA"\n'
                                  'author="Wiffaltro"\nversion="1"\nscript="plugin.gd"\n')
(project / "project.godot").write_text(active + '\n[editor]\nexport/convert_text_resources_to_binary=false\n\n'
                                      '[editor_plugins]\n'
                                      'enabled=PackedStringArray("res://addons/wiffaltro_exact_export/plugin.cfg")\n')
(project / "export_presets.cfg").write_text(f'''[preset.0]
name="{official.TITLE}"
platform="Linux"
runnable=true
custom_features="wiffaltro_starter_beta"
export_filter="all_resources"
include_filter="src/*,starter_bootstrap/*,cp314_probe.*"
exclude_filter="addons/wiffaltro_exact_export/*"
export_path=""
script_export_mode=0
[preset.0.options]
binary_format/embed_pck=false
binary_format/architecture="x86_64"
''')


def env(mode):
    e = {k: v for k, v in os.environ.items() if not k.startswith("WIFFALTRO_")}
    for key, v in (("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"),
                   ("XDG_CONFIG_HOME", "config")):
        p = root / mode / v
        p.mkdir(parents=True, exist_ok=True)
        e[key] = str(p)
    return e


def run(mode, command, environment, timeout, expected=0):
    with (root / f"{mode}.log").open("xb") as f:
        proc = subprocess.run(command, cwd=root, env=environment, stdout=f, stderr=subprocess.STDOUT, timeout=timeout)
    log = (root / f"{mode}.log").read_text()
    assert proc.returncode == expected and "SCRIPT ERROR:" not in log and "\nERROR:" not in log, log[-3000:]
    return log


build_env = env("build")
build_env["WIFFALTRO_PACK_PINNED_PROJECT"] = str(raw)
engine = [str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(project)]
run("import", [*engine, "--editor", "--import"], build_env, 180)
exe, pack = (root / "Wiffaltro.x86_64", root / "Wiffaltro.pck")
# Use the previously verified immutable vendor template, not another
# large duplicate. Neither the link nor the existing executable is edited.
assert official.digest(vendor_release) == official.LINUX_RELEASE_SHA
if vendor_release.stat().st_dev == root.stat().st_dev:
    os.link(vendor_release, exe)
else:
    shutil.copy2(vendor_release, exe)
assert official.digest(exe) == official.LINUX_RELEASE_SHA
assert shutil.disk_usage(root).free >= 73 * 1024**2, "40 MiB reserve plus owned QA PCK and buffer"
assert "REVIEWED_RAW_CONFIG_ADDED" in run("export", [*engine, "--export-pack", official.TITLE, str(pack)],
                                         build_env, 180)
print("CP314 QA export", official.digest(exe), official.digest(pack), flush=True)

# Reproducible assembly from this run only; never delete prior runs or proofs.
shutil.rmtree(project)
