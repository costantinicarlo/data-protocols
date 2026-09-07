# Dataset compliance pipeline

The R compliance suite (`0.1.0`) ingests completed local downloads of a mutable source-of-truth XLSX or ODS workbook. Each invocation reads the download's bytes afresh, archives a SHA-256-addressed snapshot, validates source metadata and datasheets, and writes a versioned run directory. It never edits the server workbook or the downloaded file.

Only a complete, successful run updates `current.json`. A later invalid download retains its snapshot and diagnostics while the previous validated publication stays current. A changing filename is not a new source: use the same stable `workbook_id` across downloads of the same server workbook.

## Quick start

R 4.2 or later and these packages are required:

```sh
mkdir -p local/R-library
Rscript -e 'install.packages(c("jsonlite", "xml2", "digest"), lib="local/R-library", repos="https://cloud.r-project.org")'
```

Run the included sample workbook from the repository root:

```sh
R_LIBS_USER="$PWD/local/R-library" Rscript src/run_compliance.R \
  examples/compliance/collection.xlsx local/compliance-state \
  --source-id demo_collection --config config/compliance.example.json
```

The equivalent `examples/compliance/collection.ods` is also supplied. Both files are small synthetic source workbooks with metadata, original data, reference data, excluded calculated content, native dates, and decimal/sexagesimal coordinate examples. Their generator is `tests/make_workbook_fixtures.py`.

For a real download:

```sh
R_LIBS_USER="$PWD/local/R-library" Rscript src/run_compliance.R \
  inputs/collection.xlsx local/compliance-state \
  --source-id collection --config config/compliance.example.json
```

The source workbook's `meta__readme` must contain `workbook_id = collection`. Use the same command after replacing the local download with a newer completed export. Do not process a file while the browser, sync client, or download job is still writing it. Input size, mtime, and hashes before/after copying are checked to detect mutation during snapshot creation.

The suite does not connect to the source server, infer credentials, watch the filesystem, or schedule downloads. Invoke it after each completed download. Source workbook migration must happen upstream if its sheets and metadata do not yet follow the adopted workbook contract.

## Source metadata

Source metadata is authoritative for identity and semantics. The external JSON configuration controls execution, output serialization, optional reference inputs, and publication coverage requirements; it does not duplicate the workbook's key declarations or maintain a complete column whitelist.

Use `meta__readme` with `item`, `value`, and optionally `description`. The current machine profile requires these exact items:

| Item | Example / meaning |
| --- | --- |
| `workbook_id` | `demo_collection`; must equal `--source-id`. |
| `purpose` | Brief scientific purpose. |
| `curator` | Responsible person/team. |
| `source_reference` | Stable server workbook identifier or access-controlled link; no credentials. |
| `contract_version` | `2.0.0-draft.1`, the implemented workbook contract. |
| `locale` | Documented source locale, e.g. `en_US`; never inferred from the processing computer. |
| `timezone` | When needed, an IANA name, `UTC`, or explicitly `unknown`. |
| `identifier_profiles` | JSON object defining project, legacy, and external identifier profiles. |
| `default_identifier_profile` | Optional default profile name; override selectively for other keys. |
| `coordinate_crs` | Optional common source CRS, such as `EPSG:4326`. |
| `coordinate_decimal_mark` | Optional `.` or `,`; default `.` for automatic coordinate-field discovery. |
| `coordinate_fields` | Optional JSON object giving authoritative mappings per table. |
| `toponym_fields` | Optional JSON object selecting stored OSM reference fields for consistency checks. |

The first six names concretise the workbook contract's essential metadata. Their meanings must be correct; populating them mechanically with placeholders does not establish valid provenance.

`meta__tables` requires one row for every `data__` or `ref__` worksheet, with `sheet_name`, `key_field`, `key_scope`, and `record_unit`; `notes` documents expected repetitions. `key_scope` is `row` or `entity`. A `ref__` table remains a separately catalogued original table, not an automatic join target.

`meta__fields` is optional and selective. It requires `sheet_name` and `field_name`, with any of these additional columns as needed:

| Column | Supported declaration |
| --- | --- |
| `identifier_profile` | Name defined in `identifier_profiles`; used for the key or additional identifier fields. |
| `type` | `text`, `number`, `integer`, `boolean`, `date`, `datetime`, `time`, `duration`, or `partial_date`. |
| `required` | Literal `true` when blank observations violate the collection requirement. |
| `minimum`, `maximum` | Hard numeric bounds with scientific justification. |
| `unit` | Meaningful unit; required when numeric durations need interpretation. |
| `allowed_values` | JSON array of permitted literal values. |
| `ref_sheet`, `ref_field` | A retained field in a `ref__` worksheet supplying allowed values. |
| `missing_codes` | JSON array of documented legacy missing codes; retained verbatim, never silently replaced. |
| `timezone` | Field-specific timezone or `unknown`; overrides the workbook declaration. |

Do not add every ordinary column to `meta__fields`. Undeclared scientific units, scales, and bounds are reported as outside assessed coverage. Date/time suffixes and native spreadsheet temporal types identify temporal checks, but do not establish a timezone.

### Identifier profiles

Example `identifier_profiles` value (entered as one text value in `meta__readme`):

```json
{
  "field_items": {
    "type": "field_collection",
    "namespace": "collection_items",
    "serial_width": 5,
    "year_digits": 2,
    "year_range": [2000, 2099]
  },
  "sites_2020": {
    "type": "legacy",
    "namespace": "sites_2020",
    "pattern": "^SN20_S[0-9]{2}G[0-9]{2}$",
    "width": 11
  },
  "taxon_accessions": {
    "type": "external",
    "namespace": "provider_taxa",
    "pattern": "^[A-Za-z0-9_.-]+$"
  }
}
```

A `field_collection` profile implements country/year/serial semantics and rejects zero serials. It may include `child_pattern`, for example `"_A[0-9]{2}"`, to define an aliquot suffix. Other newly issued layouts use `type: "regex"` with an explicit pattern and optional fixed `width`; new project lexical rules still apply. Legacy/external profiles preserve their declared case and punctuation. They are explicit adoption choices, not automatic repairs.

The bundled `references/iso3166.tab` is the public-domain IANA time-zone distribution country table, dated 2025-07-01 with assignments referenced to 2024-02-29. Its bytes are fingerprinted in each manifest. It is an offline, pinned reference, not a claim of a live ISO lookup; historical or later code changes need a deliberately reviewed reference update.

Table row-key uniqueness is separate from namespace allocation uniqueness. Without an authoritative allocation register, the latter is `not_assessed`. The pipeline cannot prove that a reused physical label or undocumented reassignment did not occur. Retired identifiers may legitimately occur in historical observations.

### Coordinate mapping

Example `coordinate_fields` value:

```json
{
  "data__samples": {
    "latitude": "lat",
    "longitude": "lon",
    "crs": "EPSG:4326",
    "format": "auto",
    "decimal_mark": ".",
    "required": false,
    "display_digits": 5,
    "bounds": [-18, 12, -11, 17]
  }
}
```

`bounds` is optional and means west, south, east, north; it triggers review warnings, not automatic rejection or relocation. Accepted formats are `auto`, `dd`, `dm`, and `dms`. Automatic discovery recognises `latitude`, `lat`, `decimal_latitude`, `latitude_dd` and `longitude`, `lon`, `long`, `lng`, `decimal_longitude`, `longitude_dd`. Multiple candidates or missing partners block conversion; source mapping resolves the ambiguity.

Examples: `13.5`, `13.5 N`, `13° 30' 0" N`, `13:30:00 N`, and `16° 12' W`. A declared decimal comma permits `13,5`; it is rejected under the default decimal mark. Conflicting signs/hemispheres and out-of-range components remain errors. Bare unmarked sexagesimal components require `dm` or `dms` rather than guessing.

For a projected source, map `longitude` to x/easting and `latitude` to y/northing, and set the actual source CRS. Install `sf` to enable transformation:

```sh
Rscript -e 'install.packages("sf", lib="local/R-library", repos="https://cloud.r-project.org")'
```

The target is `OGC:CRS84` (WGS84 longitude/latitude). Transformations disallow ballpark approximations and fail if necessary support is unavailable. `sf` and its geospatial library versions are recorded when installed. Geographic formats can be converted without `sf`.

Derived tables contain source row/ID, original coordinate strings, full-precision decimal values, source/target CRS, method, and status. `display_digits` adds separate rounded display strings. Sampling positions are never replaced by OSM anchor positions.

## Configuration and reference evidence

`config/compliance.example.json` lists execution defaults. Accepted options are:

- `max_cells`: limit on occupied cells and logical rectangles (default one million).
- `missing_token`: CSV serialization token for genuine blanks (default `\N`). A literal collision blocks extraction; choose a different token rather than recoding a source value.
- `required_assessments`: check names that must have assessed/applicable coverage before publishing; absent or `not_assessed` checks block publication. Examples include `identifier_profile`, `lineage`, and `assignment_uniqueness_and_retirement`.
- `references`: optional `registry`, `lineage`, and `aliases` entries. Each selects either `{"sheet":"ref__register"}` or `{"path":"register.csv"}`. Paths are relative to the configuration file. External reference files must be UTF-8 CSV; values are read as literal text. Files are retained byte-for-byte in each run and hashed for build invalidation.
- `enrich_toponyms`: default false; explicitly opts into network geocoding.
- `geocoding_delay`: default 15.1 seconds; recurring enrichment requires at least 15 seconds between uncached Nominatim requests.

Registry columns: `namespace,identifier,entity_reference,status`. Alias columns: `provider,external_id,namespace,identifier`. Lineage columns: `namespace,child_id,parent_id,relationship`, optionally `parent_namespace`. Multiple pool parents are valid. Missing references, self-parenting, cycles, duplicate allocations, and conflicting provider mappings produce findings. The register remains authoritative; observation exports are not mistaken for an allocation ledger. When a previous validated register exists, changed entity assignments or removed historical identifiers block publication.

## Scripts and stages

All entry points accept the same workbook/state/source/config arguments as `run_compliance.R`:

| Script | Assessment |
| --- | --- |
| `snapshot_source.R` | Retain and fingerprint a completed local download. |
| `inspect_dataset.R` | Read stored workbook evidence and inspect structure/metadata. |
| `validate_workbook.R` | Validate structure, worksheet roles, formulas, and essential metadata. |
| `validate_identifiers.R` | Structure plus identifier and supplied assignment/alias checks. |
| `validate_lineage.R` | Structure, identifier checks, and supplied lineage checks. |
| `validate_values.R` | Structure plus declared value/code/unit-bound checks. |
| `validate_temporal_fields.R` | Structure plus temporal validation and native-time serialization. |
| `validate_coordinates.R`, `standardize_coordinates.R` | Structure plus coordinate checks and derived conversion candidates. |
| `validate_toponymy.R` | Structure plus explicitly mapped stored OSM reference checks. |
| `extract_original_tables.R`, `build_compliance_report.R` | Complete assessment and eligible extraction, without changing the publication pointer. |
| `run_compliance.R` | Complete assessment, extraction, reporting, and validated publication. |

Each stage invocation creates a new auditable run and snapshots the input; a stage is not an in-place mutation of a previous run. Only the full runner updates `current.json`. It is safe to inspect stage outputs, but `assessed_stage_only` is not a validated full build.

## History, evidence, and publication

```text
STATE_DIR/WORKBOOK_ID/
  snapshots/SHA256/source.xlsx        (or source.ods)
  runs/RUN_ID/
    manifest.json
    inventory.json
    changes.json
    findings.json
    coverage.json
    correction_proposals.json
    report.md
    table_evidence.rds
    cell_evidence/sheet_001.csv
    original/data__samples.csv
    original/ref__codes.csv
    documentation/meta__readme.csv
    derived/data__samples__coordinates.csv
  latest_attempt.json
  current.json
  geocoding/.osm_toponym_cache/       (only with optional enrichment)
```

Successful original/reference extraction retains headers, order, identifiers, literal text, named all-missing variables, and real records with missing observations. Native spreadsheet dates are serialised as ISO dates; explicit native clock fields are serialised as clocks. Formula/error evidence is preserved, not evaluated. Excluded calculated columns/sheets are inventoried and remain in the snapshot. Styled empty grid cells do not create observations; occupied formula-only prefill does.

`changes.json` compares the latest attempt's inventory with the previous attempt: added/removed sheets and fields, field order, row counts, content changes, and key-definition changes. Where both versions have unambiguous row keys, it also reports added, removed, and modified record IDs. Repeated entity keys are not matched by arbitrary row order. The last validated run is separately identified in the manifest.

Every invocation recomputes the source digest. The build signature also includes source-code and contract file hashes, available last-modifying Git commits, execution configuration, reference files, R/package versions, and stage. Uncommitted code is therefore distinguished by its content hash. Unchanged inputs are recognised but still assessed into a new run; there is no reuse of stale validation success. New source bytes, relevant code/configuration/contracts, or reference data change the signature. Explicit live OSM refreshes additionally require cache management because upstream API state is not fixed by Git.

`current.json` is a small atomically replaced pointer to a completed, coherent validated run. Consumers should resolve that pointer and verify the referenced manifest's `status`; directory existence alone is not proof of publication. Do not mix files from different run directories. Manifests include SHA-256 digests of generated artifacts. The snapshots/runs are retained as evidence and are not automatically pruned.

A per-source lock prevents concurrent publications from competing processes. After an interrupted process, inspect its state before manually removing an abandoned `.lock` directory. Locks are not silently broken based on time.

Exit codes: `0` for a successful full run or completed named stage; `2` for an assessed run with validation/processing errors; `1` for invocation, setup, or snapshot acquisition failure. Findings carry severity separately from coverage (`assessed`, `not_assessed`, `not_applicable`). Warnings remain visible; required missing evidence can be made publication-blocking through configuration.

## Optional OSM enrichment

Stored OSM references are checked only when selected through `toponym_fields`, for example:

```json
{"data__localities":{"name":"name","osm_type":"osm_type","osm_id":"osm_id","status":"status"}}
```

For new enrichment, use `--enrich-toponyms` on a full run (and install `httr2` if needed). It invokes the existing toponym engine only after validation succeeds, uses the standardised sampling coordinates, preserves original entity IDs and source row references, and writes separate GeoJSON artifacts. It does not alter reviewed source names. Ambiguous/fallback matches generate review warnings; unresolved records or service denials block publication of the requested enriched build.

Read and comply with the [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/). This workflow is recurring bulk use: the integration enforces a delay of at least 15 seconds and retains API caches across workbook downloads. Service availability is not a condition for ordinary offline validation. Confidential coordinates must not be submitted to a public service.

## Supported evidence and limits

The adapters read OOXML/ODF cell values and formula records directly, including shared/inline XLSX strings, 1900/1904 date systems, and repeated ODS rows/cells. They do not run spreadsheet software or formulas. Unsupported cell types, package structures, oversized content, or damaged XML stop validation rather than being guessed. XLSX style evidence and ODS typed values support temporal interpretation; selective metadata resolves ambiguous clock/duration meanings. XLSX's fictitious 1900-02-29 and hidden fractions in a date-only cell are rejected.

This implementation targets ordinary rectangular XLSX/ODS datasheets and the source metadata above. It does not promise support for every spreadsheet feature, encrypted workbooks, embedded objects, nested ODS tables, or arbitrary vendor extensions. Before adopting a real server export, compare representative raw values, cell types, names, and dimensions against source evidence. Repeat that acceptance check after exporter/reader changes. Merely opening the file successfully is insufficient.

Colour-only meanings, pasted-formula history, actual field positioning accuracy, material identity, and undocumented provider transformations cannot be certified from a workbook. They appear as missing coverage where applicable. Unusual observations are not automatically censored. Automatic transformations produce derived data or explicit serialization; correction proposals are instructions for upstream adjudication, not edits to the source of truth.

## Verification

```sh
R_LIBS_USER="$PWD/local/R-library" Rscript tests/test_compliance.R
R_LIBS_USER="$PWD/local/R-library" Rscript tests/test_osm_toponym.R
```

The workbook tests also require `httr2` for the optional enrichment integration check. They use Python 3's standard library to generate deterministic packages, then run the R readers and pipeline. They exercise XLSX/ODS equivalence, shared strings, formulas/errors, text/Unicode, both Excel date systems, clocks/durations, empty tables, identifier profiles, duplicate versus entity keys, coordinate ambiguity, mutation history, config invalidation, failed-publication preservation, register reassignment, and lineage cycles. Cached OSM responses exercise enrichment without public requests. Projected-CRS transformation requires separate acceptance testing with `sf` and representative source coordinates.

Format references: [Microsoft's OOXML cell-value documentation](https://learn.microsoft.com/en-us/office/open-xml/spreadsheet/how-to-retrieve-the-values-of-cells-in-a-spreadsheet), the [OpenDocument specifications](https://www.oasis-open.org/standard/opendocumentv1-3/), and [RFC 7946](https://www.rfc-editor.org/rfc/rfc7946.html). Source contract rules, rather than these format specifications alone, determine what is publishable.
