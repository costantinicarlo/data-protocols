<img src="assets/branding/data-protocols-hex.png" alt="Data Protocols hex logo" width="200">

# Data Standard Operating Protocols

Shared conventions for reproducible scientific data curation and geographical references, with an R utility for resolving coordinates against OpenStreetMap (OSM).

## Current status

The toponym utility reports generator version `1.1.2` and combines Nominatim reverse geocoding with Overpass place-node matching and disk caching. The workbook contract is `2.0.0-draft.1` (2026-09-07), proposed for review and adoption. The new workbook compliance suite (`0.1.0`) preserves XLSX/ODS downloads, validates their datasheets, derives decimal-degree coordinates, compares successive snapshots, and publishes coherent validated builds. The toponymy contract has no declared semantic version.

The [Key Fields and Identifiers Contract](contracts/Key%20Fields%20and%20Identifiers%20Contract.md) is a `1.0.0-draft.1` specification for identifier assignment, text representation, uniqueness, lineage, and exchange. The suite validates declared profiles and available register/lineage evidence; it does not allocate or rewrite identifiers. The new [Geographical Coordinates Contract](contracts/Geographical%20Coordinates%20Contract.md) defines conversion, CRS, preservation, and precision requirements.

See [Dataset Compliance](docs/Dataset%20Compliance.md) for the mutable-workbook workflow, source metadata, individual scripts, coverage limits, and runnable XLSX/ODS examples. Run a completed download with:

```sh
R_LIBS_USER="$PWD/local/R-library" Rscript src/run_compliance.R \
  inputs/collection.xlsx local/compliance-state --source-id collection \
  --config config/compliance.example.json
```

The workbook's `workbook_id` must match `--source-id`. Install `jsonlite`, `xml2`, and `digest` as described in the guide. Each downloaded revision is retained; failed checks leave the last validated publication unchanged. Network geocoding is optional.

Use the immutable Git revisions below for pre-release review. Remote HEAD/tags and releases were checked on 2026-09-08: no tags or releases were present. These new pins exist locally only and have not been pushed. A generator version or draft contract label alone does not identify exact file contents.

## Pinning source code and contracts

The following full commit IDs identify the current committed source and contracts, verified locally on 2026-09-08. The compliance suite pin includes its runtime, configuration, country-code reference, sample workbooks, and offline regression tests. Use the shared checkout below to obtain its contracts and usage guide as well. The corrected standalone toponym utility is version `1.1.2`.

| Component | Path | Commit to pin |
| --- | --- | --- |
| Toponym utility (`1.1.2`) | `src/osm_toponym.R` | `4270181a45d1cc4f82d44bf281989f96985878be` |
| Workbook compliance suite (`0.1.0`) | `src/run_compliance.R`, `src/compliance/`, stage scripts and supporting files | `4270181a45d1cc4f82d44bf281989f96985878be` |
| Toponymy Reference Contract (unversioned) | `contracts/Toponymy Reference Contract.md` | `4270181a45d1cc4f82d44bf281989f96985878be` |
| Workbook contract (`2.0.0-draft.1`) | `contracts/Workbook Datasets — Source-of-Truth Contract.md` | `4270181a45d1cc4f82d44bf281989f96985878be` |
| Key Fields and Identifiers Contract (`1.0.0-draft.1`) | `contracts/Key Fields and Identifiers Contract.md` | `4270181a45d1cc4f82d44bf281989f96985878be` |
| Geographical Coordinates Contract (`1.0.0-draft.1`) | `contracts/Geographical Coordinates Contract.md` | `4270181a45d1cc4f82d44bf281989f96985878be` |

These are **Git commit IDs**, not file checksums. All six components were modified in the same implementation commit. The subsequent report/pin documentation commit does not change their bytes. For a single checkout containing all six components listed above, pin **`4270181a45d1cc4f82d44bf281989f96985878be`**. It includes the compliance suite, all four contracts, and the usage guide. Each listed component is byte-for-byte identical to its component pin above.

Example YAML for a consuming repository's manifest (illustrative keys; adapt to its manifest schema):

```yaml
data_protocols:
  repository: "<repository-clone-url>"
  revision: "4270181a45d1cc4f82d44bf281989f96985878be"
  source:
    path: "src/osm_toponym.R"
    revision: "4270181a45d1cc4f82d44bf281989f96985878be"
    generator_version: "1.1.2"
  workbook_compliance:
    entry_point: "src/run_compliance.R"
    modules: "src/compliance/"
    reference_data: "references/"
    revision: "4270181a45d1cc4f82d44bf281989f96985878be"
    pipeline_version: "0.1.0"
  contracts:
    toponymy:
      path: "contracts/Toponymy Reference Contract.md"
      revision: "4270181a45d1cc4f82d44bf281989f96985878be"
    workbook_datasets:
      path: "contracts/Workbook Datasets — Source-of-Truth Contract.md"
      revision: "4270181a45d1cc4f82d44bf281989f96985878be"
      contract_version: "2.0.0-draft.1"
    key_fields:
      path: "contracts/Key Fields and Identifiers Contract.md"
      revision: "4270181a45d1cc4f82d44bf281989f96985878be"
      contract_version: "1.0.0-draft.1"
    geographical_coordinates:
      path: "contracts/Geographical Coordinates Contract.md"
      revision: "4270181a45d1cc4f82d44bf281989f96985878be"
      contract_version: "1.0.0-draft.1"
```

Replace `<repository-clone-url>` with the actual accessible repository location. Verify that pinned commits are available from the repository used by consumers. The hardening branch and its new pins are local until separately authorised for push.

After cloning, select and verify the shared snapshot:

```sh
git -C path/to/data-protocols checkout --detach 4270181a45d1cc4f82d44bf281989f96985878be
git -C path/to/data-protocols rev-parse HEAD
git -C path/to/data-protocols diff --exit-code HEAD -- src/ contracts/ references/ config/
```

Use full hashes in manifests rather than a moving branch name or `HEAD`. These pins identify the source and contracts, not future README edits. Advance them only after the relevant changes are committed and reviewed. To obtain the latest modifying commits in a later checkout:

```sh
git log -1 --format=%H -- src/osm_toponym.R
git log -1 --format=%H -- 'contracts/Toponymy Reference Contract.md'
git log -1 --format=%H -- 'contracts/Workbook Datasets — Source-of-Truth Contract.md'
git log -1 --format=%H -- 'contracts/Key Fields and Identifiers Contract.md'
git log -1 --format=%H -- 'contracts/Geographical Coordinates Contract.md'
git log -1 --format=%H -- src/ references/ config/compliance.example.json
```

Record local configuration edits or patches separately from the upstream revision. Pinning this repository does not pin R dependencies or the changing OSM services; retain dependency versions, API caches, input/output digests, and run provenance when reproducibility requires them. The GeoJSON includes `generator_version`, but the script does not automatically embed these Git revisions.

## Repository contents

| Path | Purpose |
| --- | --- |
| [Toponymy Reference Contract](contracts/Toponymy%20Reference%20Contract.md) | OSM reference conventions for geographical identity, names, discrepancies, and provenance. |
| [Workbook Datasets — Source-of-Truth Contract](contracts/Workbook%20Datasets%20%E2%80%94%20Source-of-Truth%20Contract.md) | Draft conventions for source workbooks, worksheet roles, raw/calculated fields, keys, metadata, and extraction. |
| [Key Fields and Identifiers Contract](contracts/Key%20Fields%20and%20Identifiers%20Contract.md) | Draft rules for stable text IDs, country/year profiles, assignment scope, fixed widths, child/pool lineage, labels, provider mappings, and legacy compatibility. |
| [Geographical Coordinates Contract](contracts/Geographical%20Coordinates%20Contract.md) | Draft coordinate representation, CRS, conversion, precision, and provenance requirements. |
| [Dataset Compliance](docs/Dataset%20Compliance.md) | Workbook ingestion, validation, history, publication, and configuration guide. |
| [src/run_compliance.R](src/run_compliance.R) | Full XLSX/ODS compliance runner; individual stage scripts share modules in `src/compliance/`. |
| [Example XLSX](examples/compliance/collection.xlsx) / [Example ODS](examples/compliance/collection.ods) | Equivalent synthetic source workbooks containing metadata and datasheets. |
| [config/compliance.example.json](config/compliance.example.json) | Execution settings and optional reference-evidence configuration. |
| [src/osm_toponym.R](src/osm_toponym.R) | CSV-to-GeoJSON command-line utility using Nominatim and Overpass. |
| [examples/example_toponym.json](examples/example_toponym.json) | Illustrative single Feature with placeholder reference data, not a verified lookup. |
| [examples/input_data.normalized.csv](examples/input_data.normalized.csv) | One-site input with the required `id,latitude,longitude` columns. |
| [examples/input_data.toponyms.geojson](examples/input_data.toponyms.geojson) | Earlier lookup output for that example; predates the current status/provenance schema and contains an escaped attribution artifact. |
| [data-protocols.code-workspace](data-protocols.code-workspace) | VS Code workspace opening this directory. |
| [tests/test_osm_toponym.R](tests/test_osm_toponym.R) | Offline regression checks for service denials, diagnostics, cache reuse, and CLI status handling. |

The contracts are the authoritative protocol text. Workbook-specific metadata belongs in the source workbook, especially `meta__readme` and `meta__tables`.

`inputs/`, `outputs/`, and `local/` are ignored working directories, not distributed datasets. Put authorised downloads and generated results in these working directories; they are not supplied by a fresh clone.

## Setup and execution

The script requires R 4.2 or later for its native pipe with a named `_` placeholder (see the [R pipe documentation](https://stat.ethz.ch/R-manual/R-patched/RHOME/library/base/html/pipeOp.html) and [R 4.2 release announcement](https://stat.ethz.ch/pipermail/r-announce/2022/000683.html)). Install `httr2` and `jsonlite`; dependency versions are not locked. Use a UTF-8 locale to preserve geographical names and attribution.

From the repository root, install into an ignored local library:

```sh
mkdir -p local/R-library inputs outputs
Rscript -e 'install.packages(c("httr2", "jsonlite"), lib="local/R-library", repos="https://cloud.r-project.org")'
```

The script sends an identifying `data-protocols/osm_toponym/1.1.2` User-Agent by default. Set `OSM_CONTACT_EMAIL` to append a real project contact, or `OSM_USER_AGENT` to supply your own identifying application string. Empty or known placeholder User-Agents are rejected before processing. No fictitious contact is sent by default. Review `NOMINATIM_URL`, `OVERPASS_URL`, `NOMINATIM_ZOOM` (15), `NOMINATIM_DELAY` (1.10 seconds), `PLACE_NODE_RADIUS_M` (5,000 metres), and `PLACE_TYPES`. These service/search settings remain script constants, not environment-variable or command-line options. Keep any local configuration changes in downstream provenance when using a pinned upstream revision.

The CSV must contain `id`, `latitude`, and `longitude`; additional fields are not copied to the output. Coordinates are decimal degrees, with latitude in [-90, 90] and longitude in [-180, 180]. Missing/non-finite coordinates stop the batch. Input columns are read as UTF-8 character strings with no implicit missing tokens. IDs such as `00017`, long digit strings, `NA`, `N/A`, `NULL`, and nonblank Unicode or whitespace-bearing IDs remain exact. Duplicate IDs and row order are retained. Blank/whitespace-only IDs, malformed headers/record widths, and invalid coordinates are rejected for the entire input before requests or output replacement. This general-purpose resolver does not impose the new project-ID grammar.

Run the tracked one-site example from `local/`, so the script's relative cache directory stays inside an ignored directory:

```sh
(
  cd local
  R_LIBS_USER="$PWD/R-library" Rscript ../src/osm_toponym.R \
    ../examples/input_data.normalized.csv ../outputs/input_data.toponyms.geojson
)
```

For the existing local 2015 batch:

```sh
(
  cd local
  R_LIBS_USER="$PWD/R-library" Rscript ../src/osm_toponym.R \
    ../inputs/sites_2015.csv ../outputs/sites_2015.toponyms.geojson
)
```

The script requires exactly two positional arguments: input CSV and output GeoJSON. It creates cache directories, but not the output's parent directory. It overwrites the requested output after the batch completes and prints a resolution summary. Exit status is `0` when no records are unresolved, `2` when the written output contains unresolved records, and `1` for a fatal error or invalid invocation. Ambiguous and fallback records still need review even after exit status `0`.

## Resolution and output

Nominatim provides the initial geographical context. If it returns a node whose category is `place`, the script accepts it directly. Otherwise, Overpass searches for named nodes within 5 km with `place` equal to `city`, `town`, `village`, `hamlet`, `isolated_dwelling`, or `locality`. Names and alternatives are normalised for matching; output retains the chosen OSM spelling. Exactly one matching node is selected; proximity alone does not resolve multiple matching nodes.

| Status | Meaning |
| --- | --- |
| `node_exact` | Nominatim returned a place node, or Overpass found exactly one name-compatible place node. This is an automated classification, not human verification. |
| `osm_fallback` | No matching place node was established; the original Nominatim object is retained. |
| `ambiguous` | Multiple name-compatible nodes exist; the original Nominatim object is retained with candidates for review. |
| `unresolved` | A caught nonfatal error prevented resolution, including exhausted transient Overpass failures. Access denials stop the entire batch instead. |

The output is a GeoJSON `FeatureCollection` with attribution, generator/version, UTC generation time, and one Feature per input row. Resolved Features retain the source ID, canonical name and OSM reference, status and method, country/place context, original query coordinates, original Nominatim object references, and candidate-node summaries. Distance to the anchor is populated for selected place nodes.

Point geometry uses **longitude, latitude** for the canonical OSM anchor, which may differ from the sampling coordinate. Unresolved records use the query point. The `verified` field records the run date, including when cached responses are reused; it is not a cache retrieval date or a certificate of human review. Review the output against the Toponymy Reference Contract before adopting names.

## Caching and service use

Successful API responses are cached under `.osm_toponym_cache/nominatim/` and `.osm_toponym_cache/overpass/`, relative to the process working directory. The commands above therefore use `local/.osm_toponym_cache/`. `.osm_toponym_cache/` is ignored at every repository depth, including the root; existing evidence is never deleted by the hardening migration.

Rerunning reuses validated successful cached responses and retries requests whose responses were not cached; it rebuilds the output rather than resuming a partial GeoJSON file. Nominatim cache keys include coordinates and zoom; Overpass keys include coordinates and radius. Keys do not include service URLs, the accepted place-type list, or cache age. Preserve caches for reproducibility, and use a separate cache when changing those assumptions or deliberately refreshing source data. Earlier local Feature caches are not interchangeable with this version's full-response JSON caches.

**Read the [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/) before submitting coordinates.** The public service requires application identification, attribution, caching for bulk work, and at most one request per second. Small one-time bulk jobs must use one thread on one machine; recurring jobs and jobs lasting longer than a day are restricted to four requests per minute. The standalone one-off default spaces actual Nominatim attempts by at least 1.10 seconds, including retries. Recurring compliance enrichment defaults to 15.1 seconds and rejects settings below 15 seconds. The standalone default is unsuitable for recurring jobs or jobs lasting longer than a day; set an appropriate interval or use your own service. One limiter covers successive records and tables within one resolver workflow; it does not coordinate independent processes. Do not submit confidential material. Select suitable services and rate limits for the intended workload.

## HTTP failures and diagnosis

An HTTP 403 means the service denied the request; it does not mean that coordinates are invalid or a locality is absent. The original local `sites_2020.toponyms.geojson` had 48 unresolved records with the same 403 and no service context. The old script sent a placeholder contact, continued across all rows, embedded terminal formatting in JSON messages, and exited successfully despite every lookup failing. That output alone cannot establish whether the service rejected the identification, the network/IP, or another access condition.

Historical execution note (reported before this hardening pass, not rerun as release evidence): the patched CLI was rerun on the same 48-site input on 2026-09-07: all 48 records resolved as `node_exact`, with IDs, order, and query coordinates verified. The original failure file is preserved locally as `local/sites_2020.before-fix.geojson`. The successful rerun supports application identification as a likely cause, but the original response details are insufficient to prove it.

Since version `1.1.1`, the utility identifies Nominatim versus Overpass in errors and includes a bounded plain-text excerpt of the server response. HTTP 401/403 stops immediately; exhausted HTTP 429 retries also stop the batch. Existing output remains unchanged and completed responses remain cached. Correct the access/configuration problem before rerunning; repeatedly retrying a denied service will not fix it.

Requests have a timeout of at most 30 seconds and at most four attempts within a 120-second budget. An explicit attempt loop disables nested httr2 retries and redirects. Transient HTTP 429/500/502/503/504 and transport failures are eligible for retries. The longest of the per-service interval, exponential backoff, and valid `Retry-After` seconds or HTTP-date controls each wait, including across records. If the safe wait exceeds the remaining budget, no early retry is attempted. Cache hits consume no request quota. Permanent 401/403 responses are not retried. Other exhausted failures are recorded as unresolved with plain-text messages and cause CLI exit status `2`.

## Validation and maintenance

Historical execution note (not current acceptance evidence): the local 2015 run on 2026-09-07 produced 78 records, all classified `node_exact`: 72 used Nominatim place nodes directly and six used Overpass matching. Input IDs, order, and query coordinates were checked. One HTTP 504 recovered on a cached rerun. Execution used a local copy with the placeholder User-Agent replaced; the tracked source was unchanged. This run checks execution and output structure, not the scientific correctness of every match.

Run the offline regression checks from the repository root:

```sh
R_LIBS_USER="$PWD/local/R-library" Rscript tests/run_all.R
```

The toponym checks intercept HTTP requests and use temporary caches; they do not call public services. They cover Nominatim/Overpass access denials, preserving existing outputs, diagnostic formatting, retry classification, cache reuse, and incomplete-run exit status. Run the workbook suite separately with `R_LIBS_USER="$PWD/local/R-library" Rscript tests/test_compliance.R`; it generates XLSX/ODS fixtures and verifies validation and mutable-download publication behaviour. There is no R package manifest or dependency lockfile. The tracked toponym example output predates version 1.1.0 and is not a current regression fixture. When changing either suite, validate with controlled fixtures before live service requests. When changing contracts, keep their status/version explicit and update downstream pins after adoption.

Keep source, contracts, and curated examples under version control. The `.gitignore` excludes OS metadata, R session state, editor/spreadsheet temporary files, local environment files, and the three working directories. CSV, JSON, GeoJSON, and workbook formats are not ignored globally.

## Release candidate hardening

Repository/compliance `0.1.0` remains an unreleased candidate; generator `1.1.2` is a separate utility version. Contract draft versions are unchanged because these fixes enforce their existing invariants. See the [release-readiness report](docs/Release%20Readiness.md) for historical execution evidence, immutable component pins, subsequent licensing decisions, and exporter acceptance requirements. No release is authorised by a successful local test.

Overpass HTTP 200 is insufficient evidence of success. Both fresh and cached responses need an object containing a valid `elements` array of well-formed candidate nodes. `elements: []` is a completed empty search; an absent/null/object-valued array is a failure. Every nonempty `remark` is conservatively rejected, including unrecognised remarks; no informational form is currently allowlisted. Partial candidates accompanied by a remark cannot establish uniqueness or a successful fallback. Such failures produce `unresolved` (standalone status `2`) and block requested enriched publication. Failed fresh responses never enter the success cache. Bounded diagnostic markers are saved under `.osm_toponym_cache/failures/`; old invalid cached bytes are moved there unchanged with a failure marker before a bounded retry. Successful cache/state layouts remain compatible.

Install all mandatory test dependencies (`jsonlite`, `xml2`, `digest`, `httr2`) and Python 3.10 or later, then run `Rscript tests/run_all.R`. It runs both existing suites plus declaration/parser/network regressions and fresh-process CLI/programmatic checks. All HTTP is mocked; unexpected requests fail. CI covers minimum R 4.2.3 and current release R on Linux, plus current release R on macOS, using read-only permissions and immutable Actions pins. Authoring that workflow is not evidence that remote CI passed. Optional `sf`/projected-CRS acceptance is separate.

## Licence

Unless otherwise indicated, the original source code, scientific protocol documents, accompanying documentation, configuration, and original synthetic examples and test fixtures in this repository are licensed under the [MIT License](LICENSE). The same licence applies to reusable code examples in the documentation; there is no separate documentation licence.

Third-party material retains its existing terms and notices. This licence does not change the rights applicable to user-supplied datasets or replace the terms applicable to OpenStreetMap-derived material. See [Third-party notices](THIRD_PARTY_NOTICES.md) for scope and exceptions.

## Citation and methodological use

When a study's data handling adopts these contracts, cite the repository release or full commit actually used, identify the applicable contracts, and document study-specific departures. The [CITATION.cff](CITATION.cff) file supplies bibliographic metadata; [Citation and reuse](docs/Citation%20and%20reuse.md) provides manuscript wording and release-specific guidance.

Following a contract and running the supplied validator are distinct activities. A successful validator run does not certify conditions outside the available evidence. Scholarly citation is requested for methodological traceability, not imposed as an additional MIT licence condition. OSM attribution and other applicable third-party requirements remain separate.
