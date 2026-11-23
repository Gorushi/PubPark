import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from pubpark.config import data_dir, public_data_api_key
from pubpark.storage.cache import load_cache, save_cache


class StorageTests(unittest.TestCase):
    def test_missing_and_unicode_roundtrip(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "nested" / "cache.json"
            self.assertEqual(load_cache(path), {})
            data = {"001": {"name": "서울 주차장", "count": 0}}
            save_cache(path, data)
            self.assertEqual(load_cache(path), data)

    def test_failed_write_preserves_previous_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "cache.json"
            save_cache(path, {"old": 1})
            with self.assertRaises(TypeError):
                save_cache(path, {"invalid": object()})
            self.assertEqual(load_cache(path), {"old": 1})
            self.assertEqual(list(Path(directory).glob("*.tmp")), [])

    def test_invalid_cache_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "cache.json"
            for content in ("{", "[]"):
                path.write_text(content, encoding="utf-8")
                with self.assertRaises(ValueError):
                    load_cache(path)


class ConfigTests(unittest.TestCase):
    def test_missing_key(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, "PUBLIC_DATA_API_KEY"):
                public_data_api_key()

    def test_directory_override(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, {"PUBPARK_DATA_DIR": directory}):
                self.assertEqual(data_dir(), Path(directory).resolve())


if __name__ == "__main__":
    unittest.main()
