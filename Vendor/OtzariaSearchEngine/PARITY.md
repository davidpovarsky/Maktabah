# Otzaria Desktop parity notes

Last verified: 2026-08-25.

Maktabah remains pinned to `Otzaria/otzaria_search_engine` commit
`265a14ea54f959a3e266d6e8acfa3a3b98101d68`, index schema 4. The `refactor`
branch was seven commits ahead at verification time. Its Rust search diff adds
an opt-in economy writer mode and generated binding changes; it does not bump
the index schema or change query interpretation. Maktabah therefore does not
upgrade automatically or rebuild the already-published Otzaria v22 index.

The current `Sivan22/otzaria` desktop `main` pins the older
`Sivan22/otzaria_search_engine` commit
`01b49f69b8475f673cd1db13128a482963d4bf7d`. It is a different historical
fork, so commit equality is not a meaningful parity assertion. Behavioral
parity is recorded instead.

The prebuilt acceptance runner always executes the golden query
`לחתוך צנון בסכין בשרי` in advanced/relevance mode and records:

- normalized query;
- ordered result IDs and stable source IDs;
- references;
- whether the top page contains upstream highlight markup.

The Zayit production workflow writes the corresponding ordered JSON response
to `zayit-production-golden.json`. These reports are diagnostics artifacts,
not a brittle snapshot of the complete corpus. A Desktop export for the same
query can be compared to them explicitly when updating a golden fixture.

Semantic/hybrid search is intentionally unavailable in the product until a
model, persisted vector artifact, and inference backend are all ready.
