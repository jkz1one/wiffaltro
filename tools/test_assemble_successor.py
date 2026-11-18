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
                with patch.object(assembly, 'LIVE_FAMILY', 'test'), patch.object(assembly, 'PLAY_FAMILY', 'test'):
                    played = assembly.assemble(repo, root/'played', live_play=True)
                    self.assertEqual(played['launcher'], assembly.PLAY_LAUNCHER)
                    self.assertEqual((repo/'project.godot').read_text(), config)
                (folder/'new.gd').write_text('corrupted')
                with self.assertRaises(ValueError):
                    assembly.assemble(repo, root/'bad')
                self.assertFalse((root/'bad').exists())

    def test_unsafe_paths(self):
        for path in ['../save', '/tmp/save', 'src/../../save']:
            with self.assertRaises(ValueError):
                assembly.safe(path)


if __name__ == '__main__':
    unittest.main()
