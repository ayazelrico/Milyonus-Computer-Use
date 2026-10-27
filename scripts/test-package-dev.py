#!/usr/bin/env python3
"""Headless packaging checks; no native apps, permissions or input are invoked."""
from contextlib import contextmanager
import importlib.util
import os
import select
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("package_dev", Path(__file__).with_name("package-dev.py"))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


@contextmanager
def pipeline_fixture():
    """Run the real orchestration against temporary files and simulated external tools."""
    previous_cwd = Path.cwd()
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        (root / "scripts").mkdir()
        (root / "Package.swift").write_text("synthetic package manifest")
        (root / "Sources").mkdir()
        (root / "Sources" / "main.swift").write_text("synthetic source")
        binary = root / "bin"; binary.mkdir()
        output = root / "build"; output.mkdir()
        for name in package.TARGETS:
            (binary / name).write_text("new-" + name)
            app = output / (name + ".app"); app.mkdir()
            (app / "old-marker").write_text("old-" + name)
        def external_output(command, **kwargs):
            if command[0] == "/bin/ps": return ""
            if command[:2] == ["swift", "build"]: return str(binary) + "\n"
            raise AssertionError(f"Unexpected external command: {command}")
        try:
            with patch.object(package, "__file__", str(root / "scripts" / "package-dev.py")), \
                 patch.object(package.subprocess, "check_output", side_effect=external_output):
                yield root, binary, output
        finally:
            os.chdir(previous_cwd)


class PackagingTests(unittest.TestCase):
    def test_oversized_generated_receipt_cannot_publish_apps(self):
        with pipeline_fixture() as (_, _, output):
            with patch.object(package.subprocess, "run"), \
                 patch.object(package, "package_receipt", return_value={"padding": "x" * (1024 * 1024)}):
                with self.assertRaisesRegex(RuntimeError, "receipt exceeds"):
                    package.main("debug")
            self.assert_original_bundles(output)
            self.assertFalse((output / "package-receipt.json").exists())

    def test_receipt_verification_detects_file_and_source_changes(self):
        for change in ["executable", "metadata", "source"]:
            with self.subTest(change=change), pipeline_fixture() as (root, _, output):
                with patch.object(package.subprocess, "run"): package.main("debug")
                self.assertEqual(package.verify_receipt(root)["status"], "matched")
                app = output / (package.TARGETS[0] + ".app") / "Contents"
                path = {"executable": app / "MacOS" / package.TARGETS[0],
                        "metadata": app / "Info.plist", "source": root / "Sources" / "main.swift"}[change]
                path.write_bytes(path.read_bytes() + b"modified")
                self.assertEqual(package.verify_receipt(root)["status"], "mismatch")

    def test_receipt_verification_refuses_duplicates_and_oversize(self):
        with pipeline_fixture() as (root, _, output):
            path = output / "package-receipt.json"
            for content in ['{"version":1,"version":1}', '[' * 2000, 'x' * (1024 * 1024 + 1)]:
                path.write_text(content)
                with self.assertRaises(RuntimeError): package.verify_receipt(root)

    def test_receipt_verification_does_not_follow_package_links(self):
        with pipeline_fixture() as (root, _, output):
            with patch.object(package.subprocess, "run"): package.main("debug")
            contents = output / (package.TARGETS[0] + ".app") / "Contents"
            saved = root / "external-contents"
            contents.rename(saved)
            contents.symlink_to(saved, target_is_directory=True)
            with self.assertRaises(OSError): package.verify_receipt(root)
            self.assertTrue(saved.exists())

    def test_receipt_cli_returns_nonzero_for_mismatch_without_rebuild(self):
        script = Path(package.__file__).resolve()
        with pipeline_fixture() as (root, _, output):
            with patch.object(package.subprocess, "run"): package.main("debug")
            copied_script = root / "scripts" / "package-dev.py"
            package.shutil.copy2(script, copied_script)
            result = subprocess.run([sys.executable, str(copied_script), "--verify-receipt"], capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0)
            (root / "Sources" / "main.swift").write_text("changed")
            result = subprocess.run([sys.executable, str(copied_script), "--verify-receipt"], capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(package.json.loads(result.stdout)["status"], "mismatch")
            self.assertFalse(package.json.loads(result.stdout)["sourceInputsMatch"])
            self.assertEqual(list(output.glob(".package-*")), [])

    def test_receipt_matches_published_bytes(self):
        with pipeline_fixture() as (root, _, output):
            with patch.object(package.subprocess, "run"):
                package.main("debug")
            receipt = package.json.loads((output / "package-receipt.json").read_text())
            self.assertEqual(receipt["configuration"], "debug")
            self.assertEqual(receipt["sourceInputs"], package.source_inputs(root))
            for name in package.TARGETS:
                actual = output / (name + ".app") / "Contents" / "MacOS" / name
                self.assertEqual(receipt["apps"][name]["executable"], package.file_digest(actual))

    def test_changed_source_prevents_publication_and_preserves_receipt(self):
        with pipeline_fixture() as (root, _, output):
            (output / "package-receipt.json").write_text("old receipt")
            def mutate_source(command, **kwargs):
                if command[:2] == ["swift", "build"]:
                    (root / "Sources" / "main.swift").write_text("changed source")
            with patch.object(package.subprocess, "run", side_effect=mutate_source):
                with self.assertRaisesRegex(RuntimeError, "sources changed"):
                    package.main("debug")
            self.assert_original_bundles(output)
            self.assertEqual((output / "package-receipt.json").read_text(), "old receipt")

    def test_receipt_digest_refuses_symlinks_and_special_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); target = root / "target"; target.write_text("data")
            link = root / "link"; link.symlink_to(target)
            fifo = root / "fifo"; os.mkfifo(fifo, 0o600)
            for path in [link, fifo, root]:
                with self.assertRaises((OSError, RuntimeError)): package.file_digest(path)

    def test_invalid_receipt_destination_stops_before_build(self):
        with pipeline_fixture() as (_, _, output):
            (output / "package-receipt.json").mkdir()
            with patch.object(package.subprocess, "run") as run:
                with self.assertRaises(RuntimeError): package.main("debug")
                run.assert_not_called()
            self.assert_original_bundles(output)

    def test_recovery_inventory_does_not_create_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "missing"
            result = package.recovery_status(output)
            self.assertEqual(result["entries"], [])
            self.assertFalse(output.exists())

    def test_recovery_inventory_distinguishes_staged_previous_and_missing(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary); stage = output / ".package-test"; stage.mkdir()
            (stage / (package.TARGETS[0] + ".app")).mkdir()
            (stage / (package.TARGETS[1] + ".previous")).mkdir()
            (stage / "unrelated-secret").write_text("never-read")
            result = package.recovery_status(output)
            self.assertFalse(result["signatureVerified"])
            bundles = result["entries"][0]["bundles"]
            self.assertEqual(bundles[package.TARGETS[0]], {"staged": "directory", "previous": "missing"})
            self.assertEqual(bundles[package.TARGETS[1]], {"staged": "missing", "previous": "directory"})
            self.assertNotIn("never-read", str(result))
            self.assertEqual(sorted(p.name for p in output.iterdir()), [".package-test"])

    def test_recovery_inventory_refuses_links(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); output = root / "build"; output.mkdir()
            external = root / "external"; external.mkdir()
            (external / "secret").write_text("not-in-report")
            (output / ".package-link").symlink_to(external, target_is_directory=True)
            stage = output / ".package-real"; stage.mkdir()
            (stage / (package.TARGETS[0] + ".previous")).symlink_to(external, target_is_directory=True)
            result = package.recovery_status(output)
            self.assertEqual(result["entries"][0]["kind"], "symlink-refused")
            self.assertEqual(result["entries"][1]["bundles"][package.TARGETS[0]]["previous"], "symlink-refused")
            alias = root / "alias"; alias.symlink_to(output, target_is_directory=True)
            with self.assertRaises(RuntimeError): package.recovery_status(alias)

    def test_recovery_directory_swap_cannot_redirect_inventory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); output = root / "build"; output.mkdir()
            stage = output / ".package-race"; stage.mkdir()
            outside = root / "outside"; outside.mkdir()
            (outside / (package.TARGETS[0] + ".previous")).mkdir()
            original_open = os.open
            swapped = False
            def racing_open(path, flags, *args, **kwargs):
                nonlocal swapped
                if path == stage.name and "dir_fd" in kwargs and not swapped:
                    swapped = True
                    stage.rename(output / "retained-original")
                    stage.symlink_to(outside, target_is_directory=True)
                return original_open(path, flags, *args, **kwargs)
            with patch.object(package.os, "open", side_effect=racing_open):
                result = package.recovery_status(output)
            entry = next(item for item in result["entries"] if item["name"] == ".package-race")
            self.assertEqual(entry["kind"], "changed-or-unreadable")
            self.assertNotIn("bundles", entry)

    def test_recovery_inventory_is_bounded(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            for index in range(105): (output / f".package-{index:03d}").mkdir()
            result = package.recovery_status(output)
            self.assertEqual(len(result["entries"]), 100)
            self.assertTrue(result["truncated"])

    def assert_original_bundles(self, output):
        for name in package.TARGETS:
            self.assertEqual((output / (name + ".app") / "old-marker").read_text(), "old-" + name)

    def test_pipeline_signing_failures_preserve_both_apps(self):
        # Fail each of the two signing and two verification invocations independently.
        for fail_at in range(1, 5):
            with self.subTest(fail_at=fail_at), pipeline_fixture() as (_, _, output):
                signing_calls = []
                def run(command, **kwargs):
                    if command[0] == "/usr/bin/codesign":
                        signing_calls.append(command)
                        if len(signing_calls) == fail_at:
                            raise subprocess.CalledProcessError(1, command)
                with patch.object(package.subprocess, "run", side_effect=run):
                    with self.assertRaises(subprocess.CalledProcessError): package.main("debug")
                self.assert_original_bundles(output)
                self.assertEqual(len(signing_calls), fail_at)
                self.assertEqual(len(list(output.glob(".package-*"))), 1)

    def test_pipeline_missing_binary_preserves_both_apps(self):
        for name in package.TARGETS:
            with self.subTest(name=name), pipeline_fixture() as (_, binary, output):
                (binary / name).unlink()
                with patch.object(package.subprocess, "run"):
                    with self.assertRaises(FileNotFoundError): package.main("debug")
                self.assert_original_bundles(output)

    def test_pipeline_late_running_app_blocks_publication(self):
        with pipeline_fixture() as (_, _, output):
            with patch.object(package.subprocess, "run"), \
                 patch.object(package, "require_stopped", side_effect=[None, RuntimeError("App started during build")]):
                with self.assertRaisesRegex(RuntimeError, "App started"):
                    package.main("debug")
            self.assert_original_bundles(output)

    def test_pipeline_success_publishes_complete_metadata_and_cleans_stage(self):
        with pipeline_fixture() as (_, _, output):
            with patch.object(package.subprocess, "run") as external:
                package.main("debug")
            self.assertEqual(external.call_count, 5)
            for name in package.TARGETS:
                app = output / (name + ".app")
                self.assertEqual((app / "Contents" / "MacOS" / name).read_text(), "new-" + name)
                metadata = package.plistlib.loads((app / "Contents" / "Info.plist").read_bytes())
                self.assertEqual(metadata["CFBundleExecutable"], name)
                self.assertFalse((app / "old-marker").exists())
            self.assertEqual(list(output.glob(".package-*")), [])
            with package.packaging_lock(output): pass

    def test_pipeline_invalid_second_destination_stops_before_build(self):
        with pipeline_fixture() as (_, _, output):
            second = output / (package.TARGETS[1] + ".app")
            package.shutil.rmtree(second)
            second.write_text("not-an-app")
            with patch.object(package.subprocess, "run") as external:
                with self.assertRaises(RuntimeError): package.main("debug")
                external.assert_not_called()
            self.assertEqual(second.read_text(), "not-an-app")
            self.assertEqual((output / (package.TARGETS[0] + ".app") / "old-marker").read_text(), "old-" + package.TARGETS[0])

    def test_process_names_match_without_reading_arguments(self):
        self.assertEqual(package.running_targets("/tmp/ComputerUseFixture\n/Applications/X/MilyonusComputerUse\n/bin/sleep\n"),
                         ["ComputerUseFixture", "MilyonusComputerUse"])
        self.assertEqual(package.running_targets("/tmp/ComputerUseFixture-copy\n/bin/sleep\n"), [])

    def test_running_app_refuses_publication(self):
        with patch.object(package.subprocess, "check_output", return_value="/tmp/ComputerUseFixture\n"):
            with self.assertRaisesRegex(RuntimeError, "Close these development apps"):
                package.require_stopped()

    def test_process_inventory_failure_is_not_assumed_safe(self):
        with patch.object(package.subprocess, "check_output", side_effect=OSError("unavailable")):
            with self.assertRaises(OSError):
                package.require_stopped()

    def test_publish_complete_staged_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            staged, destination, backup = [root / name for name in ("stage", "app", "backup")]
            staged.mkdir(); destination.mkdir()
            (staged / "binary").write_text("new")
            (destination / "binary").write_text("old")
            package.publish(staged, destination, backup)
            self.assertEqual((destination / "binary").read_text(), "new")
            self.assertEqual((backup / "binary").read_text(), "old")

    def test_failed_staging_retains_recovery_material(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(RuntimeError):
                with package.staging_directory(Path(temporary)) as stage:
                    (stage / "previous-app").write_text("recoverable")
                    raise RuntimeError("publication interrupted")
            self.assertEqual((stage / "previous-app").read_text(), "recoverable")

    def test_lock_refuses_second_process_and_releases(self):
        child_code = """
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location('packager', sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with module.packaging_lock(Path(sys.argv[2])):
    print('locked', flush=True)
    sys.stdin.readline()
"""
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            child = subprocess.Popen([sys.executable, "-u", "-c", child_code, str(Path(package.__file__).resolve()), temporary],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                self.assertTrue(select.select([child.stdout], [], [], 5)[0], "Child did not acquire lock")
                self.assertEqual(child.stdout.readline().strip(), "locked")
                with self.assertRaisesRegex(RuntimeError, "Another development packaging run"):
                    with package.packaging_lock(output):
                        self.fail("Concurrent lock acquired")
                child.communicate("release\n", timeout=5)
                self.assertEqual(child.returncode, 0)
                with package.packaging_lock(output):
                    self.assertEqual((output / ".packaging.lock").stat().st_mode & 0o777, 0o600)
            finally:
                if child.poll() is None:
                    child.kill()
                    child.communicate(timeout=5)
                for stream in [child.stdin, child.stdout, child.stderr]:
                    if stream and not stream.closed:
                        stream.close()

    def test_unsafe_lock_files_refused(self):
        for kind in ["symlink", "hardlink", "public", "fifo"]:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                output = Path(temporary); lock = output / ".packaging.lock"
                other = output / "other"
                other.write_text("untouched"); other.chmod(0o600)
                if kind == "symlink": lock.symlink_to(other)
                elif kind == "hardlink": os.link(other, lock)
                elif kind == "fifo": os.mkfifo(lock, 0o600)
                else: lock.write_text("lock"); lock.chmod(0o644)
                with self.assertRaises((OSError, RuntimeError)):
                    with package.packaging_lock(output):
                        self.fail("Unsafe lock accepted")
                self.assertEqual(other.read_text(), "untouched")

    def test_invalid_destinations_refused(self):
        for kind in ["file", "symlink"]:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                output = Path(temporary)
                first = output / (package.TARGETS[0] + ".app"); first.mkdir()
                (first / "binary").write_text("original")
                second = output / (package.TARGETS[1] + ".app")
                if kind == "file": second.write_text("user-file")
                else: second.symlink_to(first, target_is_directory=True)
                with self.assertRaises(RuntimeError): package.validate_destinations(output)
                self.assertEqual((first / "binary").read_text(), "original")

    def test_rollback_failure_keeps_previous_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            destination = output / "app"; destination.mkdir()
            (destination / "binary").write_text("original")
            original_rename = Path.rename
            with self.assertRaises(OSError):
                with package.staging_directory(output) as stage:
                    staged, backup = stage / "new", stage / "previous"
                    staged.mkdir()
                    def fail_publication_and_restore(path, target):
                        if path == staged or path == backup:
                            raise OSError("injected rename failure")
                        return original_rename(path, target)
                    with patch.object(Path, "rename", fail_publication_and_restore):
                        package.publish(staged, destination, backup)
            self.assertEqual((backup / "binary").read_text(), "original")
            self.assertFalse(destination.exists())

    def test_publish_failure_restores_previous_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination, backup = root / "app", root / "backup"
            destination.mkdir(); (destination / "binary").write_text("old")
            with self.assertRaises(FileNotFoundError):
                package.publish(root / "missing-stage", destination, backup)
            self.assertEqual((destination / "binary").read_text(), "old")
            self.assertFalse(backup.exists())


if __name__ == "__main__":
    unittest.main()
