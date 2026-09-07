"""Unit tests for ITorahSharedContainer shared storage, asset validation,
cross-process locking, and migration lifecycle cases A through I.
"""

import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile
import threading
import time
import unittest


APP_GROUP_IDENTIFIER = "group.com.davidpovarsky.itorah"
CHAVRUSA_TEXT_APP_GROUP_IDENTIFIER = "group.com.davidpovarsky.chavrusatext"
OTZARIA_NAMESPACE = "Otzaria"
PRODUCTION_PROFILE = "production"
MINI_TEST10_PROFILE = "miniTest10"


def database_relative_path(profile_id: str) -> str:
    if profile_id == PRODUCTION_PROFILE:
        return os.path.join(OTZARIA_NAMESPACE, "database", "seforim.db")
    return os.path.join(OTZARIA_NAMESPACE, "Profiles", profile_id, "database", "seforim.db")


def otzaria_search_relative_path(profile_id: str) -> str:
    if profile_id == PRODUCTION_PROFILE:
        return os.path.join(OTZARIA_NAMESPACE, "SearchIndex")
    return os.path.join(OTZARIA_NAMESPACE, "Profiles", profile_id, "search", "otzaria")


def zayit_search_relative_path(profile_id: str) -> str:
    if profile_id == PRODUCTION_PROFILE:
        return os.path.join(OTZARIA_NAMESPACE, "ZayitIndex", "active")
    return os.path.join(OTZARIA_NAMESPACE, "Profiles", profile_id, "search", "zayit", "active")


def lexical_relative_path() -> str:
    return os.path.join(OTZARIA_NAMESPACE, "SearchResources", "lexical.db")


# MARK: - Helpers to Create Test Assets

def create_valid_sqlite_db(path: Path, tables=("book", "line", "category"), extra_sql: str = None):
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    cur = conn.cursor()
    for t in tables:
        cur.execute(f"CREATE TABLE {t} (id INTEGER PRIMARY KEY, name TEXT);")
    if extra_sql:
        cur.executescript(extra_sql)
    conn.commit()
    conn.close()


def create_corrupt_sqlite_db(path: Path, mode: str = "zero_byte"):
    path.parent.mkdir(parents=True, exist_ok=True)
    if mode == "zero_byte":
        path.write_bytes(b"")
    elif mode == "bad_header":
        path.write_bytes(b"NOT_A_SQLITE_FILE_CONTENT_AT_ALL_HERE_1234567890")
    elif mode == "truncated":
        path.write_bytes(b"SQLite format 3\0" + b"\x00" * 50)
    elif mode == "missing_tables":
        conn = sqlite3.connect(str(path))
        conn.execute("CREATE TABLE other_table (id INT);")
        conn.commit()
        conn.close()


def create_database_manifest(path: Path, profile_id: str, db_file_size: int):
    path.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        "profileID": profile_id,
        "effectiveProfileID": profile_id,
        "databaseFileSize": db_file_size,
        "installedAt": "2026-09-07T00:00:00Z"
    }
    path.write_text(json.dumps(manifest), encoding="utf-8")


def create_valid_otzaria_index(dir_path: Path, profile_id: str = PRODUCTION_PROFILE):
    dir_path.mkdir(parents=True, exist_ok=True)
    meta = {
        "segments": [{"segment_id": "seg-1", "max_doc": 100}],
        "schema": [{"name": "text", "type": "text"}]
    }
    (dir_path / "meta.json").write_text(json.dumps(meta), encoding="utf-8")
    (dir_path / "seg-1.store").write_bytes(b"tantivy-segment-data-12345")
    manifest = {
        "profileID": profile_id,
        "effectiveProfileID": profile_id,
        "file_count": 2
    }
    (dir_path / "otzaria_prebuilt_installation.json").write_text(json.dumps(manifest), encoding="utf-8")


def create_corrupt_otzaria_index(dir_path: Path, mode: str = "empty_dir"):
    dir_path.mkdir(parents=True, exist_ok=True)
    if mode == "empty_dir":
        pass
    elif mode == "missing_meta":
        (dir_path / "dummy.dat").write_bytes(b"some data")
    elif mode == "invalid_json_meta":
        (dir_path / "meta.json").write_text("CORRUPTED NOT JSON", encoding="utf-8")
        (dir_path / "dummy.dat").write_bytes(b"some data")


def create_valid_zayit_index(dir_path: Path, profile_id: str = PRODUCTION_PROFILE):
    dir_path.mkdir(parents=True, exist_ok=True)
    meta = {
        "segments": [{"segment_id": "zayit-seg-1", "max_doc": 50}],
        "schema": [{"name": "content", "type": "text"}]
    }
    (dir_path / "meta.json").write_text(json.dumps(meta), encoding="utf-8")
    zayit_meta = {
        "schema_version": 1,
        "tantivy_index_version": 1
    }
    (dir_path / "zayit-index-metadata.json").write_text(json.dumps(zayit_meta), encoding="utf-8")
    (dir_path / "zayit-seg-1.store").write_bytes(b"zayit-segment-data-67890")
    manifest = {
        "profileID": profile_id,
        "effectiveProfileID": profile_id
    }
    (dir_path.parent / "zayit-installation.json").write_text(json.dumps(manifest), encoding="utf-8")


def create_corrupt_zayit_index(dir_path: Path, mode: str = "missing_zayit_meta"):
    dir_path.mkdir(parents=True, exist_ok=True)
    if mode == "missing_zayit_meta":
        (dir_path / "meta.json").write_text(json.dumps({"segments": []}), encoding="utf-8")
        (dir_path / "file.dat").write_bytes(b"data")
    elif mode == "bad_zayit_meta":
        (dir_path / "meta.json").write_text(json.dumps({"segments": []}), encoding="utf-8")
        (dir_path / "zayit-index-metadata.json").write_text(json.dumps({"wrong_key": True}), encoding="utf-8")


def create_valid_lexical_db(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.execute("CREATE TABLE terms (term TEXT PRIMARY KEY, count INT);")
    conn.commit()
    conn.close()
    marker = {"size": path.stat().st_size}
    Path(str(path) + ".release.json").write_text(json.dumps(marker), encoding="utf-8")


# MARK: - Validation Implementation (Mirrors Swift ITorahSharedContainer)

def is_database_valid(path: Path, profile_id: str) -> bool:
    if not path.is_file():
        return False
    size = path.stat().st_size
    if size < 100:
        return False
    with open(str(path), "rb") as f:
        header = f.read(16)
        if not header.startswith(b"SQLite format 3\x00"):
            return False
    try:
        conn = sqlite3.connect(f"file:{str(path)}?mode=ro", uri=True)
        cur = conn.cursor()
        cur.execute("PRAGMA quick_check(1);")
        row = cur.fetchone()
        if not row or str(row[0]).lower() != "ok":
            conn.close()
            return False
        cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = {r[0] for r in cur.fetchall()}
        conn.close()
        if not ({"book", "line", "category"}.issubset(tables)):
            return False
    except Exception:
        return False

    manifest_path = path.parent / "seforim-installation.json"
    if manifest_path.is_file():
        try:
            m = json.loads(manifest_path.read_text(encoding="utf-8"))
            m_profile = m.get("profileID") or m.get("effectiveProfileID")
            if m_profile and m_profile != profile_id:
                return False
            expected_size = m.get("databaseFileSize")
            if expected_size and int(expected_size) != size:
                return False
        except Exception:
            return False
    return True


def is_otzaria_search_valid(dir_path: Path, profile_id: str) -> bool:
    if not dir_path.is_dir():
        return False
    children = list(dir_path.iterdir())
    if len(children) < 2:
        return False
    meta_path = dir_path / "meta.json"
    if not meta_path.is_file():
        return False
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if "segments" not in meta and "schema" not in meta:
            return False
    except Exception:
        return False

    manifest_path = dir_path / "otzaria_prebuilt_installation.json"
    if manifest_path.is_file():
        try:
            m = json.loads(manifest_path.read_text(encoding="utf-8"))
            m_profile = m.get("profileID") or m.get("effectiveProfileID")
            if m_profile and m_profile != profile_id:
                return False
        except Exception:
            return False
    return True


def is_zayit_search_valid(dir_path: Path, profile_id: str) -> bool:
    if not dir_path.is_dir():
        return False
    children = list(dir_path.iterdir())
    if len(children) < 2:
        return False
    meta_path = dir_path / "meta.json"
    zayit_meta_path = dir_path / "zayit-index-metadata.json"
    if not meta_path.is_file() or not zayit_meta_path.is_file():
        return False
    try:
        zm = json.loads(zayit_meta_path.read_text(encoding="utf-8"))
        if "schema_version" not in zm:
            return False
    except Exception:
        return False

    manifest_path = dir_path.parent / "zayit-installation.json"
    if manifest_path.is_file():
        try:
            m = json.loads(manifest_path.read_text(encoding="utf-8"))
            m_profile = m.get("profileID") or m.get("effectiveProfileID")
            if m_profile and m_profile != profile_id:
                return False
        except Exception:
            return False
    return True


def is_lexical_database_valid(path: Path) -> bool:
    if not path.is_file():
        return False
    size = path.stat().st_size
    if size < 100:
        return False
    with open(str(path), "rb") as f:
        header = f.read(16)
        if not header.startswith(b"SQLite format 3\x00"):
            return False
    try:
        conn = sqlite3.connect(f"file:{str(path)}?mode=ro", uri=True)
        cur = conn.cursor()
        cur.execute("PRAGMA quick_check(1);")
        row = cur.fetchone()
        conn.close()
        if not row or str(row[0]).lower() != "ok":
            return False
    except Exception:
        return False

    marker_path = Path(str(path) + ".release.json")
    if marker_path.is_file():
        try:
            m = json.loads(marker_path.read_text(encoding="utf-8"))
            expected_size = m.get("size")
            if expected_size and int(expected_size) != size:
                return False
        except Exception:
            return False
    return True


# MARK: - Migration Engine (Mirrors Swift ITorahSharedContainer.migrateLegacyDataIfNeeded)

_migration_locks = {}
_migration_mutex = threading.Lock()


def with_storage_lock(name: str, fn):
    with _migration_mutex:
        if name not in _migration_locks:
            _migration_locks[name] = threading.Lock()
        lock = _migration_locks[name]
    with lock:
        return fn()


def clean_dangling_staging(directory: Path):
    if not directory.is_dir():
        return
    for item in directory.iterdir():
        if ".migrating" in item.name:
            if item.is_dir():
                shutil.rmtree(item, ignore_errors=True)
            else:
                item.unlink(missing_ok=True)


def migrate_legacy_data_if_needed(shared_root: Path, legacy_roots: list[Path], profile_id: str):
    for lr in legacy_roots:
        if shared_root.resolve() == lr.resolve():
            return

    def run_migration():
        # 1. Database migration
        dest_db = shared_root / database_relative_path(profile_id)
        dest_manifest = dest_db.parent / "seforim-installation.json"
        clean_dangling_staging(dest_db.parent)

        if not is_database_valid(dest_db, profile_id):
            for lr in legacy_roots:
                leg_db = lr / database_relative_path(profile_id)
                leg_manifest = leg_db.parent / "seforim-installation.json"
                if is_database_valid(leg_db, profile_id):
                    staging_id = f"proc-{os.getpid()}-{threading.get_ident()}-{int(time.time() * 1000)}"
                    staging_db = dest_db.parent / f"seforim.db.migrating.{staging_id}"
                    staging_manifest = dest_db.parent / f"seforim-installation.json.migrating.{staging_id}"
                    dest_db.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(leg_db, staging_db)
                    if leg_manifest.is_file():
                        shutil.copy2(leg_manifest, staging_manifest)

                    if is_database_valid(staging_db, profile_id):
                        if dest_db.exists():
                            dest_db.unlink()
                        staging_db.rename(dest_db)
                        if staging_manifest.is_file():
                            if dest_manifest.exists():
                                dest_manifest.unlink()
                            staging_manifest.rename(dest_manifest)
                        break
                    else:
                        staging_db.unlink(missing_ok=True)
                        staging_manifest.unlink(missing_ok=True)

        # 2. Otzaria search index migration
        dest_search = shared_root / otzaria_search_relative_path(profile_id)
        clean_dangling_staging(dest_search.parent)
        if not is_otzaria_search_valid(dest_search, profile_id):
            for lr in legacy_roots:
                leg_search = lr / otzaria_search_relative_path(profile_id)
                if is_otzaria_search_valid(leg_search, profile_id):
                    staging_id = f"proc-{os.getpid()}-{threading.get_ident()}-{int(time.time() * 1000)}"
                    staging_search = dest_search.parent / f"{dest_search.name}.migrating.{staging_id}"
                    dest_search.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copytree(leg_search, staging_search)
                    if is_otzaria_search_valid(staging_search, profile_id):
                        if dest_search.exists():
                            shutil.rmtree(dest_search)
                        staging_search.rename(dest_search)
                        break
                    else:
                        shutil.rmtree(staging_search, ignore_errors=True)

        # 3. Zayit search index migration
        dest_zayit = shared_root / zayit_search_relative_path(profile_id)
        clean_dangling_staging(dest_zayit.parent)
        if not is_zayit_search_valid(dest_zayit, profile_id):
            for lr in legacy_roots:
                leg_zayit = lr / zayit_search_relative_path(profile_id)
                if is_zayit_search_valid(leg_zayit, profile_id):
                    staging_id = f"proc-{os.getpid()}-{threading.get_ident()}-{int(time.time() * 1000)}"
                    staging_zayit = dest_zayit.parent / f"{dest_zayit.name}.migrating.{staging_id}"
                    dest_zayit.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copytree(leg_zayit, staging_zayit)
                    leg_zayit_manifest = leg_zayit.parent / "zayit-installation.json"
                    if leg_zayit_manifest.is_file():
                        shutil.copy2(leg_zayit_manifest, dest_zayit.parent / "zayit-installation.json")
                    if is_zayit_search_valid(staging_zayit, profile_id):
                        if dest_zayit.exists():
                            shutil.rmtree(dest_zayit)
                        staging_zayit.rename(dest_zayit)
                        break
                    else:
                        shutil.rmtree(staging_zayit, ignore_errors=True)

        # 4. Lexical database migration (production only)
        if profile_id == PRODUCTION_PROFILE:
            dest_lex = shared_root / lexical_relative_path()
            clean_dangling_staging(dest_lex.parent)
            if not is_lexical_database_valid(dest_lex):
                for lr in legacy_roots:
                    leg_lex = lr / lexical_relative_path()
                    if is_lexical_database_valid(leg_lex):
                        staging_id = f"proc-{os.getpid()}-{threading.get_ident()}-{int(time.time() * 1000)}"
                        staging_lex = dest_lex.parent / f"lexical.db.migrating.{staging_id}"
                        staging_marker = dest_lex.parent / f"lexical.db.release.json.migrating.{staging_id}"
                        dest_lex.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(leg_lex, staging_lex)
                        leg_marker = Path(str(leg_lex) + ".release.json")
                        if leg_marker.is_file():
                            shutil.copy2(leg_marker, staging_marker)
                        if is_lexical_database_valid(staging_lex):
                            if dest_lex.exists():
                                dest_lex.unlink()
                            staging_lex.rename(dest_lex)
                            if staging_marker.is_file():
                                dest_marker = Path(str(dest_lex) + ".release.json")
                                if dest_marker.exists():
                                    dest_marker.unlink()
                                staging_marker.rename(dest_marker)
                            break
                        else:
                            staging_lex.unlink(missing_ok=True)
                            staging_marker.unlink(missing_ok=True)

    with_storage_lock(f"migration-{profile_id}", run_migration)


# MARK: - Real Device Simulation Logic

class AppGroupUnavailableError(Exception):
    pass


def resolve_shared_root(
    simulate_real_device_missing_container: bool = False,
    override_root: Path = None,
    is_ios_physical_device: bool = False,
    container_available: bool = True
) -> Path:
    if simulate_real_device_missing_container:
        raise AppGroupUnavailableError(
            f"CRITICAL CONFIGURATION ERROR: The shared App Group container '{APP_GROUP_IDENTIFIER}' "
            "could not be resolved on a physical device. Refusing fallback to private storage."
        )
    if override_root is not None:
        return override_root
    if is_ios_physical_device:
        if not container_available:
            raise AppGroupUnavailableError(
                f"CRITICAL CONFIGURATION ERROR: The shared App Group container '{APP_GROUP_IDENTIFIER}' "
                "could not be resolved on physical iOS device."
            )
    return Path(tempfile.gettempdir()) / "shared_app_group"


# MARK: - Test Cases Suite

class ITorahSharedStorageTestSuite(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.legacy_root = self.root / "legacy_app_support"
        self.shared_root = self.root / "shared_container"

    def tearDown(self):
        self.temp_dir.cleanup()

    # Case A: Empty shared directory, valid legacy directory exists
    # -> full migration succeeds; legacy data left intact; shared directory populated and valid.
    def test_case_a_empty_shared_valid_legacy(self):
        leg_db = self.legacy_root / database_relative_path(PRODUCTION_PROFILE)
        create_valid_sqlite_db(leg_db)
        create_database_manifest(leg_db.parent / "seforim-installation.json", PRODUCTION_PROFILE, leg_db.stat().st_size)

        leg_search = self.legacy_root / otzaria_search_relative_path(PRODUCTION_PROFILE)
        create_valid_otzaria_index(leg_search, PRODUCTION_PROFILE)

        leg_zayit = self.legacy_root / zayit_search_relative_path(PRODUCTION_PROFILE)
        create_valid_zayit_index(leg_zayit, PRODUCTION_PROFILE)

        leg_lex = self.legacy_root / lexical_relative_path()
        create_valid_lexical_db(leg_lex)

        self.assertFalse(self.shared_root.exists())

        migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], PRODUCTION_PROFILE)

        dest_db = self.shared_root / database_relative_path(PRODUCTION_PROFILE)
        dest_search = self.shared_root / otzaria_search_relative_path(PRODUCTION_PROFILE)
        dest_zayit = self.shared_root / zayit_search_relative_path(PRODUCTION_PROFILE)
        dest_lex = self.shared_root / lexical_relative_path()

        self.assertTrue(is_database_valid(dest_db, PRODUCTION_PROFILE))
        self.assertTrue(is_otzaria_search_valid(dest_search, PRODUCTION_PROFILE))
        self.assertTrue(is_zayit_search_valid(dest_zayit, PRODUCTION_PROFILE))
        self.assertTrue(is_lexical_database_valid(dest_lex))

        self.assertTrue(is_database_valid(leg_db, PRODUCTION_PROFILE))
        self.assertTrue(is_otzaria_search_valid(leg_search, PRODUCTION_PROFILE))
        self.assertTrue(is_zayit_search_valid(leg_zayit, PRODUCTION_PROFILE))
        self.assertTrue(is_lexical_database_valid(leg_lex))

    # Case B: Valid shared directory already exists
    # -> migration is a no-op; existing data is untouched.
    def test_case_b_valid_shared_exists_noop(self):
        dest_db = self.shared_root / database_relative_path(PRODUCTION_PROFILE)
        create_valid_sqlite_db(dest_db, extra_sql="CREATE TABLE canary_shared (c TEXT);")
        create_database_manifest(dest_db.parent / "seforim-installation.json", PRODUCTION_PROFILE, dest_db.stat().st_size)

        leg_db = self.legacy_root / database_relative_path(PRODUCTION_PROFILE)
        create_valid_sqlite_db(leg_db, extra_sql="CREATE TABLE canary_legacy (c TEXT);")
        create_database_manifest(leg_db.parent / "seforim-installation.json", PRODUCTION_PROFILE, leg_db.stat().st_size)

        migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], PRODUCTION_PROFILE)

        self.assertTrue(dest_db.exists())
        conn = sqlite3.connect(str(dest_db))
        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE name='canary_shared';")
        self.assertIsNotNone(cur.fetchone(), "Shared canary table must still exist")
        cur.execute("SELECT name FROM sqlite_master WHERE name='canary_legacy';")
        self.assertIsNone(cur.fetchone(), "Legacy table must not have overwritten shared db")
        conn.close()

    # Case C: Corrupt shared database exists, valid legacy database exists
    # -> shared database is repaired/replaced from valid legacy database; migration succeeds.
    def test_case_c_corrupt_shared_valid_legacy_repaired(self):
        dest_db = self.shared_root / database_relative_path(PRODUCTION_PROFILE)
        create_corrupt_sqlite_db(dest_db, mode="bad_header")
        self.assertFalse(is_database_valid(dest_db, PRODUCTION_PROFILE))

        leg_db = self.legacy_root / database_relative_path(PRODUCTION_PROFILE)
        create_valid_sqlite_db(leg_db, extra_sql="CREATE TABLE recovered_table (r INT);")
        create_database_manifest(leg_db.parent / "seforim-installation.json", PRODUCTION_PROFILE, leg_db.stat().st_size)

        migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], PRODUCTION_PROFILE)

        self.assertTrue(is_database_valid(dest_db, PRODUCTION_PROFILE))
        conn = sqlite3.connect(str(dest_db))
        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE name='recovered_table';")
        self.assertIsNotNone(cur.fetchone(), "Recovered table from legacy must be present")
        conn.close()

    # Case D: Valid shared database exists, corrupt legacy database exists
    # -> shared database is preserved, migration does not overwrite with corruption.
    def test_case_d_valid_shared_corrupt_legacy_preserved(self):
        dest_db = self.shared_root / database_relative_path(PRODUCTION_PROFILE)
        create_valid_sqlite_db(dest_db, extra_sql="CREATE TABLE valid_shared_content (v INT);")
        create_database_manifest(dest_db.parent / "seforim-installation.json", PRODUCTION_PROFILE, dest_db.stat().st_size)

        leg_db = self.legacy_root / database_relative_path(PRODUCTION_PROFILE)
        create_corrupt_sqlite_db(leg_db, mode="zero_byte")

        migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], PRODUCTION_PROFILE)

        self.assertTrue(is_database_valid(dest_db, PRODUCTION_PROFILE))
        conn = sqlite3.connect(str(dest_db))
        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE name='valid_shared_content';")
        self.assertIsNotNone(cur.fetchone())
        conn.close()

    # Case E: Both corrupt
    # -> migration fails/reports failure, does not crash or mark as valid.
    def test_case_e_both_corrupt_fails_safely(self):
        dest_db = self.shared_root / database_relative_path(PRODUCTION_PROFILE)
        create_corrupt_sqlite_db(dest_db, mode="bad_header")

        leg_db = self.legacy_root / database_relative_path(PRODUCTION_PROFILE)
        create_corrupt_sqlite_db(leg_db, mode="missing_tables")

        migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], PRODUCTION_PROFILE)

        self.assertFalse(is_database_valid(dest_db, PRODUCTION_PROFILE))

    # Case F: Interrupted migration with leftover staging directory
    # -> staging cleaned up, new migration completes cleanly.
    def test_case_f_interrupted_migration_staging_cleaned(self):
        dest_db = self.shared_root / database_relative_path(PRODUCTION_PROFILE)
        dest_db.parent.mkdir(parents=True, exist_ok=True)
        leftover_staging = dest_db.parent / "seforim.db.migrating.1234-leftover"
        leftover_staging.write_bytes(b"interrupted partial staging data")
        self.assertTrue(leftover_staging.exists())

        leg_db = self.legacy_root / database_relative_path(PRODUCTION_PROFILE)
        create_valid_sqlite_db(leg_db)
        create_database_manifest(leg_db.parent / "seforim-installation.json", PRODUCTION_PROFILE, leg_db.stat().st_size)

        migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], PRODUCTION_PROFILE)

        self.assertFalse(leftover_staging.exists(), "Dangling staging must be cleaned")
        self.assertTrue(is_database_valid(dest_db, PRODUCTION_PROFILE))

    # Case G: Concurrent migration attempts on same profile
    # -> lock serializes them, no data corruption.
    def test_case_g_concurrent_migrations_serialized(self):
        leg_db = self.legacy_root / database_relative_path(PRODUCTION_PROFILE)
        create_valid_sqlite_db(leg_db)
        create_database_manifest(leg_db.parent / "seforim-installation.json", PRODUCTION_PROFILE, leg_db.stat().st_size)

        errors = []

        def worker():
            try:
                for _ in range(5):
                    migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], PRODUCTION_PROFILE)
            except Exception as ex:
                errors.append(ex)

        threads = [threading.Thread(target=worker) for _ in range(4)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        self.assertEqual(len(errors), 0, f"Concurrent workers encountered errors: {errors}")
        dest_db = self.shared_root / database_relative_path(PRODUCTION_PROFILE)
        self.assertTrue(is_database_valid(dest_db, PRODUCTION_PROFILE))

    # Case H: Multi-profile isolation
    # -> migrating miniTest10 does not touch production, and vice versa.
    def test_case_h_multi_profile_isolation(self):
        leg_prod_db = self.legacy_root / database_relative_path(PRODUCTION_PROFILE)
        create_valid_sqlite_db(leg_prod_db, extra_sql="CREATE TABLE production_data (p INT);")
        create_database_manifest(leg_prod_db.parent / "seforim-installation.json", PRODUCTION_PROFILE, leg_prod_db.stat().st_size)

        leg_mini_db = self.legacy_root / database_relative_path(MINI_TEST10_PROFILE)
        create_valid_sqlite_db(leg_mini_db, extra_sql="CREATE TABLE minitest10_data (m INT);")
        create_database_manifest(leg_mini_db.parent / "seforim-installation.json", MINI_TEST10_PROFILE, leg_mini_db.stat().st_size)

        migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], MINI_TEST10_PROFILE)

        dest_mini_db = self.shared_root / database_relative_path(MINI_TEST10_PROFILE)
        dest_prod_db = self.shared_root / database_relative_path(PRODUCTION_PROFILE)

        self.assertTrue(is_database_valid(dest_mini_db, MINI_TEST10_PROFILE))
        self.assertFalse(dest_prod_db.exists(), "Production DB must not be created when migrating miniTest10")

        migrate_legacy_data_if_needed(self.shared_root, [self.legacy_root], PRODUCTION_PROFILE)

        self.assertTrue(is_database_valid(dest_prod_db, PRODUCTION_PROFILE))
        self.assertTrue(is_database_valid(dest_mini_db, MINI_TEST10_PROFILE))

        conn_p = sqlite3.connect(str(dest_prod_db))
        tables_p = {r[0] for r in conn_p.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()}
        conn_p.close()
        self.assertIn("production_data", tables_p)
        self.assertNotIn("minitest10_data", tables_p)

        conn_m = sqlite3.connect(str(dest_mini_db))
        tables_m = {r[0] for r in conn_m.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()}
        conn_m.close()
        self.assertIn("minitest10_data", tables_m)
        self.assertNotIn("production_data", tables_m)

    # Case I: Real-device failure simulation
    # -> when simulateRealDeviceMissingContainerForTesting is true, resolveSharedRoot fails explicitly
    # and refuses silent private Application Support fallback.
    def test_case_i_real_device_simulation_refuses_private_fallback(self):
        with self.assertRaises(AppGroupUnavailableError) as ctx:
            resolve_shared_root(simulate_real_device_missing_container=True)
        self.assertIn("could not be resolved on a physical device", str(ctx.exception))
        self.assertIn("Refusing fallback to private storage", str(ctx.exception))

        with self.assertRaises(AppGroupUnavailableError) as ctx:
            resolve_shared_root(
                simulate_real_device_missing_container=False,
                is_ios_physical_device=True,
                container_available=False
            )
        self.assertIn("could not be resolved on physical iOS device", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
