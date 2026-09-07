# Key Fields and Identifiers Contract

**Contract version:** `1.0.0-draft.1`

**Document date:** 2026-09-07

**Status:** Draft for adoption. Applies prospectively to newly assigned project identifiers; existing identifiers require explicit migration rather than automatic rewriting.

**Implementation status:** This is a specification. The [workbook compliance suite](../docs/Dataset%20Compliance.md) validates declared identifier profiles and available assignment, alias, and lineage evidence, with unassessed conditions reported explicitly. It does not allocate or rewrite identifiers. The standalone toponym utility carries input identifiers into its output; it does not enforce these rules.

## Purpose and scope

An identifier connects a scientific entity or record to its observations, physical labels, source data, derived products, and external processing history. It MUST remain stable, unambiguous within its declared scope, and faithfully preserved across those representations.

This contract governs the assignment, storage, exchange, and interpretation of project identifiers for sites, collection events, samples, specimens, subsamples, pools, and records. It distinguishes the **key field** (for example `sample_id`) from the **identifier value** stored in that field (for example `SN26_00001`).

It complements the [Workbook Datasets — Source-of-Truth Contract](Workbook%20Datasets%20%E2%80%94%20Source-of-Truth%20Contract.md), which governs table keys and raw-data extraction, and the [Toponymy Reference Contract](Toponymy%20Reference%20Contract.md), which distinguishes project identity from geographical reference anchors. It does not require rebuilding workbook relationships as a relational database.

Here **MUST** expresses a requirement, **SHOULD** a default with documented exceptions, and **MAY** an allowed choice. Examples are illustrative, not issued identifiers or a mandatory dataset schema.

## 1. Identity, keys, and uniqueness

Define what an identifier identifies before assigning it. A site, a visit to that site, a collected specimen, an aliquot, and an assay result are different objects even when related. Do not reuse a specimen ID to identify an independently tracked aliquot or use a site ID as the identity of every visit.

An **identifier namespace** is the declared scope within which one authority coordinates assignment and guarantees that a full identifier names only one entity. Record a stable namespace name and responsible curator/team. A country/year prefix alone does not guarantee uniqueness across unrelated projects, institutions, or entity classes.

Within a namespace:

- A full identifier MUST refer to one entity or record only and MUST NOT be reassigned after loss, consumption, cancellation, deletion, or retirement.
- Independent allocators MUST coordinate. Use a single allocator or documented non-overlapping allocations; do not restart the same serial range for each collector, worksheet, site, or entity class without a distinguishing namespace or prefix.
- Uniqueness checks MUST include previously issued and retired identifiers, not only the current export.
- A current row number, row position, sort order, or count of currently retained records MUST NOT serve as persistent identity.

Keep namespace information with exchanged data. Where independent namespaces can issue the same value, the identifying reference is **namespace + identifier**. Before physically mixing material or sending it to a shared provider, ensure labels and manifests distinguish those namespaces, either through a separately displayed namespace or a declared distinguishing ID segment. Never assume a bare `SN26_00001` is globally unique.

A repeated identifier is not necessarily a duplicate entity. Follow the workbook contract's `meta__tables` declaration:

| Key scope | Required interpretation |
| --- | --- |
| `row` | The key identifies one record and MUST be nonmissing and unique within that table. |
| `entity` | The key identifies an entity that may recur across observations. It MUST be nonmissing; legitimate repetitions are documented rather than rejected. |

Do not introduce synthetic row identifiers merely to remove legitimate repeated entity keys. When an observation itself needs independent tracking, give it its own declared record ID and retain the relevant entity ID separately. Identifier uniqueness is an assignment rule; table uniqueness depends on the declared key scope.

## 2. Text representation and field names

New project identifiers MUST be literal text, beginning with an ASCII letter. Use uppercase ASCII letters `A–Z`, decimal digits `0–9`, and single underscores between declared segments. Do not include whitespace, accents, punctuation other than underscore, or trailing/doubled underscores. Do not distinguish two identifiers only by letter case.

This contract uses “alphanumeric identifier” to include those explicit underscore separators. The general lexical form is:

```text
^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*$
```

This grammar is a first check, not proof of validity or uniqueness. Each adopted identifier profile MUST define its narrower layout, widths, permitted segments, and allocation scope.

The values' uppercase convention does not change the workbook naming rules: field names remain meaningful English `lower_snake_case`, normally ending in `_id` where appropriate. `sample_id` is a field name; `SN26_00001` is a value. Reserved worksheet/field prefixes such as `calc__` are not identifier segments.

Configure spreadsheet entry/import columns as text before values arrive, and configure programmatic readers to retain IDs as strings. An alphabetic prefix reduces numeric coercion risk but does not replace type checks. A display format, CSV quoting, or a leading apostrophe used by a spreadsheet UI is not a portable guarantee of the stored value. Verify that exports contain the exact identifier, without an extra literal apostrophe. Spreadsheet conversion can remove leading zeros or alter long numeric strings; see [Microsoft's guidance on identifier storage](https://support.microsoft.com/en-us/excel/keeping-leading-zeros-and-large-numbers).

Key cells MUST contain assigned literal identifiers, not formulas. Allocate identifiers through a controlled source register or allocation tool and record the issued strings; do not derive raw key cells with spreadsheet formulas or paste spreadsheet-calculated keys into raw fields. Assignment establishes identity; it must not depend on recalculation or row rearrangement.

## 3. Default field-collection profile

For newly identified field-collected items with known country and collection year, the default profile is:

```text
CCYY_NNNNN
SN26_00001
```

| Segment | Meaning |
| --- | --- |
| `CC` | Uppercase ISO 3166-1 alpha-2 code for the country of collection. |
| `YY` | Last two digits of the actual collection year, interpreted under a declared full-year range. |
| `_` | Fixed separator between provenance prefix and serial. |
| `NNNNN` | Illustrative five-digit serial, zero-padded to the profile's declared width. |

Use **ISO 3166-1 alpha-2**, not an internet-domain suffix as the authority for country codes. ISO defines the two-letter country-code system; the current assignments are available through its [country-code resources](https://www.iso.org/iso-3166-country-codes.html). Record the code-list reference or date used for assignment, and validate actual membership rather than accepting any two letters.

The country is the collection country, not the collector's nationality, funding institution, receiving laboratory, or current storage location. The year is the collection year, not the export, analysis, accession, or shipment year. Keep the full country and collection-date information in explicit metadata; the ID prefix is a compact assignment convention, not the authoritative observation record.

### 3.1 Width, capacity, and century

Choose the serial width before issuing labels, allowing for expected growth and concurrent allocations. A width of five accommodates `00001` through `99999` per allocated country/year prefix within the namespace; reserve `00000` as unissued. Gaps are acceptable and MUST NOT be closed by renumbering. Define equivalent capacity for other widths.

A base identifier has length `5 + serial_width`; the five-digit example has ten characters. Identifiers MUST have the declared fixed length **within the same profile and entity class**. This is not a requirement that every identifier column in the project, or every parent and child ID, have the same length.

If a register combines several profiles, retain the profile associated with each ID and validate it accordingly. Do not apply one field-wide length rule to an explicitly mixed-profile register.

Two year digits do not identify a century. A namespace using `YY` MUST declare a full-year range in which every suffix maps to at most one year, for example 2000–2099, and retain full collection years. Do not reuse an existing identifier when a century rolls over. If the material spans ambiguous centuries, choose a four-digit-year profile before assignment, such as `SN2026_00001`, and document its different width. Do not guess a century from the current date.

If capacity is exhausted, stop assignment under that profile and deliberately introduce a documented extension or new allocation scope. Do not wrap the counter, truncate serials, or silently widen previously issued identifiers.

### 3.2 Unknown provenance and other entity types

Do not invent a country or year to satisfy the default layout. Unknown, mixed-country, historical, non-terrestrial, or non-field material needs a documented alternative profile, with explicit provenance fields. `00` is not a missing-year code, and arbitrary letters MUST NOT be presented as assigned country codes.

Persistent sites, instruments, and laboratory-created objects MAY use a different profile when country/year-of-collection has no appropriate meaning. A revisited site keeps its site ID; each new collection event or collected item receives the applicable event/item ID. Subsamples inherit their parent's collection context; record the later subsampling or processing date separately.

A project MAY adopt additional fixed segments, such as an issuer or entity-class code, when needed to prevent collisions or support field practice. Define their meanings and widths once, before assignment. Avoid encoding mutable attributes such as a current taxonomic determination, place-name spelling, treatment result, or quality assessment.

## 4. Stability, corrections, and retirement

Once issued and used, an identifier MUST remain stable. Correct scientific metadata independently: a corrected collection date, country attribution, locality name, or classification does not automatically justify relabelling the entity. Record any resulting discrepancy between an assigned prefix and corrected metadata.

Distinguish a transcription error from a change of identity. Correct a mistyped value against the authoritative assignment record, retain an audit of the correction, and reconcile affected labels, files, and provider references. Do not infer the intended ID solely from the nearest spelling or automatically trim, uppercase, pad, or otherwise repair it during archival extraction.

If two different objects were accidentally assigned the same ID, quarantine the conflict from automatic matching and adjudicate it upstream. Retain the original identifier and enough context to distinguish the affected objects; a one-column old-to-new mapping is insufficient when one old value referred to several objects. Document replacement IDs, reason, date, and affected records. A duplicate row describing the same entity requires a different assessment from two entities sharing one assigned ID.

Retired, voided, missing, and consumed objects retain their identifiers and documented status. New material receives a new identifier, even when it replaces something lost or recollected.

## 5. Subsamples, disaggregation, and pools

A separately tracked physical child MUST receive its own identifier and an explicit parent reference. Repeated measurements on the same unchanged item may repeat its entity ID; they do not necessarily create new material identities.

For a child of one parent, prefer the parent ID followed by an underscore and a fixed-width child segment:

```text
SN26_00001       parent item
SN26_00001_A01   first aliquot
SN26_00001_A02   second aliquot
```

Here `A` means aliquot in this example profile, followed by a two-digit serial from `01` to `99` allocated once per parent and child type. Define the actual child types and widths before use. The child IDs in this example have fourteen characters. Do not mix points, hyphens, and underscores for newly issued child IDs.

Store `parent_id` and the relationship meaning explicitly. The suffix is a label aid, not the sole record of lineage. If multiple processing generations are tracked, either declare the depth and fixed layout of each child profile or issue a new standalone ID linked to the immediate parent. Do not grow undocumented suffix chains or assume every underscore introduces a parent.

When material is pooled from several parents, assign the pool a new ID and record each contributing parent separately. Use a small provenance table, for example:

```text
child_id   | parent_id  | relationship
POOL26_001 | SN26_00001 | pooled_from
POOL26_001 | SN26_00002 | pooled_from
```

`POOL26_001` is an example of a separately declared pool profile. Its namespace, year meaning, and serial width must be defined before issuance. Do not label the pool as though it had only one arbitrarily selected parent or concatenate a parent list into one key cell. A child taken from that pool links to the pool; original contributions remain recorded through the pool's provenance. Disaggregation does not establish which contributor an item came from unless that identity is independently known.

These relationship records preserve necessary lineage; they do not require every downstream archive to implement foreign keys or mandatory joins. Check references, self-parenting, and cycles when maintaining source lineage, and retain any required parent namespace when parents come from different assignment scopes.

## 6. Physical labels and external exchange

Use the exact canonical identifier on physical labels, in digital records, and on submissions to external services. Labels SHOULD include legible human-readable text; where a barcode or QR code is used, document its payload and verify that decoding preserves the exact identifier. Check readability, available label width, and survival under the intended storage/handling conditions before large-scale issuance.

Agree identifier handling with the receiving provider before shipment or upload. Check accepted characters, maximum length, case handling, truncation, and returned-file behaviour using representative labels. Do not silently replace underscores or remove leading zeros to satisfy a provider.

If a provider requires its own accession or alias, retain both identifiers and their mapping, including provider and namespace where needed. Do not replace the project ID with the provider's ID or reconcile returned results by row order. Check returned IDs against the submission manifest, including missing, unexpected, duplicated, or truncated values.

Avoid printed typography that makes different characters indistinguishable, and use scanning or independent reconciliation where transcription errors would break identity. A name or descriptive label MAY accompany the ID but MUST NOT substitute for it.

## 7. Minimal source-side documentation and allocation

Maintain one authoritative place for assignment rules and issued identifiers. An existing curated source table may serve as the register; do not create a second mutable inventory solely for this contract. Where assignment occurs separately from observations, keep a small allocation register recording the issued ID, namespace, identified entity, and lifecycle status, with enough audit information to resolve conflicts and reservations.

Document the following once per profile:

- namespace, curator/allocator, entity meaning, and participating projects or teams;
- profile identifier/version, grammar, segment meanings, widths, and capacity;
- country-code reference, full-year range, and serial allocation/reset scope where applicable;
- child profiles and lineage rules where applicable;
- treatment of legacy or external IDs and any provider aliases;
- adopted contract version and immutable contract revision once available.

In source workbooks, keep the key field and `row`/`entity` scope in `meta__tables`, as required by the workbook contract. Put profile/namespace declarations or their authoritative reference in `meta__readme`, and necessary field-specific interpretation in selective `meta__fields` entries. These declarations supplement the existing metadata; they are not a new exhaustive column schema.

For example, a coordinated collection might declare `field_items_v1`, namespace `mangrove_collection`, country/year prefixes using five-digit serials, full-year range 2000–2099, and one serial allocation across all participating teams for each country/year. The name `mangrove_collection` is illustrative; choose a stable namespace appropriate to the actual project.

## 8. Validation and acceptance

Validation MUST distinguish identifier syntax, assignment identity, and table cardinality. Matching a regular expression proves neither country-code validity nor uniqueness.

For the five-digit default base profile, the syntax check is:

```text
^[A-Z]{2}[0-9]{2}_[0-9]{5}$
```

For the example aliquot profile, it is:

```text
^[A-Z]{2}[0-9]{2}_[0-9]{5}_A[0-9]{2}$
```

In addition, check that:

1. Every required key is present, nonblank, stored as text, and matches its declared profile without hidden whitespace or formula values.
2. Country/year segments are meaningful under the assignment metadata; reserved zero serials and undeclared widths or segments are rejected.
3. Allocation records do not assign one full ID to multiple entities within a namespace; table uniqueness is checked only as required by `key_scope`.
4. Issued IDs survive source export, programmatic import, label generation, scanning, and provider round-trips exactly.
5. Parent/pool relationships and external aliases refer to the intended entities, and retired IDs are not recycled.

Example checks for the base/aliquot profiles above:

| Value or situation | Outcome |
| --- | --- |
| `SN26_00001` | Valid base syntax; still requires code, year, and assignment checks. |
| `SN26_00001_A01` | Valid aliquot syntax; requires a registered parent and child assignment. |
| `SN26_1` | Invalid width for the five-digit profile. |
| `sn26_00001` | Invalid case for newly issued IDs under this profile. Preserve it unchanged if it is a documented legacy identifier. |
| `SN26_00000` | Reserved unissued serial; not an assigned item. |
| `SN26_00001_A00` | Reserved unissued child serial. |
| `SN26_00001-A01` | Invalid separator for the new child profile. |
| Two assay rows with the same valid `sample_id` and `key_scope = entity` | Potentially legitimate repeated observations, not an automatic duplicate-key error. |

Correct violations in the authoritative source or allocation record and retain evidence of changes. An extractor MUST report discrepancies rather than silently manufacture compliant-looking identities. Regex checks cannot certify that a physical label was attached to the correct specimen; assignment and handling controls remain necessary.

## 9. Adoption and legacy compatibility

Adopt a profile before new collection/label production and test representative end-to-end transfers. Record exceptions deliberately rather than adding ad hoc punctuation or varying widths as records arrive.

Existing identifiers, external accessions, controlled reference codes, and historical datasets MUST retain their exact values unless a documented migration is required. Do not retroactively prefix external codes with country/year, convert numeric-looking accessions, or pad old serials merely to match this default. A project-issued local identifier MAY accompany an external accession, with an explicit mapping.

The workspace's existing `SN15_S01G01` and `SN20_S01G01` inputs are examples of a different segmented identifier layout. This contract does not infer what `S` or `G` means, declare those data invalid, or authorise renumbering them. Document their original profile and preserve the strings.

For an intentional migration, retain original snapshots, define the new assignment scope, audit collisions and lineage, maintain a lossless old/new/context mapping, reconcile physical and external references, and record the effective date. Do not activate a new ID in analysis while labels or provider records still point ambiguously to the old one.

The exact identifier layout, uppercase convention, widths, serial rules, and child suffixes are project design choices. External sources cited above support country-code terminology and storage risks; they do not make this project scheme a global identifier standard. Once this draft is adopted and committed, pin its full Git commit in consuming manifests. A draft label alone does not identify the exact contract text.
