#!/usr/bin/env python3
"""Package development apps without replacing a running app or publishing unsigned staging."""
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import fcntl
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import sys
import tempfile

TARGETS = ("MilyonusComputerUse", "ComputerUseFixture")


def running_targets(process_names):
    return sorted({Path(line.strip()).name for line in process_names.splitlines()
                   if Path(line.strip()).name in TARGETS})


def require_stopped():
    names = subprocess.check_output(["/bin/ps", "-axo", "comm="], text=True)
    active = running_targets(names)
    if active:
        raise RuntimeError("Close these development apps before packaging: " + ", ".join(active))


def publish(staged, destination, backup):
    """Rollback a failed publication. The directory rename pair is not an atomic swap."""
    had_previous = destination.exists()
    if had_previous:
        destination.rename(backup)
    try:
        staged.rename(destination)
    except BaseException:
        if had_previous:
            backup.rename(destination)
        raise


@contextmanager
def staging_directory(output):
    stage = Path(tempfile.mkdtemp(prefix=".package-", dir=output))
    try:
        yield stage
    except BaseException:
        # Keep old bundles even if rollback itself failed. Never delete recovery
        # material merely because a packaging operation did not finish.
        print(f"Packaging recovery material preserved at {stage}", file=sys.stderr)
        raise
    else:
        shutil.rmtree(stage)


@contextmanager
def packaging_lock(output):
    descriptor = os.open(output / ".packaging.lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
    try:
        info = os.fstat(descriptor)
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
                or info.st_nlink != 1 or stat.S_IMODE(info.st_mode) & 0o077):
            raise RuntimeError("Unsafe packaging lock")
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Another development packaging run is active") from None
        yield
    finally:
        os.close(descriptor)


def validate_destinations(output):
    receipt = output / "package-receipt.json"
    if receipt.is_symlink() or (receipt.exists() and not receipt.is_file()):
        raise RuntimeError("Refusing non-file or symbolic-link receipt destination")
    for name in TARGETS:
        destination = output / (name + ".app")
        if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
            raise RuntimeError("Refusing non-directory or symbolic-link app destination")


def recovery_status(output):
    """Bounded metadata inventory only; no content reads, symlink traversal or writes."""
    result = {"snapshotOnly": True, "signatureVerified": False, "entries": [], "truncated": False}
    if output.is_symlink():
        raise RuntimeError("Refusing symbolic-link build directory")
    if not output.exists():
        return result
    if not output.is_dir():
        raise RuntimeError("Build path is not a directory")

    def kind(name, directory):
        try:
            mode = os.stat(name, dir_fd=directory, follow_symlinks=False).st_mode
        except FileNotFoundError:
            return "missing"
        except OSError:
            return "unreadable"
        if stat.S_ISLNK(mode): return "symlink-refused"
        if stat.S_ISDIR(mode): return "directory"
        if stat.S_ISREG(mode): return "file"
        return "special-file-refused"

    # Descriptor-relative lookups prevent a directory replaced with a symlink
    # between inspection and enumeration from redirecting child lookups.
    output_fd = os.open(output, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        scanned = 0
        with os.scandir(output_fd) as candidates:
            for candidate in candidates:
                scanned += 1
                if scanned > 1000 or len(result["entries"]) >= 100:
                    result["truncated"] = True
                    break
                if not candidate.name.startswith(".package-"):
                    continue
                entry = {"name": candidate.name, "kind": kind(candidate.name, output_fd)}
                if entry["kind"] == "directory":
                    try:
                        stage_fd = os.open(candidate.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=output_fd)
                    except OSError:
                        entry["kind"] = "changed-or-unreadable"
                    else:
                        try:
                            entry["bundles"] = {name: {"staged": kind(name + ".app", stage_fd),
                                                       "previous": kind(name + ".previous", stage_fd)}
                                                for name in TARGETS}
                        finally:
                            os.close(stage_fd)
                result["entries"].append(entry)
    finally:
        os.close(output_fd)
    result["entries"].sort(key=lambda item: item["name"])
    return result


def file_digest(path):
    return digest_owned_descriptor(os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK))


def digest_owned_descriptor(descriptor):
    try:
        initial = os.fstat(descriptor)
        if not stat.S_ISREG(initial.st_mode) or initial.st_size > 128 * 1024 * 1024:
            raise RuntimeError("Receipt input is not a bounded regular file")
        digest = hashlib.sha256()
        size = 0
        while True:
            block = os.read(descriptor, 65536)
            if not block: break
            size += len(block)
            if size > 128 * 1024 * 1024:
                raise RuntimeError("Receipt input exceeded size limit")
            digest.update(block)
        final = os.fstat(descriptor)
        if size != initial.st_size or final.st_mtime_ns != initial.st_mtime_ns or final.st_size != initial.st_size:
            raise RuntimeError("Receipt input changed while hashing")
        return {"sha256": digest.hexdigest(), "bytes": size}
    finally:
        os.close(descriptor)


def source_inputs(root):
    paths = [root / "Package.swift"] + sorted((root / "Sources").rglob("*.swift"))
    return {str(path.relative_to(root)): file_digest(path) for path in paths}


def package_receipt(stage, configuration, inputs):
    return {"version": 1, "createdAt": datetime.now(timezone.utc).isoformat(),
            "configuration": configuration, "algorithm": "SHA-256",
            "scope": "Swift sources and package manifest; not a reproducible-build or signed attestation",
            "sourceInputs": inputs,
            "apps": {name: {"executable": file_digest(stage / (name + ".app") / "Contents" / "MacOS" / name),
                             "metadata": file_digest(stage / (name + ".app") / "Contents" / "Info.plist")}
                     for name in TARGETS}}


def open_package_file(output, parts):
    directory = os.open(output, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = child
        return os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
    finally:
        os.close(directory)


def verify_receipt(root):
    output = root / "build"
    descriptor = open_package_file(output, ["package-receipt.json"])
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_size > 1024 * 1024:
            raise RuntimeError("Invalid or oversized package receipt")
        chunks = []; total = 0
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk: break
            total += len(chunk)
            if total > 1024 * 1024: raise RuntimeError("Oversized package receipt")
            chunks.append(chunk)
    finally:
        os.close(descriptor)

    def unique_members(pairs):
        result = {}
        for key, value in pairs:
            if key in result: raise ValueError("Duplicate package receipt member")
            result[key] = value
        return result

    try:
        receipt = json.loads(b"".join(chunks).decode("utf-8"), object_pairs_hook=unique_members)
    except (ValueError, RecursionError) as error:
        raise RuntimeError("Malformed package receipt") from error

    def valid_digest(value):
        return (isinstance(value, dict) and set(value) == {"sha256", "bytes"}
                and isinstance(value["sha256"], str) and len(value["sha256"]) == 64
                and all(c in "0123456789abcdef" for c in value["sha256"])
                and type(value["bytes"]) is int and 0 <= value["bytes"] <= 128 * 1024 * 1024)

    if (not isinstance(receipt, dict) or type(receipt.get("version")) is not int or receipt["version"] != 1
            or receipt.get("algorithm") != "SHA-256" or receipt.get("configuration") not in ("debug", "release")
            or not isinstance(receipt.get("apps"), dict) or set(receipt["apps"]) != set(TARGETS)
            or not isinstance(receipt.get("sourceInputs"), dict)
            or not receipt["sourceInputs"] or len(receipt["sourceInputs"]) > 10000
            or not all(valid_digest(value) for value in receipt["sourceInputs"].values())):
        raise RuntimeError("Invalid package receipt contract")
    for record in receipt["apps"].values():
        if not isinstance(record, dict) or set(record) != {"executable", "metadata"} or not all(valid_digest(v) for v in record.values()):
            raise RuntimeError("Invalid package receipt app record")
    checks = {}
    # Never use receipt-controlled paths to open files.
    for name in TARGETS:
        for key, suffix in [("executable", ["MacOS", name]), ("metadata", ["Info.plist"])]:
            actual = digest_owned_descriptor(open_package_file(output, [name + ".app", "Contents"] + suffix))
            checks[name + "." + key] = actual == receipt["apps"][name][key]
    current_sources = source_inputs(root)
    sources_match = current_sources == receipt["sourceInputs"]
    return {"status": "matched" if all(checks.values()) and sources_match else "mismatch",
            "packageFiles": checks, "sourceInputsMatch": sources_match,
            "sourceFileChecks": len(current_sources), "signedAttestation": False,
            "snapshotOnly": True, "configuration": receipt["configuration"]}


def main(configuration):
    if configuration not in ("debug", "release"):
        raise ValueError("Usage: build-apps.sh [debug|release|--recovery-status|--verify-receipt]")
    root = Path(__file__).resolve().parent.parent
    os.chdir(root)
    output = root / "build"
    output.mkdir(exist_ok=True)
    with packaging_lock(output):
        validate_destinations(output)
        require_stopped()
        inputs = source_inputs(root)
        if not inputs or len(inputs) > 10000:
            raise RuntimeError("Too many source inputs for package receipt")
        subprocess.run(["swift", "build", "-c", configuration], check=True)
        binary = Path(subprocess.check_output(["swift", "build", "-c", configuration, "--show-bin-path"], text=True).strip())
        with staging_directory(output) as stage:
            # Prepare and verify every app before changing either destination.
            for name in TARGETS:
                app = stage / (name + ".app")
                executable = app / "Contents" / "MacOS" / name
                executable.parent.mkdir(parents=True)
                shutil.copy2(binary / name, executable)
                bundle = "com.milyonus.computeruse" + (".fixture" if name == "ComputerUseFixture" else "")
                metadata = dict(CFBundleIdentifier=bundle, CFBundleExecutable=name, CFBundleName=name,
                                CFBundleDisplayName=name, CFBundlePackageType="APPL", CFBundleShortVersionString="0.1.0",
                                CFBundleVersion="1", LSMinimumSystemVersion="14.0", NSHighResolutionCapable=True)
                (app / "Contents" / "Info.plist").write_bytes(plistlib.dumps(metadata))
                subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", "--options", "runtime", str(app)], check=True)
                subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(app)], check=True)
            if source_inputs(root) != inputs:
                raise RuntimeError("Swift sources changed during packaging; rebuild before publication")
            receipt = stage / "package-receipt.json"
            receipt_data = (json.dumps(package_receipt(stage, configuration, inputs), indent=2, sort_keys=True) + "\n").encode("utf-8")
            if len(receipt_data) > 1024 * 1024:
                raise RuntimeError("Package receipt exceeds size limit")
            receipt.write_bytes(receipt_data)
            require_stopped()
            validate_destinations(output)
            for name in TARGETS:
                require_stopped()
                destination = output / (name + ".app")
                validate_destinations(output)
                publish(stage / (name + ".app"), destination, stage / (name + ".previous"))
            os.replace(receipt, output / "package-receipt.json")
        print(f"Development bundles are ready in {output} (ad-hoc signed, not notarized).")


if __name__ == "__main__":
    try:
        if len(sys.argv) > 2:
            raise ValueError("Usage: build-apps.sh [debug|release|--recovery-status|--verify-receipt]")
        if len(sys.argv) == 2 and sys.argv[1] == "--recovery-status":
            print(json.dumps(recovery_status(Path(__file__).resolve().parent.parent / "build"), sort_keys=True))
        elif len(sys.argv) == 2 and sys.argv[1] == "--verify-receipt":
            result = verify_receipt(Path(__file__).resolve().parent.parent)
            print(json.dumps(result, sort_keys=True))
            if result["status"] != "matched": sys.exit(1)
        else:
            main(sys.argv[1] if len(sys.argv) == 2 else "debug")
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"Packaging failed: {error}", file=sys.stderr)
        sys.exit(1)
