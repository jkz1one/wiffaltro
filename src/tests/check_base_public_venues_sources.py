"""No-engine parser/lint, historical fixture pins and independent allocation oracle."""
from pathlib import Path
import hashlib
import json
import re
from lark import Lark
from gdtoolkit.parser import parser
from gdtoolkit.parser.gdscript_indenter import GDScriptIndenter
from gdtoolkit.linter import lint_code

HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parents[1]
WORKSPACE = CANDIDATE.parents[2]
BASE = WORKSPACE / "recovery-20261013/ay03/public-day-managed-smoke-20261015T0447Z"
MANIFEST = BASE / "COMPOSED_SOURCE_MANIFEST.json"
TOOLCHAIN = WORKSPACE / "recovery-20261013/toolchain/reconstructed-tooling-venv-copies"
NAMES = ["base_public_venues_data_test.gd", "base_public_venues_runtime_test.gd"]
V1 = "src/tests/fixtures/ay03_control_ay02_save61.json"
V2 = "src/tests/fixtures/base_control_ay03_save61_v2.json"
REPORT = "src/tests/fixtures/ay03_control_ay02_report15.json"
PINS = {
    V1: "aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067",
    V2: "86cbcd4827d265647b2f9eba6f58079d0347edb19d9658e80cb6fe345c96ae1d",
    REPORT: "20bbc936bbb2a60775cfd0bc73233f746b6648e8b7b5b2a5667c1f7873377564",
}
GOLDEN = {
    0: ["AY-03", "AE-01", "AC-01", "AE-01", "AY-01"],
    1: ["AC-01", "AE-01", "AY-02", "AE-01", "AY-03"],
    10: ["AE-01", "AE-01", "AC-01", "AY-03", "AY-01"],
    47: ["AC-01", "AE-01", "AY-03", "AY-02", "AE-01"],
    443: ["AE-01", "AE-01", "AY-01", "AC-01", "AY-02"],
    2147483647: ["AY-02", "AE-01", "AC-01", "AE-01", "AY-03"],
}
checks = []


def check(name, passed):
    checks.append({"name": name, "passed": bool(passed)})
    if not passed:
        raise AssertionError(name)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


base = json.loads(MANIFEST.read_text())["files"]


def resolve(relative):
    overlay = CANDIDATE / relative
    return overlay if overlay.is_file() else WORKSPACE / base[relative]["source"]


# As in the accepted source checks: no parser-cache or Python-bytecode writes.
grammar = TOOLCHAIN / "lib/python3.12/site-packages/gdtoolkit/parser/gdscript.lark"
memory = Lark.open(str(grammar), parser="lalr", start="start",
                   postlex=GDScriptIndenter(), propagate_positions=True,
                   maybe_placeholders=False, cache=False, regex=True)
parser.__dict__["_parser"] = memory
parser.__dict__["_parser_with_metadata"] = memory
for name in NAMES:
    text = (HERE / name).read_text()
    parser.parse(text)
    check("memory_parser:" + name, True)
    check("lint:" + name, not lint_code(text))
    check("scene_reference:" + name,
          f"res://src/tests/{name}" in (HERE / name).with_suffix(".tscn").read_text())
    for relative in re.findall(r'"res://([^"\n]+)"', text):
        check("resource_exists:" + relative, resolve(relative).is_file())

for relative, pin in PINS.items():
    check("actual_fixture_pin:" + relative, sha(resolve(relative)) == pin)
check("accepted_v2_fixture_byte_copy", resolve(V2).read_bytes() ==
      (BASE / "root-first/match/ay03-public-final-save.json").read_bytes())
for version, relative, venue in [(1, V1, "AY-02"), (2, V2, "AY-03")]:
    saved = json.loads(resolve(relative).read_text())
    evidence = saved["results"][0]["yard_evidence"]
    binding = evidence["property"]["binding"]
    check(f"actual_assignment{version}_save61", saved["version"] == 61 and
          saved["npc_venues"]["version"] == version and
          len(saved["npc_venues"]["assignments"]) == version)
    check(f"actual_assignment{version}_completed_fixture0", len(saved["results"]) == 1 and
          saved["results"][0]["id"] == 0 and len(saved["physical"]["reports"]) == 2 and
          saved["physical"]["pending"] == {} and evidence["property"]["manifest"]["id"] == venue)
    check(f"actual_assignment{version}_legacy_binding_shape", "assignment_version" not in binding
          and "environment_seed" not in binding and
          evidence["property"]["environment"]["seed"] == binding["match_seed"])
helper = base["src/tests/stadium_npc_yard_two_public_checks.gd"]
check("accepted_full_precision_settled_helper", helper["sha256"] ==
      "7adda9013489a154db9debbf90403d5cb9ef8fee5443bfa179947772bb4b0582" and
      sha(WORKSPACE / helper["source"]) == helper["sha256"])
old = json.loads(resolve(REPORT).read_text())
check("synthetic_schema_lift_has_only_matching_yard_graph", old["version"] == 15 and
      old["yard"] == [] and all(event["source"] == "boundary" and
      event["id"] == "PERIM-BACKYARD-STRAIGHT-BX1-v1"
      for row in old["surfaces"] for event in row["events"]))


# Independent source-only model; this is not native allocation or game evidence.
def stream(seed, name):
    value = f"ordinary-venues-v3:{name}:{seed}:1:0".encode()
    return int(hashlib.sha256(value).hexdigest()[:8], 16) & 0x7fffffff


def draw(state, bound):
    limit = (1 << 32) - ((1 << 32) % bound)
    while True:
        value = f"ordinary-venues-v3:shuffle:{state[0]}:{state[1]}".encode()
        state[1] += 1
        value = int(hashlib.sha256(value).hexdigest()[:8], 16)
        if value < limit:
            return value % bound


def shuffle(values, state):
    values = list(values)
    for index in range(len(values) - 1, 0, -1):
        other = draw(state, index + 1)
        values[index], values[other] = values[other], values[index]
    return values


predictions = []
data_text = (HERE / NAMES[0]).read_text()
runtime_text = (HERE / NAMES[1]).read_text()
for seed, expected in GOLDEN.items():
    states = {name: [stream(seed, name), 0] for name in ["layout", "owner", "environment"]}
    selected = shuffle(sorted(["AY-01", "AY-02", "AY-03"]), states["layout"])[:2]
    selected += ["AE-01", "AE-01", "AC-01"]
    selected = shuffle(selected, states["owner"])
    environments = [draw(states["environment"], 1 << 31) for _ in range(32)]
    check(f"independent_map_golden:{seed}", selected == expected)
    check(f"native_map_golden_present:{seed}", f'{seed}: {json.dumps(expected)}' in data_text)
    check(f"independent_environment_match_seeds_distinct:{seed}", all(
        value != ((seed + fixture * 104729) & 0x7fffffff)
        for fixture, value in enumerate(environments)))
    predictions.append({"seed": seed, "career_run": 1, "venue_ordinal": 0,
                        "owners_1_to_5": selected, "environment_first3": environments[:3]})
check("environment_draw_golden", predictions[4]["environment_first3"] ==
      [2386655, 1737811887, 1397012882])
check("no_pitch_or_full_game_calls_in_focused_runtime", all(token not in runtime_text for token in
      ["_throw_pitch(", "_start_ball_in_play(", "record_player_result(", "MatchAutomation.new("]))
check("schema_lift_explicitly_not_game_evidence", "Synthetic envelope lift only" in data_text and
      "never reaches season settlement" in data_text)
check("actual_lifecycle_gate_precedes_negative_probes", runtime_text.index("ordinary public startup") <
      runtime_text.index("_identity(lab, property)"))
check("runtime_starts_after_root_ready", "_run.call_deferred()" in runtime_text and
      "func _run() -> void:" in runtime_text)
check("separate_coverage_markers", "BASE_PUBLIC_COVERAGE_DATA" in data_text and
      "BASE_PUBLIC_COVERAGE_RUNTIME" in runtime_text)

owned = NAMES + [Path(name).with_suffix(".tscn").name for name in NAMES]
owned += ["fixtures/base_control_ay03_save61_v2.json"]
result = {
    "status": "SOURCE_ONLY_NATIVE_DATA_AND_RUNTIME_UNRUN",
    "engine_launched": False, "new_game_evidence": False,
    "checks": checks, "failures": sum(not item["passed"] for item in checks),
    "base_manifest_sha256": sha(MANIFEST),
    "independent_source_predictions": predictions,
    "actual_historical_fixtures": {relative: {"source": str(resolve(relative).relative_to(WORKSPACE)),
        "sha256": pin, "bytes": resolve(relative).stat().st_size} for relative, pin in PINS.items()},
    "v2_original_source": str((BASE / "root-first/match/ay03-public-final-save.json").relative_to(WORKSPACE)),
    "owned_files": {name: {"sha256": sha(HERE / name), "bytes": (HERE / name).stat().st_size}
                    for name in owned},
    "prospective_native_coverage": {"golden_maps": 6, "routed_hosts": 5, "installed_families": 3},
    "native_total_check_counts": "Unrun; do not infer native pass counts from source checks.",
    "report17_schema": "In-memory accepted AY02 core/boundary lift to AY01 binding only; never "
        "persisted, settled or represented as actual AY01/AE01/AC01 gameplay.",
}
(HERE / "base_public_venues_source_checks.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"source_checks": len(checks), "failures": result["failures"],
                  "native": "UNRUN", "engine_launched": False}))
