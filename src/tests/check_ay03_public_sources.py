"""Source/fixture checks only. This script never imports or launches Godot."""
from pathlib import Path
import hashlib
import json
from lark import Lark
from gdtoolkit.parser import parser
from gdtoolkit.parser.gdscript_indenter import GDScriptIndenter
from gdtoolkit.linter import lint_code

HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parents[1]
WORKSPACE = CANDIDATE.parents[2]
JOINED = WORKSPACE / "recovery-20261013/ay02/joined-public-pool-pinfix-20261015T0420Z"
TOOLCHAIN = WORKSPACE / "recovery-20261013/toolchain/reconstructed-tooling-venv-copies"
SCRIPT_NAMES = [
    "stadium_npc_yard_three_public_data_test.gd",
    "stadium_npc_yard_three_public_runtime_test.gd",
]
PINS = {
    "ay03_control_ay02_save61.json":
        "aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067",
    "ay03_control_ay02_report15.json":
        "20bbc936bbb2a60775cfd0bc73233f746b6648e8b7b5b2a5667c1f7873377564",
}
checks = []


def check(name, passed):
    checks.append({"name": name, "passed": bool(passed)})
    if not passed:
        raise AssertionError(name)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Match the R13 checker: no gdtoolkit parser caches or Python bytecode writes.
grammar = TOOLCHAIN / "lib/python3.12/site-packages/gdtoolkit/parser/gdscript.lark"
memory = Lark.open(str(grammar), parser="lalr", start="start",
                   postlex=GDScriptIndenter(), propagate_positions=True,
                   maybe_placeholders=False, cache=False, regex=True)
parser.__dict__["_parser"] = memory
parser.__dict__["_parser_with_metadata"] = memory
for name in SCRIPT_NAMES:
    path = HERE / name
    text = path.read_text()
    parser.parse(text)
    check("memory_parser:" + name, True)
    problems = lint_code(text)
    check("lint:" + name, not problems)
    scene = path.with_suffix(".tscn").read_text()
    check("scene_reference:" + name, f"res://src/tests/{name}" in scene)

for name, pin in PINS.items():
    check("actual_fixture_pin:" + name, sha(HERE / "fixtures" / name) == pin)
old = json.loads((HERE / "fixtures/ay03_control_ay02_save61.json").read_text())
report = json.loads((HERE / "fixtures/ay03_control_ay02_report15.json").read_text())
check("old61_assignment1_unchanged", old["version"] == 61 and
      old["npc_venues"]["version"] == 1 and
      list(old["npc_venues"]["assignments"]) == ["5"] and
      old["npc_venues"]["assignments"]["5"]["manifest"]["id"] == "AY-02")
check("actual_completed_fixture0_for_existing_helper", len(old["results"]) == 1 and len(old["physical"]["reports"]) == 2 and
      old["results"][0]["id"] == 0 and "yard_evidence" in old["results"][0] and
      not old["physical"]["pending"])
check("report15_exact_AY02_not_AY03_evidence", report["version"] == 15 and
      report["resolver"] == "physical-ai-ay02-away-v1" and
      report["property"]["manifest"]["id"] == "AY-02" and
      len(report["plays"]) == 124)
check("schema_lift_has_no_AY02_specific_events", report["yard"] == [] and all(
    event["source"] == "boundary" for row in report["surfaces"] for event in row["events"]))
manifest = json.loads((JOINED / "COMPOSED_SOURCE_MANIFEST.json").read_text())
helper = manifest["files"]["src/tests/stadium_npc_yard_two_public_checks.gd"]
check("joined_R13_full_precision_helper", helper["sha256"] ==
      "7adda9013489a154db9debbf90403d5cb9ef8fee5443bfa179947772bb4b0582" and
      sha(WORKSPACE / helper["source"]) == helper["sha256"])
assignments = []
for seed in [0, 1, 47, 443, 2147483647]:
    owner = 1 + int(hashlib.sha256(f"ay02-away-v1:{seed}".encode()).hexdigest()[:8], 16) % 5
    others = [club for club in range(1, 6) if club != owner]
    next_owner = others[int(hashlib.sha256(f"ay03-away-v1:{seed}".encode()).hexdigest()[:8], 16) % 4]
    assignments.append({"seed": seed, "AY-02": owner, "AY-03": next_owner})
check("independent_seed443_contract", assignments[3] == {"seed": 443, "AY-02": 4, "AY-03": 3})
check("all_owner_pairs_disjoint", all(row["AY-02"] != row["AY-03"] for row in assignments))
files = SCRIPT_NAMES + [Path(n).with_suffix(".tscn").name for n in SCRIPT_NAMES]
files += ["fixtures/" + n for n in PINS]
result = {
    "status": "SOURCE_ONLY_NATIVE_DATA_AND_RUNTIME_TESTS_UNRUN",
    "engine_launched": False, "new_game_evidence": False,
    "checks": checks, "failures": sum(not row["passed"] for row in checks),
    "independent_assignment_examples": assignments,
    "joined_manifest_sha256": sha(JOINED / "COMPOSED_SOURCE_MANIFEST.json"),
    "historical_helper": helper,
    "files": {name: {"sha256": sha(HERE / name), "bytes": (HERE / name).stat().st_size}
              for name in files},
    "report_schema_control": "In-memory duplicate of accepted AY02 core/boundary rows; changes "
        "version, resolver, property and seed only. Never persisted, settled or claimed as AY03 play.",
}
(HERE / "ay03_public_source_checks.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"source_checks": len(checks), "failures": result["failures"],
                  "native": "UNRUN", "engine_launched": False}))
