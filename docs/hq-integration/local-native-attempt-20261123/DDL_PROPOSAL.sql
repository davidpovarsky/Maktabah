-- PROPOSED only; not executed. All operations use the original captured DB.
-- Values below are the existing source/envelope/body budgets, not SDK ID caps.
-- Installation and exact schema validation are owned by LocalEditorPersistence.
CREATE TABLE main.otzaria_local_editor_native_attempt_schema (
    singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
    version INTEGER NOT NULL CHECK(typeof(version) = 'integer' AND version = 1)
);

CREATE TABLE main.otzaria_local_editor_native_attempts (
    attempt_uuid TEXT PRIMARY KEY NOT NULL
        CHECK(typeof(attempt_uuid) = 'text' AND length(CAST(attempt_uuid AS BLOB)) = 36),
    namespace TEXT NOT NULL
        CHECK(typeof(namespace) = 'text' AND namespace = 'otzaria.local.annotation'),
    annotation_uuid TEXT NOT NULL
        CHECK(typeof(annotation_uuid) = 'text' AND length(CAST(annotation_uuid AS BLOB)) = 36),
    annotation_id INTEGER NOT NULL CHECK(typeof(annotation_id) = 'integer' AND annotation_id > 0),
    prepared_session_uuid TEXT NOT NULL
        CHECK(typeof(prepared_session_uuid) = 'text' AND length(CAST(prepared_session_uuid AS BLOB)) = 36),
    captured_database_url TEXT NOT NULL
        CHECK(typeof(captured_database_url) = 'text'
              AND length(CAST(captured_database_url AS BLOB)) > 0
              AND instr(captured_database_url, char(0)) = 0),
    native_account_id TEXT COLLATE BINARY NOT NULL
        CHECK(typeof(native_account_id) = 'text'
              AND length(CAST(native_account_id AS BLOB)) > 0
              AND instr(native_account_id, char(0)) = 0),
    native_space_id TEXT COLLATE BINARY NOT NULL
        CHECK(typeof(native_space_id) = 'text'
              AND length(CAST(native_space_id AS BLOB)) > 0
              AND instr(native_space_id, char(0)) = 0),
    source_canonical_base64 TEXT NOT NULL
        CHECK(typeof(source_canonical_base64) = 'text'
              AND length(CAST(source_canonical_base64 AS BLOB)) BETWEEN 1 AND 11184812),
    source_digest TEXT NOT NULL
        CHECK(typeof(source_digest) = 'text' AND length(CAST(source_digest AS BLOB)) = 64),
    version_mutation_uuid TEXT NOT NULL
        CHECK(typeof(version_mutation_uuid) = 'text'
              AND length(CAST(version_mutation_uuid AS BLOB)) = 36),
    saved_revision INTEGER NOT NULL
        CHECK(typeof(saved_revision) = 'integer' AND saved_revision > 0),
    payload_digest TEXT NOT NULL
        CHECK(typeof(payload_digest) = 'text' AND length(CAST(payload_digest AS BLOB)) = 64),
    payload_base64 TEXT NOT NULL
        CHECK(typeof(payload_base64) = 'text'
              AND length(CAST(payload_base64 AS BLOB)) BETWEEN 1 AND 2796204),
    destinations_json TEXT NOT NULL
        CHECK(typeof(destinations_json) = 'text' AND destinations_json = '[]'),
    body_format TEXT NOT NULL
        CHECK(typeof(body_format) = 'text'
              AND length(CAST(body_format AS BLOB)) BETWEEN 1 AND 512),
    body_format_version INTEGER NOT NULL
        CHECK(typeof(body_format_version) = 'integer' AND body_format_version > 0),
    body_byte_count INTEGER NOT NULL
        CHECK(typeof(body_byte_count) = 'integer' AND body_byte_count BETWEEN 1 AND 1064976),
    body_digest TEXT NOT NULL
        CHECK(typeof(body_digest) = 'text' AND length(CAST(body_digest AS BLOB)) = 64),
    dispatch_state TEXT NOT NULL
        CHECK(typeof(dispatch_state) = 'text'
              AND dispatch_state IN ('prepared', 'dispatch_may_have_occurred', 'abandoned_before_dispatch'))
);

-- Deliberately excludes session, numeric row ID, revision, path, account, Space.
-- UUID case variants cannot gain a second active slot; decoding also requires
-- canonical UUID text and detects ambiguous/corrupt variants in history.
CREATE UNIQUE INDEX main.otzaria_local_editor_native_attempt_one_active
ON otzaria_local_editor_native_attempts(namespace COLLATE BINARY, annotation_uuid COLLATE NOCASE)
WHERE dispatch_state IN ('prepared', 'dispatch_may_have_occurred');

-- Full saved version namespace/annotation_uuid are the row's fixed/common fields.
-- Full saved version sourceDigest equals source_digest, checked against actual
-- current source, original version, decoded envelope, and frozen source bytes.
-- Exact body bytes remain inside unchanged payload_base64.
-- No native object ID, outbox message, identity result, ACK, foreign store or
-- copied transport queue is created. No FK alters original ledger dependencies.
