# Resolver lane discoveries

- [x] Never sort qualified identity components by a delimiter-joined string. It changes prefix order and permits collisions when opaque work keys/revisions contain that delimiter. Resolver now compares typed components and retains a regression fixture.
- [x] Candidate caps and ambiguity are different facts: a returned page of one candidate must remain ambiguous when the complete bounded catalog contained multiple qualified matches.
- [ ] Source adapters must prove Embedded ref existence against actual catalog/section data; a trim/echo normalizer cannot fulfill validate. Native/full-source integration acceptance remains separate from portable resolver fixtures.
