#!/usr/bin/env python3
"""Propose renderer-bound v2 profiles, verify legacy/v2, or install reviewed v2 only.

Proposal/verification NEVER write the runtime profile. An installation requires a
separate review record tied to the exact candidate digest and explicit rationale
for EVERY replacement. Review is a human/engineering process, not a hash refresh.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

RUNTIME = "src/presentation/stadium/stadium_npc_public_runtime.gd"
PROFILE = "src/presentation/stadium/stadium_npc_current_source_profile.gd"
LEGACY_SCHEMA = "npc-composed-source-review-v1"
SCHEMA = "npc-composed-source-review-v2"
RENDERER_ID = "literal-prefix-compact"
RENDERER_VERSION = 12


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def digest(value: dict) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def baseline(root: Path) -> dict[str, str]:
    text = (root / RUNTIME).read_text()
    block = text.split("const SOURCE_PINS: Dictionary = {", 1)[1].split("\n}", 1)[0]
    result = dict(re.findall(r'"(res://[^"\n]+)":\s*"([0-9a-f]{64})"', block))
    if not result:
        raise ValueError("No original source pins found")
    return result


def baseline_digest(pins: dict[str, str]) -> str:
    return hashlib.sha256("".join(f"{p}:{pins[p]}\n" for p in sorted(pins)).encode()).hexdigest()


def resolve(root: Path, resource: str) -> Path:
    if not resource.startswith("res://"):
        raise ValueError("Not a resource path: " + resource)
    path = (root / resource[6:]).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError("Missing or escaping source: " + resource)
    return path


def inventory(root: Path, pins: dict[str, str]) -> dict[str, str]:
    # Conservative superset of transitive code: every production script, scene,
    # shader and resource, not just textually discoverable class references.
    # All literal external res:// dependencies are then followed recursively.
    paths = {"res://" + p.relative_to(root).as_posix() for p in (root / "src").rglob("*")
             if p.is_file() and "tests" not in p.relative_to(root).parts
             and p.suffix in {".gd", ".tres", ".tscn", ".gdshader"}}
    paths |= set(pins) | {"res://project.godot"}
    paths.discard("res://" + PROFILE)  # Trust anchor, like original SOURCE_PINS.
    pending = list(paths)
    seen: set[str] = set()
    while pending:
        resource = pending.pop()
        if resource in seen:
            continue
        seen.add(resource)
        path = resolve(root, resource)
        if path.suffix not in {".gd", ".tres", ".tscn", ".gdshader", ".godot"}:
            continue
        for match in re.findall(r'[\"\'](res://[^\"\'\n]+)[\"\']', path.read_text()):
            if match == "res://" + PROFILE or not (root / match[6:]).is_file():
                continue  # Directory/format-string literals are not resources.
            if match not in paths:
                paths.add(match)
                pending.append(match)
    return {p: sha(resolve(root, p)) for p in sorted(paths)}


def _legacy_proposal(root: Path, profile_id: str, purpose: str) -> dict:
    pins = baseline(root)
    current = inventory(root, pins)
    return {
        "schema": LEGACY_SCHEMA, "profile_id": profile_id, "purpose": purpose,
        "baseline_sha256": baseline_digest(pins), "baseline_count": len(pins),
        "replacements": {p: {"original": old, "current": current[p]}
                         for p, old in sorted(pins.items()) if current[p] != old},
        "dependencies": {p: value for p, value in current.items() if p not in pins},
        "fixtures": {"res://" + p.relative_to(root).as_posix(): sha(p)
                     for p in sorted((root / "src/tests/fixtures").rglob("*")) if p.is_file()},
    }


def renderer_binding() -> dict:
    return {"id": RENDERER_ID, "version": RENDERER_VERSION,
            "generator_sha256": sha(Path(__file__).resolve())}


def _require_renderer(value: object) -> None:
    if not isinstance(value, dict) or set(value) != {"id", "version", "generator_sha256"}:
        raise ValueError("Exact renderer identifier/version/generator SHA binding required")
    if type(value["version"]) is not int or value != renderer_binding():
        raise ValueError("Unknown or changed renderer/tool bytes; requires a NEW proposal and review")


def proposal(root: Path, profile_id: str, purpose: str) -> dict:
    value = _legacy_proposal(root, profile_id, purpose)
    value["schema"] = SCHEMA
    value["renderer"] = renderer_binding()
    return value


def verify(root: Path, candidate: dict) -> None:
    if candidate.get("schema") not in {LEGACY_SCHEMA, SCHEMA} or candidate.get("purpose") not in {"isolated-test", "final"}:
        raise ValueError("Invalid profile schema or purpose")
    if candidate["schema"] == SCHEMA:
        _require_renderer(candidate.get("renderer"))
        now = proposal(root, candidate["profile_id"], candidate["purpose"])
    else:
        # Legacy artifacts have no renderer binding: preserve original verification only.
        now = _legacy_proposal(root, candidate["profile_id"], candidate["purpose"])
    if now != candidate:
        changed = [k for k in now if now[k] != candidate.get(k)]
        raise ValueError("Candidate invalidated; requires NEW review, not resealing: " + ", ".join(changed))


def _legacy_reviewed_source(candidate: dict, review: dict) -> str:
    if review.get("candidate_sha256") != digest(candidate) or review.get("decision") != "approved":
        raise ValueError("Separate exact-candidate approval record required")
    if review.get("purpose") != candidate["purpose"] or not review.get("reviewer"):
        raise ValueError("Review purpose/reviewer missing or mismatched")
    reasons = review.get("replacement_rationale", {})
    if set(reasons) != set(candidate["replacements"]) or not all(
            isinstance(v, str) and v.strip() for v in reasons.values()):
        raise ValueError("Each replacement needs an explicit review rationale")
    if review.get("dependencies_sha256") != digest(candidate["dependencies"]):
        raise ValueError("Exact dependency inventory approval required")
    if review.get("fixtures_sha256") != digest(candidate["fixtures"]):
        raise ValueError("Exact unchanged fixture inventory approval required")
    if not review.get("evidence"):
        raise ValueError("Review evidence is required")
    replacements = {p: item["current"] for p, item in candidate["replacements"].items()}
    # JSON dictionaries/string literals are valid GDScript constant syntax.
    return ("extends RefCounted\n"
            "## Explicitly reviewed whole-source profile. Do not refresh automatically.\n"
            f"## Purpose: {candidate['purpose']}; candidate: {digest(candidate)}\n\n"
            f"const PROFILE_ID: String = {json.dumps(candidate['profile_id'])}\n"
            'const REVIEW_STATUS: String = "reviewed"\n'
            f"const BASELINE_SHA256: String = {json.dumps(candidate['baseline_sha256'])}\n"
            "const REPLACEMENTS: Dictionary = " + json.dumps(replacements, indent=2, sort_keys=True) + "\n"
            "const DEPENDENCIES: Dictionary = " + json.dumps(candidate["dependencies"], indent=2, sort_keys=True) + "\n")


def _prefix_name(index: int) -> str:
    # Private uppercase names cannot collide with built-in constants (PI, OK).
    # Use the shortest names for the largest groups, preserving deterministic ties.
    letters = ""
    while index >= 0:
        letters = chr(ord("A") + index % 26) + letters
        index = index // 26 - 1
    return "_" + letters


def _suffix_limit(name: str) -> int:
    # A generated entry has compact key concatenation and a literal SHA-256 value.
    # Escaped/unusual keys still go through the exact emitted-line length checks.
    empty_row = "\t" + name + '+"":' + json.dumps("0" * 64) + ","
    return 100 - len(empty_row) - 2


def _profile_prefixes(keys: set[str]) -> dict[str, str]:
    # Deterministic literal factoring only; no source/path/hash selection changes.
    # Retain singleton prefixes too: paired declarations can replace two split
    # entries with one declaration line and two complete entries, at the same
    # density as shared prefixes. Each path and hash remains a literal String.
    remaining = set(keys)
    prefixes: dict[str, str] = {}
    while remaining:
        name = _prefix_name(len(prefixes))
        suffix_limit = _suffix_limit(name)
        options = {key[:-suffix_limit] for key in remaining if len(key) > suffix_limit}
        if not options:
            break
        prefix = max(options, key=lambda item: (
            sum(key.startswith(item) and len(key) - len(item) <= suffix_limit
                for key in remaining), -len(item), item))
        covered = {key for key in remaining
                   if key.startswith(prefix) and len(key) - len(prefix) <= suffix_limit}
        if len(covered) == 1 and len("\t" + json.dumps(next(iter(covered)))
                                    + ":" + json.dumps("0" * 64) + ",") <= 100:
            remaining -= covered  # A literal row already fits; no singleton is needed.
            continue
        if len(prefixes) >= 1296:
            raise ValueError("Profile prefix representation exceeds deterministic bound")
        prefixes[prefix] = name
        remaining -= covered
    return {prefix: prefixes[prefix] for prefix in sorted(prefixes)}


def _pack_map_tokens(opening: str, tokens: list[tuple[str, bool]]) -> str:
    # Inside a Dictionary literal GDScript permits implicit line continuation.
    # Pack only literal Strings, identifiers and punctuation. A split String is
    # joined with constant +, never encoded, abbreviated or reconstructed at run
    # time. Split on Python codepoint boundaries BEFORE JSON escaping, preserving
    # escapes and Unicode. Keep at least four codepoints in both split fragments.
    lines = [opening]
    for value, literal in tokens:
        token = json.dumps(value) if literal else value
        while len(lines[-1]) + len(token) > 100:
            if literal:
                low, high = 4, len(value) - 4
                size = 0
                while low <= high:
                    middle = (low + high) // 2
                    if len(lines[-1]) + len(json.dumps(value[:middle])) + 1 <= 100:
                        size = middle
                        low = middle + 1
                    else:
                        high = middle - 1
                if size:
                    lines[-1] += json.dumps(value[:size]) + "+"
                    value = value[size:]
                    token = json.dumps(value)
            if not lines[-1]:
                raise ValueError("Exact profile cannot meet line limits; unsplittable token")
            lines.append("")
        lines[-1] += token
    return "\n".join(lines) + "\n"


def _profile_map(name: str, values: dict[str, str], prefixes: dict[str, str]) -> str:
    tokens: list[tuple[str, bool]] = []
    for key, value in sorted(values.items()):
        matches = [prefix for prefix in prefixes
                   if key.startswith(prefix) and len(key) - len(prefix) <= _suffix_limit(prefixes[prefix])]
        if matches:
            prefix = max(matches, key=lambda item: (len(item), item))
            tokens.extend([(prefixes[prefix], False), ("+", False),
                           (key[len(prefix):], True)])
        else:
            tokens.append((key, True))
        tokens.extend([(":", False), (value, True), (",", False)])
    if tokens:
        tokens[-1] = ("}", False)
    else:
        tokens.append(("}", False))
    return _pack_map_tokens(f"const {name}: Dictionary = {{", tokens)


def _prefix_declarations(prefixes: dict[str, str], metadata: tuple[str, ...] = ()) -> str:
    # Reuse only existing literal String prefixes; add no helpers or runtime work.
    # Visit shorter prefixes first. A factored declaration can only be placed
    # on/after its parent's line, and is appended after that parent on the line.
    # First-fit packing stays deterministic with at most five declarations/line.
    lines = []
    counts: list[int] = []
    placed: dict[str, int] = {}
    earlier: list[str] = []
    for prefix in sorted(prefixes, key=lambda item: (len(item), item)):
        expression = json.dumps(prefix)
        parent = None
        matches = [item for item in earlier if prefix.startswith(item)]
        if matches:
            match = max(matches, key=lambda item: (len(item), item))
            factored = prefixes[match] + "+" + json.dumps(prefix[len(match):])
            if len(factored) < len(expression):
                expression = factored
                parent = match
        row = f"const {prefixes[prefix]}={expression}"
        first = placed[parent] if parent is not None else 0
        target = next((index for index in range(first, len(lines))
                       if counts[index] < 5 and len(lines[index]) + 1 + len(row) <= 100), None)
        if target is None:
            target = len(lines)
            lines.append(row)
            counts.append(1)
        else:
            lines[target] += ";" + row
            counts[target] += 1
        placed[prefix] = target
        earlier.append(prefix)
    # Metadata literals are independent of prefixes. Fill remaining space only
    # after prefix placement, preserving every existing prefix/map expression.
    for row in metadata:
        target = next((index for index in range(len(lines))
                       if counts[index] < 5 and len(lines[index]) + 1 + len(row) <= 100), None)
        if target is None:
            lines.append(row)
            counts.append(1)
        else:
            lines[target] += ";" + row
            counts[target] += 1
    return "\n".join(lines) + ("\n" if lines else "")


def _compact_reviewed_source(candidate: dict, review: dict) -> str:
    if review.get("candidate_sha256") != digest(candidate) or review.get("decision") != "approved":
        raise ValueError("Separate exact-candidate approval record required")
    if review.get("purpose") != candidate["purpose"] or not review.get("reviewer"):
        raise ValueError("Review purpose/reviewer missing or mismatched")
    reasons = review.get("replacement_rationale", {})
    if set(reasons) != set(candidate["replacements"]) or not all(
            isinstance(v, str) and v.strip() for v in reasons.values()):
        raise ValueError("Each replacement needs an explicit review rationale")
    if review.get("dependencies_sha256") != digest(candidate["dependencies"]):
        raise ValueError("Exact dependency inventory approval required")
    if review.get("fixtures_sha256") != digest(candidate["fixtures"]):
        raise ValueError("Exact unchanged fixture inventory approval required")
    if not review.get("evidence"):
        raise ValueError("Review evidence is required")
    replacements = {p: item["current"] for p, item in candidate["replacements"].items()}
    prefixes = _profile_prefixes(set(replacements) | set(candidate["dependencies"]))
    source = (f"extends RefCounted # Candidate: {digest(candidate)}\n"
              "## Explicitly reviewed whole-source profile. Do not refresh automatically.\n"
              f"const PROFILE_ID: String = {json.dumps(candidate['profile_id'])} "
              f"# Purpose: {candidate['purpose']}\n")
    source += _prefix_declarations(prefixes, (
        'const REVIEW_STATUS: String = "reviewed"',
        f"const BASELINE_SHA256: String = {json.dumps(candidate['baseline_sha256'])}",
    ))
    source += _profile_map("REPLACEMENTS", replacements, prefixes)
    source += _profile_map("DEPENDENCIES", candidate["dependencies"], prefixes)
    if len(source.splitlines()) > 1000 or any(len(line) > 100 for line in source.splitlines()):
        raise ValueError("Exact profile cannot meet line limits; requires a new renderer design")
    return source



def reviewed_source(candidate: dict, review: dict) -> str:
    if candidate.get("schema") == LEGACY_SCHEMA:
        # Never use compact output as a fallback for a legacy approval.
        return _legacy_reviewed_source(candidate, review)
    if candidate.get("schema") != SCHEMA:
        raise ValueError("Unknown profile schema")
    _require_renderer(candidate.get("renderer"))
    _require_renderer(review.get("renderer"))
    return _compact_reviewed_source(candidate, review)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    sub = parser.add_subparsers(dest="command", required=True)
    propose = sub.add_parser("propose")
    propose.add_argument("--id", required=True)
    propose.add_argument("--purpose", choices=["isolated-test", "final"], required=True)
    propose.add_argument("--output", type=Path, required=True)
    check = sub.add_parser("verify")
    check.add_argument("candidate", type=Path)
    installed = sub.add_parser("verify-installed")
    installed.add_argument("candidate", type=Path)
    installed.add_argument("review", type=Path)
    installed.add_argument("--profile", type=Path, required=True)
    install = sub.add_parser("install-reviewed")
    install.add_argument("candidate", type=Path)
    install.add_argument("review", type=Path)
    install.add_argument("--output", type=Path, required=True,
                         help="Explicit output; only the exact runtime profile path activates it")
    args = parser.parse_args()
    if args.command == "propose":
        value = proposal(args.root, args.id, args.purpose)
        if args.output.resolve() == (args.root / PROFILE).resolve():
            raise ValueError("Proposal must never overwrite the runtime trust anchor")
        with args.output.open("x") as output:
            json.dump(value, output, indent=2, sort_keys=True)
            output.write("\n")
        print("UNREVIEWED candidate_sha256=" + digest(value))
    else:
        value = json.loads(args.candidate.read_text())
        verify(args.root, value)
        if args.command == "install-reviewed" and value.get("schema") != SCHEMA:
            raise ValueError("Legacy profiles are verification-only; installation requires renderer-bound v2 review")
        if args.command in {"install-reviewed", "verify-installed"}:
            source = reviewed_source(value, json.loads(args.review.read_text()))
            if args.command == "verify-installed":
                if args.profile.read_text() != source:
                    raise ValueError("Installed trust anchor differs from exact reviewed profile")
                print("Exact source inventory AND installed reviewed trust anchor intact; no writes")
            else:
                # No chmod, no retry/refresh and no source mutation other than explicit output.
                args.output.write_text(source)
                print("Installed reviewed " + value["purpose"] + " profile at " + str(args.output))
        else:
            print("Exact candidate intact; no writes performed; candidate_sha256=" + digest(value))


if __name__ == "__main__":
    main()
