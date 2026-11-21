"""Assembly safety tests using only tiny synthetic source repositories."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import assemble_successor as assembly


class AssemblyTests(unittest.TestCase):
    def test_new_destination_manifest_and_explicit_tests(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root / 'repo'
            repo.mkdir()
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            (repo / 'src').mkdir()
            (repo / 'src/old.gd').write_text('extends Node\n')
            config = 'run/main_scene="res://src/presentation/season/season_app.tscn"\n'
            (repo / 'project.godot').write_text(config)
            subprocess.run(['git', 'add', '.'], cwd=repo, check=True)
            (repo / 'src/private-save.json').write_text('not tracked')
            folder = repo / 'drafts/test'
            folder.mkdir(parents=True)
            rows = []
            for name in ['src/new.gd', 'tests/check.gd']:
                data = b'extends Node\n'
                source = folder / Path(name).name
                source.write_bytes(data)
                rows.append({'backup_path': str(source.relative_to(repo)),
                             'restore_path': name, 'bytes': len(data),
                             'sha256': hashlib.sha256(data).hexdigest()})
            manifest = folder / 'DRAFT_MANIFEST.json'
            manifest.write_text(json.dumps({'files': rows}))
            with patch.object(assembly, 'FAMILIES', ('test',)):
                target = root / 'build'
                result = assembly.assemble(repo, target)
                self.assertNotIn('src/private-save.json', result['files'])
                self.assertNotIn('tests/check.gd', result['files'])
                self.assertEqual((repo/'project.godot').read_text(), config)
                self.assertIn(assembly.LAUNCHER, (target/'project.godot').read_text())
                with self.assertRaises(ValueError):
                    assembly.assemble(repo, target)
                tested = assembly.assemble(repo, root/'tested', ['tests/check.gd'])
                self.assertIn('tests/check.gd', tested['files'])
                with patch.object(assembly, 'LIVE_FAMILY', 'test'):
                    live = assembly.assemble(repo, root/'live', live_owner=True)
                    self.assertEqual(live['launcher'], assembly.LIVE_LAUNCHER)
                    self.assertIn(assembly.LIVE_LAUNCHER, (root/'live/project.godot').read_text())
                    self.assertEqual((repo/'project.godot').read_text(), config)
                with patch.object(assembly, 'LIVE_FAMILY', 'test'), patch.object(assembly, 'PLAY_FAMILY', 'test'), patch.object(assembly, 'SELECTOR_FAMILY', 'test'), patch.object(assembly, 'PAIRED_HISTORY_FAMILIES', ()):
                    played = assembly.assemble(repo, root/'played', live_play=True)
                    self.assertEqual(played['launcher'], assembly.PLAY_LAUNCHER)
                    self.assertEqual((repo/'project.godot').read_text(), config)
                with patch.object(assembly, 'LIVE_FAMILY', 'test'), patch.object(assembly, 'PLAY_FAMILY', 'test'), patch.object(assembly, 'DYNASTY_FAMILY', 'test'), patch.object(assembly, 'SELECTOR_FAMILY', 'test'), patch.object(assembly, 'PAIRED_HISTORY_FAMILIES', ()):
                    dynasty = assembly.assemble(repo, root/'dynasty', dynasty_owner=True)
                    self.assertEqual(dynasty['launcher'], assembly.DYNASTY_LAUNCHER)
                    self.assertIn(assembly.DYNASTY_LAUNCHER, (root/'dynasty/project.godot').read_text())
                    self.assertNotIn('tests/check.gd', dynasty['files'])
                    self.assertEqual((repo/'project.godot').read_text(), config)
                (folder/'new.gd').write_text('corrupted')
                with self.assertRaises(ValueError):
                    assembly.assemble(repo, root/'bad')
                self.assertFalse((root/'bad').exists())

    def test_dynasty_includes_both_materialized_dependencies(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root/'repo'
            repo.mkdir()
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            config = 'run/main_scene="res://src/presentation/season/season_app.tscn"\n'
            (repo/'project.godot').write_text(config)
            subprocess.run(['git', 'add', 'project.godot'], cwd=repo, check=True)
            names = [assembly.LIVE_FAMILY, assembly.PLAY_FAMILY, assembly.DYNASTY_FAMILY, assembly.SELECTOR_FAMILY,
                     *assembly.PAIRED_HISTORY_FAMILIES]
            for index, family in enumerate(names):
                folder = repo/'drafts'/family
                folder.mkdir(parents=True)
                data = ('# dependency %d\nextends Node\n' % index).encode()
                source = folder/'source.gd.txt'
                source.write_bytes(data)
                row = {'backup_path': str(source.relative_to(repo)),
                       'restore_path': 'src/dependency%d.gd' % index,
                       'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
                (folder/'DRAFT_MANIFEST.json').write_text(json.dumps({'files': [row]}))
            with patch.object(assembly, 'FAMILIES', ()):
                result = assembly.assemble(repo, root/'dynasty', dynasty_owner=True)
                self.assertTrue(all('src/dependency%d.gd' % i in result['files'] for i in range(len(names))))
                ordinary = assembly.assemble(repo, root/'ordinary', live_play=True)
                self.assertNotIn('src/dependency2.gd', ordinary['files'])
                self.assertTrue(all('src/dependency%d.gd' % i in ordinary['files'] for i in range(3, len(names))))
                legacy_live = assembly.assemble(repo, root/'legacy-live', live_owner=True)
                self.assertEqual(set(legacy_live['files']), {'src/dependency0.gd', 'project.godot'})
                self.assertEqual(ordinary['launcher'], assembly.PLAY_LAUNCHER)
                self.assertEqual((repo/'project.godot').read_text(), config)

    def test_authored_project_requires_private_explicit_start_and_exact_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root/'source'
            repo.mkdir()
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            raw = f'run/main_scene="{assembly.ORIGINAL_LAUNCHER}"\n'.encode()
            config = repo/'project.godot'
            config.write_bytes(raw)
            startup = repo/assembly.DYNASTY_LAUNCHER.removeprefix('res://')
            startup.parent.mkdir(parents=True)
            startup.write_text('[gd_scene format=3]\n')
            subprocess.run(['git', 'add', 'project.godot', 'src'], cwd=repo, check=True)
            with patch.object(assembly, 'FAMILIES', ()), patch.object(assembly, 'LIVE_FAMILY', 'fixture'), \
                    patch.object(assembly, 'PLAY_FAMILY', 'fixture'), patch.object(assembly, 'SELECTOR_FAMILY', 'fixture'), \
                    patch.object(assembly, 'DYNASTY_FAMILY', 'fixture'), patch.object(assembly, 'PAIRED_HISTORY_FAMILIES', ()), \
                    patch.object(assembly, 'AUTHORED_PROJECT_SHA256', hashlib.sha256(raw).hexdigest()):
                folder = repo/'drafts'/'fixture'
                folder.mkdir(parents=True)
                (folder/'DRAFT_MANIFEST.json').write_text('{"files":[]}')
                target = root/'exact'
                result = assembly.assemble(repo, target, dynasty_owner=True, preserve_authored_project=True)
                self.assertEqual((target/'project.godot').read_bytes(), raw)
                self.assertEqual(result['files']['project.godot'], hashlib.sha256(raw).hexdigest())
                self.assertEqual(result['startup']['default_scene'], assembly.ORIGINAL_LAUNCHER)
                self.assertEqual(result['startup']['explicit_scene'], assembly.DYNASTY_LAUNCHER)
                self.assertEqual(result['startup']['required_environment'], {'WIFFALTRO_DYNASTY_ENGINEERING': '1'})
                self.assertEqual(json.loads((target/'ASSEMBLY.json').read_bytes()), result)
                with self.assertRaises(ValueError):
                    assembly.assemble(repo, root/'no-flag', preserve_authored_project=True)
                config.write_bytes(raw + b'\n')
                with self.assertRaises(ValueError):
                    assembly.assemble(repo, root/'modified', dynasty_owner=True, preserve_authored_project=True)
                self.assertFalse((root/'modified').exists())

    def test_unsafe_paths(self):
        for path in ['../save', '/tmp/save', 'src/../../save']:
            with self.assertRaises(ValueError):
                assembly.safe(path)


if __name__ == '__main__':
    unittest.main()
