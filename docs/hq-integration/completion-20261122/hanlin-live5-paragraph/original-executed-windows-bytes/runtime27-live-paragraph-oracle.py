#!/usr/bin/env python3
"""Independent SQL identity for the fixed live fixture's default paragraph.

This is a read-only test oracle, not a reader implementation. Unsupported or
ambiguous TOC shapes fail before staging a credential. No UI value is an input.
"""


def require(condition, message):
    if not condition:
        raise ValueError(message)


def derive_live_paragraph(connection, book_id, requested_line):
    require(type(book_id) is int and type(requested_line) is int and book_id > 0 and requested_line >= 0,
            "Invalid original fixture book or source line")
    selected_sql = (
        "SELECT l.id,t.id,t.parentId,t.level FROM line l "
        "JOIN line_toc lt ON lt.lineId=l.id "
        "JOIN tocEntry t ON t.id=lt.tocEntryId AND t.bookId=l.bookId "
        "WHERE l.bookId=? AND l.lineIndex=? ORDER BY t.level DESC,t.id")
    selected = connection.execute(selected_sql, (book_id, requested_line)).fetchall()
    require(len(selected) == 1, "Live fixture requires one unambiguous paragraph mapping")
    line_id, entry_id, parent_id, level = selected[0]
    require(connection.execute("SELECT COUNT(*) FROM line_toc WHERE lineId=?", (line_id,)).fetchone()[0] == 1,
            "Ambiguous or foreign-book source-line TOC mapping")
    require(parent_id is not None and level > 0, "Live fixture selected a root title, not a paragraph")
    require(connection.execute("SELECT COUNT(*) FROM tocEntry WHERE parentId=?", (entry_id,)).fetchone()[0] == 0,
            "Live fixture selected a non-leaf TOC entry")
    parent = connection.execute("SELECT parentId,bookId FROM tocEntry WHERE id=?", (parent_id,)).fetchone()
    require(parent is not None and parent[0] is None and parent[1] == book_id,
            "Live fixture requires the original paragraph's exact book root")
    membership_sql = (
        "SELECT l.id,l.lineIndex,(SELECT COUNT(*) FROM line_toc other WHERE other.lineId=l.id) "
        "FROM line l JOIN line_toc lt ON lt.lineId=l.id "
        "WHERE l.bookId=? AND lt.tocEntryId=? ORDER BY l.lineIndex")
    membership = connection.execute(membership_sql, (book_id, entry_id)).fetchall()
    indices = [row[1] for row in membership]
    require(bool(indices) and len(set(indices)) == len(indices) and requested_line in indices
            and all(row[2] == 1 for row in membership), "Ambiguous paragraph membership")
    # Original paragraph mode attaches a short book title only to its first
    # child unit. Prove this selected paragraph follows another mapped sibling,
    # with any root title preceding that sibling; no product algorithm is copied.
    preceding_sql = (
        "SELECT MIN(l.lineIndex) FROM line l JOIN line_toc lt ON lt.lineId=l.id "
        "JOIN tocEntry t ON t.id=lt.tocEntryId AND t.bookId=l.bookId "
        "WHERE l.bookId=? AND t.parentId=? AND t.id<>?")
    preceding = connection.execute(preceding_sql, (book_id, parent_id, entry_id)).fetchone()[0]
    require(preceding is not None and preceding < indices[0],
            "Live fixture cannot independently exclude first-unit root-title attachment")
    root_last = connection.execute(
        "SELECT MAX(l.lineIndex) FROM line l JOIN line_toc lt ON lt.lineId=l.id "
        "WHERE l.bookId=? AND lt.tocEntryId=?", (book_id, parent_id)).fetchone()[0]
    require(root_last is None or root_last < preceding, "Unexpected interleaved book-root title")
    return {
        "mode": "paragraph", "book_id": book_id, "requested_line_index": requested_line,
        "toc_entry_id": entry_id, "parent_toc_entry_id": parent_id,
        "source_line_indices": indices, "start_line_index": indices[0], "end_line_index": indices[-1],
        "canonical_locator": f"otzaria|book:{book_id}|line:{indices[0]}",
        "preceding_sibling_line_index": preceding, "root_last_line_index": root_last,
        "sql": {"selected": selected_sql, "membership": membership_sql, "preceding": preceding_sql},
        "ui_observation_used": False,
    }
