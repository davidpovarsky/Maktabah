"""Complete consumer Mach-O symbol coverage with a deadline during every read.

The nlist/export split follows the qualified original Anytype release inspector
(anytype-swift be863930733cbaa07d3e325b0406f4dcfa4d8684). This consumer audit also
needs local, undefined and debugger symbols; the SDK's extern/defined-only
ownership helper alone cannot satisfy that wider original consumer contract.
No nm dyld reconciliation is used, and no native export is omitted.
"""
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import time


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1_048_576), b""):
            value.update(block)
    return value.hexdigest()


def bounded_stream(command, path, timeout):
    """Retain the entire merged stream, even on timeout; never await EOF first."""
    path = Path(path)
    require(timeout > 0, "A positive command deadline is required")
    started = time.monotonic()
    deadline = started + timeout
    process = None
    error = None
    raw_hash, raw_bytes = hashlib.sha256(), 0
    with path.open("xb") as destination:
        with gzip.GzipFile(fileobj=destination, mode="wb", compresslevel=1, mtime=0) as output:
            try:
                process = subprocess.Popen(
                    command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    start_new_session=True)
                os.set_blocking(process.stdout.fileno(), False)
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout, selectors.EVENT_READ)
                    while selector.get_map():
                        remaining = deadline - time.monotonic()
                        if remaining <= 0:
                            raise subprocess.TimeoutExpired(command, timeout)
                        for key, _ in selector.select(min(remaining, 0.25)):
                            try:
                                block = os.read(key.fd, 65_536)
                            except BlockingIOError:
                                continue
                            if not block:
                                selector.unregister(key.fileobj)
                                break
                            output.write(block)
                            raw_hash.update(block)
                            raw_bytes += len(block)
                    process.wait(timeout=max(0.001, deadline - time.monotonic()))
                require(process.returncode == 0, "Symbol-inspection command failed")
            except BaseException as failure:
                error = failure
                if process is not None:
                    # Only this invocation's new process group is terminated.
                    # A child may retain stdout even after its parent has exited.
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    process.wait(timeout=10)
            finally:
                if process is not None and process.stdout is not None:
                    process.stdout.close()
    receipt = {
        "command": command, "pid": process.pid if process else None,
        "returncode": process.returncode if process else None,
        "status": "PASS" if error is None else
                  ("TIMEOUT" if isinstance(error, subprocess.TimeoutExpired) else "FAIL"),
        "deadline_seconds": timeout,
        "elapsed_seconds": round(time.monotonic() - started, 6),
        "path": path.name, "sha256": digest(path),
        "compressed_bytes": path.stat().st_size,
        "raw_bytes": raw_bytes, "raw_sha256": raw_hash.hexdigest(),
    }
    receipt_path = path.with_name(path.name + ".process.json")
    with receipt_path.open("x") as stream:
        stream.write(json.dumps(receipt, sort_keys=True, indent=2) + "\n")
    if error is not None:
        raise error
    return receipt


def lines(path):
    with gzip.open(path, "rt", encoding="utf-8", errors="strict") as stream:
        yield from stream


def export_sizes(text):
    """Require complete native header-bound commands for every Mach-O member."""
    result, group, current, header_stage, members = [], None, None, None, 0
    columns = ["magic", "cputype", "cpusubtype", "caps", "filetype",
               "ncmds", "sizeofcmds", "flags"]

    def finish_command():
        nonlocal current
        if current is None:
            return
        require(current["cmd"] is not None and current["size"] is not None,
                "Incomplete native load command")
        require(current["size"] >= 8 and current["size"] % 4 == 0,
                "Malformed native load-command size")
        group["sizes"].append(current["size"])
        if current["cmd"] in {"LC_DYLD_EXPORTS_TRIE", "LC_DYLD_INFO", "LC_DYLD_INFO_ONLY"}:
            require(len(current["exports"]) == 1, "Incomplete/ambiguous native export size")
            result.append({"command": current["cmd"], "bytes": current["exports"][0]})
        current = None

    def finish_member():
        nonlocal group, members
        finish_command()
        if group is not None:
            require(len(group["sizes"]) == group["ncmds"],
                    "Native load commands are incomplete relative to the Mach-O header")
            require(sum(group["sizes"]) == group["sizeofcmds"],
                    "Native load-command sizes disagree with the Mach-O header")
            members += 1
            group = None

    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "Mach header":
            require(header_stage is None, "Incomplete preceding native Mach-O header")
            finish_member()
            header_stage = "columns"
            continue
        if header_stage == "columns":
            require(stripped.split() == columns, "Unrecognized native Mach-O header columns")
            header_stage = "values"
            continue
        if header_stage == "values":
            fields = stripped.split()
            require(len(fields) == len(columns), "Incomplete native Mach-O header values")
            values = dict(zip(columns, fields))
            require(re.fullmatch(r"\d+", values["ncmds"])
                    and re.fullmatch(r"\d+", values["sizeofcmds"]),
                    "Invalid native Mach-O load-command totals")
            count, total = int(values["ncmds"]), int(values["sizeofcmds"])
            require(0 < count < 2**32 and count * 8 <= total < 2**32,
                    "Invalid native Mach-O load-command bounds")
            group = {"ncmds": count, "sizeofcmds": total, "sizes": []}
            header_stage = None
            continue
        match = re.fullmatch(r"Load command (\d+)", stripped)
        if match:
            require(group is not None, "Native load command lacks its original Mach-O header")
            finish_command()
            require(int(match.group(1)) == len(group["sizes"])
                    and len(group["sizes"]) < group["ncmds"],
                    "Missing, duplicate or out-of-order native load command")
            current = {"cmd": None, "size": None, "exports": []}
        elif stripped.startswith("cmd "):
            require(current is not None and current["cmd"] is None
                    and re.fullmatch(r"cmd LC_[A-Z0-9_]+", stripped),
                    "Missing or ambiguous native load command")
            current["cmd"] = stripped.split()[1]
        elif stripped.startswith("cmdsize "):
            require(current is not None and current["size"] is None
                    and re.fullmatch(r"cmdsize \d+", stripped),
                    "Missing or ambiguous native load-command size")
            current["size"] = int(stripped.split()[1])
        elif current and current["cmd"] in {"LC_DYLD_INFO", "LC_DYLD_INFO_ONLY"} \
                and stripped.startswith("export_size "):
            require(re.fullmatch(r"export_size \d+", stripped), "Malformed native export size")
            current["exports"].append(int(stripped.split()[1]))
        elif current and current["cmd"] == "LC_DYLD_EXPORTS_TRIE" \
                and stripped.startswith("datasize "):
            require(re.fullmatch(r"datasize \d+", stripped), "Malformed native trie size")
            current["exports"].append(int(stripped.split()[1]))
    require(header_stage is None, "Truncated native Mach-O header")
    finish_member()
    require(members > 0, "No complete native Mach-O member was inspected")
    return result


def is_symbol_free_xcode_preview(binary, arch, symbols, loads):
    binary = Path(binary)
    if (binary.name != "__preview.dylib" or binary.parent.suffix != ".app" or arch != "arm64"
            or symbols.strip() != str(binary) + ": no symbols"):
        return False
    symtab = re.findall(r"(?m)^\s*cmd LC_SYMTAB\n((?:(?!Load command)[^\n]*\n)*)", loads)
    build = re.findall(r"(?m)^\s*cmd LC_BUILD_VERSION\n((?:(?!Load command)[^\n]*\n)*)", loads)
    return (len(symtab) == 1 and re.search(r"(?m)^\s*nsyms 0$", symtab[0]) is not None
            and len(build) == 1 and re.search(r"(?m)^\s*platform (?:7|IOSSIMULATOR)$", build[0]) is not None
            and "LC_DYLD_EXPORTS_TRIE" in loads and "LC_ID_DYLIB" in loads)


def export_names(text, binary, arch, *, allow_empty_preview=False):
    """Original strict native export grammar, applied to every actual slice."""
    rows = text.splitlines()
    require(len(rows) >= (3 if allow_empty_preview else 4) and rows[0] == str(binary) + " [" + arch + "]:"
            and rows[1].strip() == "-exports:"
            and rows[2].split() == ["offset", "symbol"],
            "Unrecognized/incomplete native export listing")
    names, kinds = set(), {}
    for row in rows[3:]:
        match = re.fullmatch(
            r"\s*0x[0-9A-Fa-f]+\s+(\S+?)(?: \[(weak-def|per-thread|absolute)\])?\s*", row)
        require(match is not None, "Unrecognized native export row: " + row[:200])
        name, kind = match.groups()
        require(name not in names, "Duplicate native export symbol")
        names.add(name)
        kinds[kind or "regular"] = kinds.get(kind or "regular", 0) + 1
    require(names or allow_empty_preview, "A nonempty native export range produced no symbols")
    return names, kinds


def inspect(binary, evidence, name):
    """Return complete nlist and native-export streams, with unchanged input."""
    binary, evidence = Path(binary), Path(evidence)
    before = digest(binary)
    arch_path = evidence / (name + "-architectures.txt.gz")
    arches_receipt = bounded_stream(["xcrun", "lipo", "-archs", str(binary)], arch_path, 30)
    arches = "".join(lines(arch_path)).split()
    require(arches and len(arches) == len(set(arches))
            and all(re.fullmatch(r"[A-Za-z0-9_]+", value) for value in arches),
            "Unrecognized/duplicate native architecture list")
    streams, slices = [], []
    for arch in arches:
        prefix = name + "-" + arch
        table_path = evidence / (prefix + "-nlist.txt.gz")
        table = bounded_stream(
            ["xcrun", "nm", "--arch=" + arch, "-a", "--no-dyldinfo", str(binary)],
            table_path, 150)
        require(table["raw_bytes"] > 0, "Empty native all-symbol table output")
        streams.append(table)
        load_path = evidence / (prefix + "-load-commands.txt.gz")
        load = bounded_stream(
            ["xcrun", "otool", "-arch", arch, "-h", "-l", str(binary)], load_path, 60)
        load_text = "".join(lines(load_path))
        ranges = export_sizes(load_text)
        row = {"architecture": arch, "nlist": table, "load_commands": load,
               "native_export_ranges": ranges, "export_trie": None}
        if any(value["bytes"] > 0 for value in ranges):
            trie_path = evidence / (prefix + "-exports.txt.gz")
            trie = bounded_stream(
                ["xcrun", "dyld_info", "-arch", arch, "-exports", str(binary)], trie_path, 60)
            empty_preview = (ranges == [{"command": "LC_DYLD_EXPORTS_TRIE", "bytes": 8}]
                             and is_symbol_free_xcode_preview(binary, arch, "".join(lines(table_path)), load_text))
            names, kinds = export_names("".join(lines(trie_path)), binary, arch,
                                        allow_empty_preview=empty_preview)
            row["export_trie"] = {
                **trie, "definitions": len(names), "kinds": kinds,
                "all_native_rows_parsed": True,
                "xcode_preview_empty_trie": empty_preview and not names,
            }
            streams.append(trie)
        slices.append(row)
    require(digest(binary) == before, "Consumer image changed during symbol inspection")
    return {
        "status": "ALL_NLIST_AND_COMPLETE_NATIVE_EXPORT_TRIES",
        "binary_sha256": before, "architectures": arches,
        "architectures_command": arches_receipt, "slices": slices,
        "symbol_streams": streams, "dyld_exports_omitted": 0,
        "local_undefined_and_debug_nlist_retained": True,
        "original_release_split_reference":
            "anytype-swift/be863930733cbaa07d3e325b0406f4dcfa4d8684",
    }
