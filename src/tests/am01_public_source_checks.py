"""Read-only checks for the small AM01 data/runtime/daylight fixtures; never launches an engine."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from lark import Lark
from gdtoolkit.parser import parser
from gdtoolkit.parser.gdscript_indenter import GDScriptIndenter
from gdtoolkit.linter import lint_code

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent.parent
WORK = SOURCE.parents[2]
BASE = json.loads((SOURCE.parent / "base-daylight-issued-20261015T0708Z/COMPOSED_SOURCE_MANIFEST.json").read_text())
VENV = WORK / "recovery-20261013/toolchain/reconstructed-tooling-venv-copies"
NAMES = ["am01_public_fixture.gd", "am01_public_data_test.gd", "am01_public_runtime_test.gd",
         "am01_public_installed_view_test.gd"]
checks = 0


def check(ok, label):
    global checks
    checks += 1
    if not ok:
        raise AssertionError(label)


def resolve(name):
    current = SOURCE / name
    return current if current.is_file() else WORK / BASE["files"][name]["source"]


def function(source, name):
    found = re.search(r"^func " + re.escape(name) + r"\(", source, re.M)
    end = re.search(r"^func ", source[found.end():], re.M)
    return source[found.start():found.end() + end.start() if end else len(source)]


memory = Lark.open(str(VENV / "lib/python3.12/site-packages/gdtoolkit/parser/gdscript.lark"),
    parser="lalr", start="start", postlex=GDScriptIndenter(), propagate_positions=True,
    maybe_placeholders=False, cache=False, regex=True)
parser.__dict__["_parser"] = memory
parser.__dict__["_parser_with_metadata"] = memory
for name in NAMES:
    text = (HERE / name).read_text()
    parser.parse(text)
    check(not lint_code(text), "lint " + name)
    check("--headless" not in text and "OS.execute" not in text, "no embedded runner " + name)
    for resource in re.findall(r'"res://([^"\n]+)"', text):
        check(resolve(resource).is_file(), "resolves " + resource)
for kind in ["data", "runtime", "installed_view"]:
    scene = (HERE / f"am01_public_{kind}_test.tscn").read_text()
    check(f'am01_public_{kind}_test.gd' in scene, "scene script " + kind)
    check(('type="Node"]' if kind == "data" else 'type="Node3D"]') in scene,
          "scene inheritance " + kind)

candidate = resolve("src/gameplay/stadium/stadium_npc_mogul_one_candidate_v1.gd").read_text()
payload = json.JSONDecoder().raw_decode(candidate[candidate.index("\treturn {") + 8:])[0]
counts = dict(sorted(Counter(row["item"] for row in payload["instances"]).items()))
check(counts == {"ST-021": 2, "ST-022": 16, "ST-023": 16, "ST-026": 1,
                "ST-029": 2, "ST-038": 6, "ST-039": 1, "ST-065": 22,
                "ST-073": 1, "ST-074": 2, "ST-081": 3}, "exact immutable copy counts")
check(len(payload["instances"]) == 72, "72 existing copies")
check(all(row["instance"] == "npc:AM-01:r1:" + row["site"] for row in payload["instances"]),
      "only existing AM01/r1 identities")
helper = (HERE / NAMES[0]).read_text()
check("SeasonVenues.capture_five(seed_value, result.career.current, 2)" in helper,
      "actual explicit-ordinal fixture allocation")
check("result.choose_player(result.offers()[0])" in helper and "range(4)" in helper,
      "actual four draft choices")
render = (HERE / NAMES[3]).read_text()
base_render = resolve("src/tests/stadium_npc_base_installed_view_test.gd").read_text()
for method in ["_view_family", "_overview", "_fixture", "_lab"]:
    expected = function(base_render, method).replace('"base-', '"am01-').replace(
        "BASE_INSTALLED_VIEWS", "AM01_INSTALLED_VIEWS")
    check(function(render, method) == expected, "unchanged Base capture body " + method)
check(render.count("Vector2i(1280, 720)") == 2 and "for left: bool in [false, true]" in render,
      "seven original1280x720 views")
check('const IDS: Array[String] = ["AM-01"]' in render and '"AM-01": 72' in render,
      "one AM01 public family")
runtime = (HERE / NAMES[2]).read_text()
check(runtime.count("var lab: PitchBatLab = _lab(season)") == 2 and
      '_complete_case("lifecycle", before)' in runtime and
      '_complete_case("writer-retirement", before)' in runtime, "two bounded install cases")
check('not R.teardown(lab)' in runtime and 'R.teardown(lab)' in runtime and
      'not ball.physics_contact_router.is_valid()' in runtime, "active refusal and idle cleanup")
check('R.callback_bound(lab, property)' in runtime and 'property.retire_installation(' in runtime,
      "issued freshness and supported writer retirement")
check('get_meta("night_qualified", true) == false' in runtime and '"Light3D"' in runtime,
      "six dormant towers")
print(json.dumps({"checks": checks, "failures": 0, "engine_launched": False,
    "fixture_files": 7, "copies": 72, "item_counts": counts, "legacy_saves": 2,
    "runtime_installs": 2, "runtime_cases": ["lifecycle", "writer-retirement"],
    "daylight_captures": 7, "capture_size": [1280, 720],
    "sha256": {name: hashlib.sha256((HERE / name).read_bytes()).hexdigest() for name in NAMES}},
    sort_keys=True))
