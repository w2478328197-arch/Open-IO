import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('openio', Path(__file__).resolve().parents[1] / 'openio.py')
openio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(openio)


class OpenIOTests(unittest.TestCase):
    def test_watch_profile_must_match_phone_features(self):
        openio.validate_watch_profile({'OpenIOFeatures': 'cue'}, {'todo', 'cue'})
        openio.validate_watch_profile({'OpenIOFeatures': 'run', 'NSHealthShareUsageDescription': 'Workout'}, {'run'})
        for info, selected in [({'OpenIOFeatures': 'cue'}, {'run'}), ({'OpenIOFeatures': 'run'}, {'run'}), ({}, {'cue'}), ({'OpenIOFeatures': 'cue,run'}, {'cue'})]:
            with self.assertRaises(ValueError):
                openio.validate_watch_profile(info, selected)

    def test_invalid_features_stop_before_build(self):
        for value in ['', 'todo,todo', 'cue,', 'unknown', '../run']:
            with self.assertRaises(ValueError):
                openio.features(value)
        self.assertEqual(openio.features('run,todo'), ['todo', 'run'])

    def test_prepare_preserves_existing_workspace(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'SOURCE_MANIFEST.json').write_text(json.dumps({'files': []}))
            output = root / 'existing'
            output.mkdir()
            sentinel = output / 'keep.txt'
            sentinel.write_text('existing user work')
            args = type('Args', (), {'features': 'todo', 'out': output, 'upstream': None})()
            with patch.object(openio, 'ROOT', root), patch.object(openio, 'run') as run:
                with self.assertRaises(ValueError):
                    openio.prepare(args)
                run.assert_not_called()
            self.assertEqual(sentinel.read_text(), 'existing user work')

    def test_tampered_overlay_never_fetches_or_writes_output(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'overlay').mkdir()
            (root / 'overlay/source.m').write_text('changed')
            (root / 'SOURCE_MANIFEST.json').write_text(json.dumps({'files': [{'path': 'source.m', 'sha256': '0' * 64}]}))
            output = root / 'new'
            args = type('Args', (), {'features': 'cue', 'out': output, 'upstream': None})()
            with patch.object(openio, 'ROOT', root), patch.object(openio, 'run') as run:
                with self.assertRaises(ValueError):
                    openio.prepare(args)
                run.assert_not_called()
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
