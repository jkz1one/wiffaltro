"""Source-policy tests; do not confuse these with native public gameplay tests."""
import copy
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

import npc_current_source_profile as policy


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.old = "a" * 64
        p = self.root / policy.RUNTIME
        p.parent.mkdir(parents=True)
        p.write_text('const SOURCE_PINS: Dictionary = {\n"res://src/old.gd": "' + self.old + '"\n}\n')
        (self.root / "src/old.gd").write_text("extends RefCounted\n")
        (self.root / "src/new.gd").write_text("extends RefCounted\n# new dependency\n")
        (self.root / "project.godot").write_text("config_version=5\n")
        fixtures = self.root / "src/tests/fixtures"
        fixtures.mkdir(parents=True)
        (fixtures / "frozen.json").write_text('{"version":1}\n')
        self.candidate = policy.proposal(self.root, "test-only", "isolated-test")
        self.review = {
            "candidate_sha256": policy.digest(self.candidate), "decision": "approved",
            "purpose": "isolated-test", "reviewer": "test-only",
            "replacement_rationale": {p: "test-only change" for p in self.candidate["replacements"]},
            "dependencies_sha256": policy.digest(self.candidate["dependencies"]),
            "fixtures_sha256": policy.digest(self.candidate["fixtures"]),
            "evidence": ["test fixture only"],
            "renderer": self.candidate["renderer"],
        }

    def test_intact_proposal_verifies_without_writing_profile(self):
        policy.verify(self.root, self.candidate)
        self.assertFalse((self.root / policy.PROFILE).exists())

    def test_replacement_tamper_rejected(self):
        (self.root / "src/old.gd").write_text("tampered")
        with self.assertRaises(ValueError):
            policy.verify(self.root, self.candidate)

    def test_dependency_tamper_rejected(self):
        (self.root / "src/new.gd").write_text("tampered")
        with self.assertRaises(ValueError):
            policy.verify(self.root, self.candidate)

    def test_new_production_file_invalidates_review(self):
        (self.root / "src/later.gd").write_text("extends RefCounted\n")
        with self.assertRaises(ValueError):
            policy.verify(self.root, self.candidate)

    def test_frozen_fixture_change_rejected(self):
        (self.root / "src/tests/fixtures/frozen.json").write_text("{}")
        with self.assertRaises(ValueError):
            policy.verify(self.root, self.candidate)

    def test_mixed_profile_rejected(self):
        mixed = copy.deepcopy(self.candidate)
        mixed["replacements"]["res://src/old.gd"]["current"] = self.old
        with self.assertRaises(ValueError):
            policy.verify(self.root, mixed)

    def test_missing_review_rejected(self):
        with self.assertRaises(ValueError):
            policy.reviewed_source(self.candidate, {})

    def test_missing_replacement_rationale_rejected(self):
        self.review["replacement_rationale"] = {}
        with self.assertRaises(ValueError):
            policy.reviewed_source(self.candidate, self.review)

    def test_wrong_inventory_review_rejected(self):
        self.review["dependencies_sha256"] = "f" * 64
        with self.assertRaises(ValueError):
            policy.reviewed_source(self.candidate, self.review)

    def test_changed_candidate_cannot_reuse_review(self):
        value = copy.deepcopy(self.candidate)
        value["profile_id"] = "different"
        with self.assertRaises(ValueError):
            policy.reviewed_source(value, self.review)

    def test_exact_review_emits_profile_without_implicit_write(self):
        source = policy.reviewed_source(self.candidate, self.review)
        self.assertIn('const REVIEW_STATUS: String = "reviewed"', source)
        self.assertFalse((self.root / policy.PROFILE).exists())


    def _review_for(self, candidate):
        review = copy.deepcopy(self.review)
        review.update({
            "candidate_sha256": policy.digest(candidate),
            "replacement_rationale": {p: "renderer test only" for p in candidate["replacements"]},
            "dependencies_sha256": policy.digest(candidate["dependencies"]),
            "fixtures_sha256": policy.digest(candidate["fixtures"]),
        })
        if "renderer" in candidate:
            review["renderer"] = copy.deepcopy(candidate["renderer"])
        else:
            review.pop("renderer", None)
        return review

    def _decoded_maps(self, source):
        # Independent restricted grammar evaluator. Never call renderer helpers.
        decoder = json.JSONDecoder()
        constants = {}

        def expression(text, offset):
            result = ""
            while True:
                offset += len(text[offset:]) - len(text[offset:].lstrip())
                if text[offset:offset + 1] == '"':
                    value, offset = decoder.raw_decode(text, offset)
                else:
                    match = re.match(r"_[A-Z]+", text[offset:])
                    self.assertIsNotNone(match, text[offset:])
                    self.assertIn(match[0], constants)  # No forward references/cycles.
                    value = constants[match[0]]
                    offset += len(match[0])
                self.assertIs(type(value), str)
                result += value
                offset += len(text[offset:]) - len(text[offset:].lstrip())
                if text[offset:offset + 1] != "+":
                    return result, offset
                offset += 1

        for line in source.splitlines():
            if not line.startswith(("const _", "const REVIEW_STATUS:", "const BASELINE_SHA256:")):
                continue
            offset = 0
            while offset < len(line):
                match = re.match(r"const (_[A-Z]+|REVIEW_STATUS|BASELINE_SHA256)(?:: String )?=", line[offset:])
                self.assertIsNotNone(match, line[offset:])
                name = match[1]
                self.assertNotIn(name, constants)
                value, offset = expression(line, offset + len(match[0]))
                constants[name] = value
                if offset < len(line):
                    self.assertEqual(line[offset], ";")
                    offset += 1
        result = {}
        for name in ["REPLACEMENTS", "DEPENDENCIES"]:
            body = source.split("const " + name + ": Dictionary = {", 1)[1]
            values = {}
            offset = 0
            while True:
                offset += len(body[offset:]) - len(body[offset:].lstrip())
                if body[offset:offset + 1] == "}":
                    break
                key, offset = expression(body, offset)
                self.assertEqual(body[offset], ":")
                value, offset = expression(body, offset + 1)
                self.assertNotIn(key, values)
                self.assertRegex(value, r"^[0-9a-f]{64}$")
                values[key] = value
                if body[offset:offset + 1] == ",":
                    offset += 1
                else:
                    self.assertEqual(body[offset:offset + 1], "}")
            following = body[offset + 1:]
            if name == "REPLACEMENTS":
                self.assertTrue(following.startswith("\nconst DEPENDENCIES: Dictionary = {"))
            else:
                self.assertFalse(following.strip())
            result[name] = values
        return result

    def test_renderer_revision_and_generator_are_explicitly_bound(self):
        binding = policy.renderer_binding()
        self.assertEqual(binding["id"], "literal-prefix-compact")
        self.assertEqual(binding["version"], 12)
        self.assertEqual(binding["generator_sha256"], policy.sha(Path(policy.__file__).resolve()))
        self.assertEqual(self.candidate["renderer"], binding)

    def test_stale_renderer_candidate_rejected_by_verify_and_render(self):
        invalid_fields = [("version", version) for version in range(1, 11)] + [
            ("version", True), ("version", 11.0), ("version", "11"), ("version", None),
            ("id", "unknown"), ("generator_sha256", "0" * 64),
            ("generator_sha256", None),
        ]
        for field, value in invalid_fields:
            with self.subTest(field=field, value=value):
                candidate = copy.deepcopy(self.candidate)
                candidate["renderer"][field] = value
                with self.assertRaises(ValueError):
                    policy.verify(self.root, candidate)
                # Even an approval of the exact stale candidate cannot select new bytes.
                with self.assertRaises(ValueError):
                    policy.reviewed_source(candidate, self._review_for(candidate))

    def test_stale_renderer_review_rejected_for_fresh_candidate(self):
        invalid_fields = [("version", version) for version in range(1, 11)] + [
            ("version", True), ("version", 11.0), ("version", "11"), ("version", None),
            ("id", "unknown"), ("generator_sha256", "0" * 64),
            ("generator_sha256", None),
        ]
        for field, value in invalid_fields:
            review = copy.deepcopy(self.review)
            review["renderer"][field] = value
            with self.assertRaises(ValueError):
                policy.reviewed_source(self.candidate, review)

    def test_missing_extra_or_non_mapping_renderer_binding_rejected(self):
        bindings = [None, [], "renderer10", {}, {**policy.renderer_binding(), "extra": True}]
        bindings.extend({key: value for key, value in policy.renderer_binding().items()
                         if key != missing} for missing in policy.renderer_binding())
        for binding in bindings:
            candidate = copy.deepcopy(self.candidate)
            candidate["renderer"] = binding
            with self.assertRaises(ValueError):
                policy.verify(self.root, candidate)
            with self.assertRaises(ValueError):
                policy.reviewed_source(candidate, self._review_for(candidate))
            review = copy.deepcopy(self.review)
            review["renderer"] = binding
            with self.assertRaises(ValueError):
                policy.reviewed_source(self.candidate, review)

    def test_compact_profile_preserves_exact_literal_maps(self):
        source = policy.reviewed_source(self.candidate, self.review)
        decoded = self._decoded_maps(source)
        self.assertEqual(decoded["REPLACEMENTS"],
                         {p: row["current"] for p, row in self.candidate["replacements"].items()})
        self.assertEqual(decoded["DEPENDENCIES"], self.candidate["dependencies"])
        self.assertNotIn("func ", source)
        self.assertNotIn("preload(", source)

    def test_large_grouped_inventory_remains_exact_and_within_hard_caps(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["dependencies"] = {
            f"res://src/presentation/stadium/group{group:02}/component{item:03}.gd":
                hashlib.sha256(f"{group}:{item}".encode()).hexdigest()
            for group in range(28) for item in range(30)
        }
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertLessEqual(len(source.splitlines()), 1000)
        self.assertLessEqual(max(map(len, source.splitlines())), 100)
        self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], candidate["dependencies"])

    def test_repeated_hashes_and_cross_map_prefixes_preserve_every_key(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["dependencies"] = {
            f"res://src/presentation/stadium/shared_structure_{index:03}.gd": "b" * 64
            for index in range(40)
        }
        candidate["replacements"] = {
            "res://src/presentation/stadium/shared_structure_replaced.gd":
                {"original": "a" * 64, "current": "b" * 64}
        }
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        decoded = self._decoded_maps(source)
        self.assertEqual(decoded["DEPENDENCIES"], candidate["dependencies"])
        self.assertEqual(decoded["REPLACEMENTS"],
                         {p: row["current"] for p, row in candidate["replacements"].items()})

    def test_escaped_and_unicode_keys_roundtrip_without_normalization(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["dependencies"] = {
            'res://src/a"quote.gd': "c" * 64,
            'res://src/a\\slash.gd': "d" * 64,
            'res://src/caf\u00e9-\u96ea-\U0001f408.gd': "e" * 64,
            'res://src/line\nbreak.gd': "f" * 64,
        }
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], candidate["dependencies"])
        self.assertLessEqual(max(map(len, source.splitlines())), 100)

    def test_insertion_order_does_not_change_approved_bytes(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["dependencies"] = {
            f"res://src/presentation/stadium/structure_{index:03}.gd": "a" * 64
            for index in range(60)
        }
        reversed_candidate = copy.deepcopy(candidate)
        for key in ["dependencies", "replacements", "fixtures"]:
            reversed_candidate[key] = dict(reversed(list(candidate[key].items())))
        self.assertEqual(policy.digest(candidate), policy.digest(reversed_candidate))
        self.assertEqual(policy.reviewed_source(candidate, self._review_for(candidate)),
                         policy.reviewed_source(reversed_candidate, self._review_for(reversed_candidate)))

    def test_prefix_factoring_is_stable_across_python_hash_seeds(self):
        code = (
            "import json, npc_current_source_profile as p; "
            "keys = {f'res://src/presentation/stadium/group{g}/file{i:03}.gd' "
            "for g in range(8) for i in range(12)}; "
            "keys |= {f'res://unique{i:02}/different_long_filename.gd' for i in range(27)}; "
            "prefixes = p._profile_prefixes(keys); "
            "print(p._prefix_declarations(prefixes)); "
            "print(p._profile_map('TEST', {key: 'a'*64 for key in keys}, prefixes))"
        )
        outputs = []
        for seed in ["1", "77", "999"]:
            env = {**os.environ, "PYTHONHASHSEED": seed}
            outputs.append(subprocess.check_output(
                [sys.executable, "-c", code], cwd=Path(policy.__file__).parent, env=env))
        self.assertEqual(outputs[0], outputs[1])
        self.assertEqual(outputs[0], outputs[2])

    def test_prefix_compaction_preserves_literal_string_constants(self):
        prefixes = {"res://src/a/": "_A", "res://src/b/": "_B"}
        source = policy._prefix_declarations(prefixes)
        self.assertIn('const _A="res://src/a/"', source)
        self.assertIn('const _B="res://src/b/"', source)
        self.assertIn(';const ', source)
        self.assertLessEqual(max(map(len, source.splitlines())), 100)

    def test_nested_prefix_constants_are_ordered_bounded_and_exact(self):
        prefixes = {"res://" + "a" * index: policy._prefix_name(index) for index in range(7)}
        declarations = policy._prefix_declarations(prefixes)
        self.assertIn('const _B=_A+"a"', declarations)
        self.assertIn('const _G=_F+"a"', declarations)
        self.assertEqual(len(declarations.splitlines()), 2)
        self.assertEqual([line.count("const ") for line in declarations.splitlines()], [5, 2])
        self.assertLessEqual(max(map(len, declarations.splitlines())), 100)
        values = {prefix + "/file.gd": "a" * 64 for prefix in prefixes}
        source = declarations + policy._profile_map("REPLACEMENTS", {}, prefixes)
        source += policy._profile_map("DEPENDENCIES", values, prefixes)
        self.assertEqual(self._decoded_maps(source), {"REPLACEMENTS": {}, "DEPENDENCIES": values})
        self.assertEqual(declarations, policy._prefix_declarations(dict(reversed(list(prefixes.items())))))

    def test_nested_prefix_escaping_preserves_literal_strings(self):
        prefixes = {'res://caf\u00e9/': "_A", 'res://caf\u00e9/a\\slash/': "_B",
                    'res://caf\u00e9/a\\slash/b"quote/': "_C"}
        values = {prefix + "file.gd": "b" * 64 for prefix in prefixes}
        source = policy._prefix_declarations(prefixes)
        source += policy._profile_map("REPLACEMENTS", {}, prefixes)
        source += policy._profile_map("DEPENDENCIES", values, prefixes)
        self.assertIn('const _B=_A+', source)
        self.assertIn('const _C=_B+', source)
        self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], values)
        self.assertLessEqual(max(map(len, source.splitlines())), 100)

    def test_short_prefixes_are_not_factored_into_longer_expressions(self):
        source = policy._prefix_declarations({"a": "_A", "ab": "_B"})
        self.assertIn('const _B="ab"', source)
        self.assertNotIn('_A+', source)

    def test_first_fit_never_places_a_child_before_its_parent(self):
        prefixes = {"a" * 70: "_A", "b" * 71: "_B", "b" * 71 + "x": "_C"}
        declarations = policy._prefix_declarations(prefixes)
        self.assertLess(declarations.index("const _B="), declarations.index("const _C="))
        values = {prefix: "a" * 64 for prefix in prefixes}
        source = declarations + policy._profile_map("REPLACEMENTS", {}, prefixes)
        source += policy._profile_map("DEPENDENCIES", values, prefixes)
        self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], values)

    def test_final_brace_reuses_comma_column_for_empty_single_and_split_maps(self):
        empty = policy._profile_map("REPLACEMENTS", {}, {})
        self.assertEqual(empty, "const REPLACEMENTS: Dictionary = {}\n")
        for key in ["short", 'res://src/a}brace-and-"quote-' + "x" * 30 + ".gd"]:
            values = {key: "a" * 64}
            source = empty + policy._profile_map("DEPENDENCIES", values, {})
            self.assertTrue(source.endswith('}\n'))
            self.assertEqual(self._decoded_maps(source), {"REPLACEMENTS": {}, "DEPENDENCIES": values})
            self.assertLessEqual(max(map(len, source.splitlines())), 100)

    def test_singleton_prefixes_remove_split_rows_with_bounded_density(self):
        candidate = copy.deepcopy(self.candidate)
        words = ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot"]
        candidate["replacements"] = {}
        candidate["dependencies"] = {
            f"res://{word}/different_long_filename_{index}.gd": "a" * 64
            for index, word in enumerate(words)
        }
        prefixes = policy._profile_prefixes(set(candidate["dependencies"]))
        self.assertEqual(len(prefixes), 6)
        self.assertTrue(all(sum(key.startswith(prefix) for key in candidate["dependencies"]) == 1
                            for prefix in prefixes))
        declarations = policy._prefix_declarations(prefixes).splitlines()
        self.assertLessEqual(len(declarations), 3)
        self.assertTrue(all(line.count("const ") <= 5 for line in declarations))
        compact = policy._profile_map("DEPENDENCIES", candidate["dependencies"], prefixes)
        unfactored = policy._profile_map("DEPENDENCIES", candidate["dependencies"], {})
        self.assertLess(len(compact.splitlines()), len(unfactored.splitlines()))
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], candidate["dependencies"])
        self.assertLessEqual(max(map(len, source.splitlines())), 100)

    def test_singleton_factoring_skips_literal_rows_that_already_fit(self):
        inline = "res://" + "a" * 23
        split = "res://bravo/different_long_filename.gd"
        values = {inline: "a" * 64, split: "b" * 64}
        prefixes = policy._profile_prefixes(set(values))
        self.assertEqual(len(policy._profile_map("TEST", {inline: values[inline]}, {}).splitlines()), 2)
        self.assertEqual(len(prefixes), 1)
        self.assertTrue(split.startswith(next(iter(prefixes))))
        self.assertEqual(len(policy._profile_map("TEST", values, prefixes).splitlines()), 3)

    def test_singleton_prefixes_keep_odd_tail_and_long_names_within_limits(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["replacements"] = {}
        candidate["dependencies"] = {
            f"res://unique{index:02}/different_long_filename.gd": "a" * 64
            for index in range(27)
        }
        prefixes = policy._profile_prefixes(set(candidate["dependencies"]))
        self.assertEqual(len(prefixes), 27)
        self.assertIn("_AA", prefixes.values())
        declaration_lines = policy._prefix_declarations(prefixes).splitlines()
        self.assertTrue(all(line.count("const ") <= 5 for line in declaration_lines))
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], candidate["dependencies"])
        self.assertLessEqual(max(map(len, source.splitlines())), 100)

    def test_short_prefix_names_are_unique_private_and_budgeted(self):
        names = [policy._prefix_name(index) for index in range(1296)]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(names[:3], ["_A", "_B", "_C"])
        self.assertEqual(names[25:28], ["_Z", "_AA", "_AB"])
        self.assertTrue(all(re.fullmatch(r"_[A-Z]+", name) for name in names))
        for name in [names[0], names[26], names[-1]]:
            row = "\t" + name + '+"' + "x" * policy._suffix_limit(name) + '":"' + "0" * 64 + '",'
            self.assertEqual(len(row), 98)

    def test_unrepresentable_line_and_file_limits_fail_closed(self):
        inventories = [
            {"res://src/" + "x" * 120 + ".gd": "a" * 64},
            {f"res://src/asset{index:04}.gd": "a" * 64 for index in range(2000)},
        ]
        for inventory in inventories:
            candidate = copy.deepcopy(self.candidate)
            candidate["dependencies"] = inventory
            with self.assertRaisesRegex(ValueError, "line limits"):
                policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertFalse((self.root / policy.PROFILE).exists())

    def test_token_packing_splits_literals_without_runtime_reconstruction(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["dependencies"] = {
            "res://different/" + "long_path_component_" * 2 + f"{index:03}.gd":
                hashlib.sha256(f"distinct-hash-{index}".encode()).hexdigest()
            for index in range(90)
        }
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertRegex(source, r'"[0-9a-f]{4,60}"\+\n"[0-9a-f]{4,60}"')
        self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], candidate["dependencies"])
        self.assertTrue(all(len(line) <= 100 for line in source.splitlines()))
        for forbidden in ["func ", "preload(", "String(", ".split(", ".join(", "static var"]:
            self.assertNotIn(forbidden, source)

    def test_packing_adversarial_literals_and_all_column_boundaries(self):
        tails = ['quote"and\\slash', "tab\tnew\nline\r", "caf\u00e9-\u96ea-\U0001f408",
                 "brace},colon:plus+semi;", "const DEPENDENCIES: Dictionary = {"]
        # Raw path Strings need not be valid files in this isolated language test.
        for offset in range(1, 101):
            values = {
                "res://" + "x" * offset + "/" + tail: hashlib.sha256(tail.encode()).hexdigest()
                for tail in tails
            }
            source = policy._profile_map("REPLACEMENTS", {}, {})
            source += policy._profile_map("DEPENDENCIES", values, {})
            self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], values)
            self.assertTrue(all(len(line) <= 100 for line in source.splitlines()))
            self.assertTrue(all(line for line in source.splitlines()))

    def test_split_fragments_have_at_least_four_codepoints(self):
        for size in range(8, 121):
            text = "q" * size
            for position in range(1, 100):
                source = policy._pack_map_tokens("{" + " " * position, [(text, True), ("}", False)])
                fragments = re.findall(r'"(q*)"', source)
                self.assertEqual("".join(fragments), text)
                self.assertTrue(all(len(fragment) >= 4 for fragment in fragments))
                self.assertLessEqual(max(map(len, source.splitlines())), 100)

    def test_packer_rejects_unsplittable_nonliteral_tokens(self):
        with self.assertRaisesRegex(ValueError, "line limits"):
            policy._pack_map_tokens("{", [("x" * 101, False)])

    def test_independent_decoder_rejects_nonliteral_or_corrupt_maps(self):
        opening = "const REPLACEMENTS: Dictionary = {}\nconst DEPENDENCIES: Dictionary = {"
        rows = ['"x":load("evil")}', '_MISSING+"x":"' + "a" * 64 + '"}',
                '"x":"' + "a" * 63 + '"}',
                '"x":"' + "a" * 64 + '","x":"' + "b" * 64 + '"}',
                '"x":"' + "a" * 64 + '"}extra']
        for row in rows:
            with self.subTest(row=row), self.assertRaises(AssertionError):
                self._decoded_maps(opening + row)

    def test_dense_970_unique_maps_fit_with_all_full_hashes(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["replacements"] = {}
        candidate["dependencies"] = {
            f"res://src/presentation/stadium/group{group:02}/component{item:03}.gd":
                hashlib.sha256(f"{group}:{item}".encode()).hexdigest()
            for group in range(97) for item in range(10)
        }
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertEqual(len(self._decoded_maps(source)["DEPENDENCIES"]), 970)
        self.assertEqual(self._decoded_maps(source)["DEPENDENCIES"], candidate["dependencies"])
        self.assertLessEqual(len(source.splitlines()), 1000)
        self.assertLessEqual(max(map(len, source.splitlines())), 100)

    def test_metadata_line_limit_cannot_be_bypassed(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["profile_id"] = "x" * 101
        with self.assertRaisesRegex(ValueError, "line limits"):
            policy.reviewed_source(candidate, self._review_for(candidate))

    def test_metadata_is_exact_and_provenance_is_retained_for_both_purposes(self):
        for purpose in ["isolated-test", "final"]:
            candidate = copy.deepcopy(self.candidate)
            candidate["purpose"] = purpose
            candidate["profile_id"] = 'odd;\"\\café'
            review = self._review_for(candidate)
            review["purpose"] = purpose
            source = policy.reviewed_source(candidate, review)
            self.assertEqual(source.splitlines()[0],
                             "extends RefCounted # Candidate: " + policy.digest(candidate))
            self.assertIn("## Explicitly reviewed whole-source profile. Do not refresh automatically.",
                          source.splitlines())
            profile_line = source.splitlines()[2]
            self.assertTrue(profile_line.endswith(" # Purpose: " + purpose))
            decoded = {}
            for name in ["PROFILE_ID", "REVIEW_STATUS", "BASELINE_SHA256"]:
                marker = "const " + name + ": String = "
                self.assertEqual(source.count(marker), 1)
                decoded[name] = json.JSONDecoder().raw_decode(source.split(marker, 1)[1])[0]
            self.assertEqual(decoded, {"PROFILE_ID": candidate["profile_id"],
                                      "REVIEW_STATUS": "reviewed",
                                      "BASELINE_SHA256": candidate["baseline_sha256"]})
            self.assertEqual(self._decoded_maps(source), {
                "REPLACEMENTS": {k: v["current"] for k, v in candidate["replacements"].items()},
                "DEPENDENCIES": candidate["dependencies"],
            })
            self.assertFalse((self.root / policy.PROFILE).exists())

    def test_metadata_packing_preserves_prefix_expressions_and_maps(self):
        prefixes = {"res://" + "a" * index: policy._prefix_name(index) for index in range(7)}
        metadata = ('const REVIEW_STATUS: String = "reviewed"',
                    'const BASELINE_SHA256: String = "' + "b" * 64 + '"')
        original = policy._prefix_declarations(prefixes)
        packed = policy._prefix_declarations(prefixes, metadata)
        stripped = packed
        for row in metadata:
            stripped = stripped.replace(";" + row, "").replace(row + "\n", "")
        self.assertEqual(stripped, original)
        self.assertTrue(all(line.count("const ") <= 5 for line in packed.splitlines()))
        self.assertTrue(all(len(line) <= 100 for line in packed.splitlines()))
        values = {key + "/file.gd": "c" * 64 for key in prefixes}
        maps = policy._profile_map("REPLACEMENTS", {}, prefixes)
        maps += policy._profile_map("DEPENDENCIES", values, prefixes)
        self.assertEqual(self._decoded_maps(packed + maps), self._decoded_maps(original + maps))
        self.assertEqual(packed, policy._prefix_declarations(
            dict(reversed(list(prefixes.items()))), metadata))
        self.assertEqual(policy._prefix_declarations({}, metadata), "\n".join(metadata) + "\n")

    def test_metadata_packing_respects_exact_column_and_declaration_limits(self):
        row = 'const REVIEW_STATUS: String = "reviewed"'
        # One prefix declaration consumes 60 columns, then ; and metadata fill 100.
        width = 100 - 1 - len(row)
        prefix_size = width - len('const _A=""')
        packed = policy._prefix_declarations({"x" * prefix_size: "_A"}, (row,))
        self.assertEqual(len(packed.splitlines()), 1)
        self.assertEqual(len(packed.splitlines()[0]), 100)
        overflow = policy._prefix_declarations({"x" * (prefix_size + 1): "_A"}, (row,))
        self.assertEqual(len(overflow.splitlines()), 2)
        prefixes = {chr(97 + i): policy._prefix_name(i) for i in range(5)}
        packed = policy._prefix_declarations(prefixes, ('const X=""',))
        self.assertEqual([line.count("const ") for line in packed.splitlines()], [5, 1])

    def test_full_render_is_deterministic_under_inventory_order(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["dependencies"].update({
            f"res://src/group{i:02}/long_component.gd": hashlib.sha256(str(i).encode()).hexdigest()
            for i in range(35)
        })
        original = policy.reviewed_source(candidate, self._review_for(candidate))
        for key in ["replacements", "dependencies", "fixtures"]:
            candidate[key] = dict(reversed(list(candidate[key].items())))
        self.assertEqual(original, policy.reviewed_source(candidate, self._review_for(candidate)))

    def test_final_line_cap_accepts_1000_and_rejects_1001(self):
        # Isolate the final guard; map literal correctness has separate exact-decoder tests.
        candidate = copy.deepcopy(self.candidate)
        candidate["replacements"] = {}
        candidate["dependencies"] = {}
        review = self._review_for(candidate)
        # Header + metadata has five lines when there are no prefixes.
        for total in [1000, 1001]:
            with mock.patch.object(policy, "_profile_map", side_effect=["{}\n" * (total - 5), ""]):
                if total == 1000:
                    self.assertEqual(len(policy.reviewed_source(candidate, review).splitlines()), total)
                else:
                    with self.assertRaisesRegex(ValueError, "line limits"):
                        policy.reviewed_source(candidate, review)
        self.assertFalse((self.root / policy.PROFILE).exists())

    def test_profile_purpose_comment_preserves_strict_column_boundary(self):
        candidate = copy.deepcopy(self.candidate)
        fixed = len('const PROFILE_ID: String = "" # Purpose: isolated-test')
        for width in [99, 100, 101]:
            candidate["profile_id"] = "x" * (width - fixed)
            review = self._review_for(candidate)
            if width <= 100:
                source = policy.reviewed_source(candidate, review)
                self.assertEqual(len(source.splitlines()[2]), width)
            else:
                with self.assertRaisesRegex(ValueError, "line limits"):
                    policy.reviewed_source(candidate, review)

    def test_legacy_verification_and_original_literal_rendering_remain_available(self):
        candidate = policy._legacy_proposal(self.root, "legacy-test", "isolated-test")
        policy.verify(self.root, candidate)
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertIn("const REPLACEMENTS: Dictionary = {\n  ", source)
        self.assertNotIn("const _A:", source)
        self.assertFalse((self.root / policy.PROFILE).exists())


    def test_cli_rejects_stale_or_legacy_installation_without_output(self):
        stale = copy.deepcopy(self.candidate)
        stale["renderer"]["version"] = 9
        legacy = policy._legacy_proposal(self.root, "legacy-test", "isolated-test")
        for label, candidate in [("stale", stale), ("legacy", legacy)]:
            with self.subTest(label=label):
                candidate_path = self.root / (label + "-candidate.json")
                review_path = self.root / (label + "-review.json")
                output_path = self.root / (label + "-forbidden.gd")
                candidate_path.write_text(json.dumps(candidate))
                review_path.write_text(json.dumps(self._review_for(candidate)))
                run = subprocess.run([
                    sys.executable, str(Path(policy.__file__).resolve()),
                    "--root", str(self.root), "install-reviewed", str(candidate_path),
                    str(review_path), "--output", str(output_path),
                ], capture_output=True, text=True, timeout=10)
                self.assertNotEqual(run.returncode, 0, run.stdout + run.stderr)
                self.assertFalse(output_path.exists())
        self.assertFalse((self.root / policy.PROFILE).exists())

    @unittest.skipUnless(os.environ.get("WIFFALTRO_PROFILE_TEST_GODOT"),
                         "Set WIFFALTRO_PROFILE_TEST_GODOT to explicitly enable native validation")
    def test_native_constant_dictionaries_equal_exact_candidate(self):
        candidate = copy.deepcopy(self.candidate)
        candidate["dependencies"] = {
            f"res://src/presentation/stadium/group{group:02}/component{item:03}.gd":
                hashlib.sha256(f"{group}:{item}".encode()).hexdigest()
            for group in range(28) for item in range(30)
        }
        candidate["dependencies"].update({
            'res://src/a"quote.gd': "c" * 64,
            'res://src/a\\slash.gd': "d" * 64,
            'res://src/caf\u00e9-\u96ea-\U0001f408.gd': "e" * 64,
            'res://src/line\nbreak.gd': "f" * 64,
        })
        candidate["dependencies"].update({
            f"res://{group}/long_component_{item:03}.gd": "d" * 64
            for group in ["alpha", "bravo"] for item in range(20)
        })
        candidate["dependencies"].update({
            f"res://unique{index:02}/different_long_filename.gd": "e" * 64
            for index in range(27)
        })
        candidate["dependencies"].update({
            "res://nested/" + "deep_" * depth + f"item{item:03}.gd": "f" * 64
            for depth in range(1, 7) for item in range(4)
        })
        candidate["dependencies"].update({
            "res://chain/" + "x" * depth + "a" * 25: "f" * 64
            for depth in range(1, 13)
        })
        source = policy.reviewed_source(candidate, self._review_for(candidate))
        self.assertIn(";const ", source)
        self.assertRegex(source, r"=_[A-Z]+\+")
        self.assertEqual(max(line.count("const ") for line in source.splitlines()), 5)
        native = self.root / "native-renderer-test"
        native.mkdir()
        (native / "project.godot").write_text("config_version=5\n")
        (native / "profile.gd").write_text(source)
        (native / "dump.gd").write_text(
            'extends SceneTree\n\n'
            'func _initialize() -> void:\n'
            '\tvar profile: GDScript = load("res://profile.gd")\n'
            '\tif profile == null or not profile.can_instantiate():\n'
            '\t\tquit(1)\n\t\treturn\n'
            '\tvar constants: Dictionary = profile.get_script_constant_map()\n'
            '\tfor key: String in constants:\n'
            '\t\tif key.begins_with("_") and typeof(constants[key]) != TYPE_STRING:\n'
            '\t\t\tquit(2)\n\t\t\treturn\n'
            '\tvar result: Dictionary = {}\n'
            '\tfor name: String in ["PROFILE_ID", "REVIEW_STATUS", "BASELINE_SHA256", '
            '"REPLACEMENTS", "DEPENDENCIES"]:\n'
            '\t\tresult[name] = constants[name]\n'
            '\tif not result.REPLACEMENTS is Dictionary or not result.DEPENDENCIES is Dictionary:\n'
            '\t\tquit(2)\n\t\treturn\n'
            '\tfor name: String in ["REPLACEMENTS", "DEPENDENCIES"]:\n'
            '\t\tfor key: Variant in result[name]:\n'
            '\t\t\tif typeof(key) != TYPE_STRING or typeof(result[name][key]) != TYPE_STRING:\n'
            '\t\t\t\tquit(3)\n\t\t\t\treturn\n'
            '\tFileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE).store_string('
            'JSON.stringify(result, "", true, true))\n'
            '\tprint("PROFILE_LITERAL_DICTIONARIES_EXPORTED")\n'
            '\tquit(0)\n')
        output = native / "native-values.json"
        env = {**os.environ, "HOME": str(native / "home"),
               "XDG_DATA_HOME": str(native / "data"),
               "XDG_CONFIG_HOME": str(native / "config"),
               "XDG_CACHE_HOME": str(native / "cache"), "TMPDIR": str(native / "tmp")}
        for directory in ["home", "data", "config", "cache", "tmp"]:
            (native / directory).mkdir()
        run = subprocess.run([
            str(Path(os.environ["WIFFALTRO_PROFILE_TEST_GODOT"]).resolve()),
            "--headless", "--path", str(native), "--script", "res://dump.gd", "--", str(output),
        ], env=env, capture_output=True, text=True, timeout=10)
        log = run.stdout + run.stderr
        self.assertEqual(run.returncode, 0, log)
        self.assertNotIn("ERROR:", log)
        self.assertIn("PROFILE_LITERAL_DICTIONARIES_EXPORTED", log)
        self.assertEqual(json.loads(output.read_text()), {
            "PROFILE_ID": candidate["profile_id"], "REVIEW_STATUS": "reviewed",
            "BASELINE_SHA256": candidate["baseline_sha256"],
            "REPLACEMENTS": {p: row["current"] for p, row in candidate["replacements"].items()},
            "DEPENDENCIES": candidate["dependencies"],
        })
        self.assertFalse((self.root / policy.PROFILE).exists())


if __name__ == "__main__":
    unittest.main()
