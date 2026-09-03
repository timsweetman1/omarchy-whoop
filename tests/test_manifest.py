import json
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]


class ManifestTests(unittest.TestCase):
    def test_manifest_entry_points_exist(self):
        manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["id"], "io.github.timsweetman1.whoop")
        self.assertEqual(manifest["version"], "0.1.2")
        for relative_path in manifest["entryPoints"].values():
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)

    def test_scripts_are_executable(self):
        for relative_path in ("setup", "uninstall", "bin/whoop-bridge", "bin/whoop-widget"):
            path = ROOT / relative_path
            self.assertTrue(path.is_file(), relative_path)
            self.assertTrue(path.stat().st_mode & 0o111, relative_path)


if __name__ == "__main__":
    unittest.main()
