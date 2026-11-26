"""Compare generated CPU physics reports to the pinned rendered report pair."""
import argparse
from collections import Counter
from hashlib import sha256
import json
import math
from pathlib import Path

REFERENCE = "614fe931fdcb03c0327b5473d3f59dddd0efcad7a5bbbf52f3d22a3e754519e4"

def differences(expected, actual, path=""):
    if isinstance(expected, dict) and isinstance(actual, dict):
        for key in sorted(expected.keys() | actual.keys()):
            at = f"{path}/{key}"
            if key not in expected or key not in actual:
                yield at, "material"
            else:
                yield from differences(expected[key], actual[key], at)
    elif isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            yield path, "material"
        for index, (left, right) in enumerate(zip(expected, actual)):
            yield from differences(left, right, f"{path}/{index}")
    elif type(expected) is bool or type(actual) is bool:
        if expected is not actual:
            yield path, "material"
    elif expected != actual:
        if path == "/physical/elapsed" and all(type(x) in (int, float) and math.isfinite(x) and x > 0 for x in (expected, actual)):
            yield path, "outer_elapsed"
        elif (type(expected) is float and type(actual) is float
              and math.isfinite(expected) and math.isfinite(actual)
              and abs(expected - actual) <= max(math.ulp(expected), math.ulp(actual))):
            yield path, "one_ulp"
        else:
            yield path, "material"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rendered", type=Path)
    parser.add_argument("generated_dir", type=Path)
    args = parser.parse_args()
    body = args.rendered.read_bytes()
    if sha256(body).hexdigest() != REFERENCE:
        parser.error("expected the exact generated CP418 two-report fixture")
    reports = json.loads(body.split(b"\n", 2)[2])["current"]["dynasty"]["physical"]["pending"]["reports"]
    if [row["fixture"] for row in reports] != [4, 5]:
        parser.error("unexpected fixture order")
    for row in reports:
        fixture = int(row["fixture"])
        actual = json.loads((args.generated_dir / f"fixture{fixture}.json").read_bytes())
        delta = list(differences(row["report"], actual))
        counts = Counter(kind for _, kind in delta)
        report = actual["physical"]
        print(f"fixture {fixture}: {report['away_runs']}–{report['home_runs']}, {len(report['plays'])} plays; {dict(counts)}")
        if counts["material"]:
            print("unexpected report differences:", [path for path, kind in delta if kind == "material"][:25])
            return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
