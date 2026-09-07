# Data Standard Operating Protocols

Shared conventions for reproducible scientific data curation and geographical references, with an R utility for resolving coordinates against OpenStreetMap (OSM).

## Current status

The toponym utility reports generator version `1.1.1` and combines Nominatim reverse geocoding with Overpass place-node matching and disk caching. The workbook contract is `2.0.0-draft.1` (2026-09-07), proposed for review and adoption; its ingestion and validation pipeline is not implemented in this repository. The toponymy contract has no declared semantic version.

Use the immutable Git revisions below for pre-release adoption. No release tags are present in this checkout. A generator version or draft contract label alone does not identify exact file contents.

## Pinning source code and contracts

The following full commit IDs identify the current committed source and contracts, verified on 2026-09-07. The source pin includes version `1.1.1`, its HTTP-error handling fixes, and offline regression tests:

| Component | Path | Commit to pin |
| --- | --- | --- |
| Toponym utility (`1.1.1`) | `src/osm_toponym.R` | `c420c2f5c803a526ddb40d2b824e3fb122026811` |
| Toponymy Reference Contract (unversioned) | `contracts/Toponymy Reference Contract.md` | `43c05938f6517e2805f8c8854bef8b37452d8df8` |
| Workbook contract (`2.0.0-draft.1`) | `contracts/Workbook Datasets — Source-of-Truth Contract.md` | `b58095009bc9b2538fbcb8f29399b53eee46bec6` |

These are **Git commit IDs**, not file checksums. Each component pin is its most recent modifying commit. For a single checkout containing all three components listed above, pin **`43c05938f6517e2805f8c8854bef8b37452d8df8`**. It contains the revised Toponymy Reference Contract; the utility and workbook contract are byte-for-byte identical to their respective component pins above.

Example YAML for a consuming repository's manifest (illustrative keys; adapt to its manifest schema):

```yaml
data_protocols:
  repository: "<repository-clone-url>"
  revision: "43c05938f6517e2805f8c8854bef8b37452d8df8"
  source:
    path: "src/osm_toponym.R"
    revision: "c420c2f5c803a526ddb40d2b824e3fb122026811"
    generator_version: "1.1.1"
  contracts:
    toponymy:
      path: "contracts/Toponymy Reference Contract.md"
      revision: "43c05938f6517e2805f8c8854bef8b37452d8df8"
    workbook_datasets:
      path: "contracts/Workbook Datasets — Source-of-Truth Contract.md"
      revision: "b58095009bc9b2538fbcb8f29399b53eee46bec6"
      contract_version: "2.0.0-draft.1"
```

Replace `<repository-clone-url>` with the actual accessible repository location. This checkout currently has no configured Git remote, so no published URL or remote availability has been verified. Ensure the pinned commits are available from the repository used by consumers.

After cloning, select and verify the shared snapshot:

```sh
git -C path/to/data-protocols checkout --detach 43c05938f6517e2805f8c8854bef8b37452d8df8
git -C path/to/data-protocols rev-parse HEAD
git -C path/to/data-protocols diff --exit-code HEAD -- src/osm_toponym.R contracts/
```

Use full hashes in manifests rather than a moving branch name or `HEAD`. These pins identify the source and contracts, not future README edits. Advance them only after the relevant changes are committed and reviewed. To obtain the latest modifying commits in a later checkout:

```sh
git log -1 --format=%H -- src/osm_toponym.R
git log -1 --format=%H -- 'contracts/Toponymy Reference Contract.md'
git log -1 --format=%H -- 'contracts/Workbook Datasets — Source-of-Truth Contract.md'
```

Record local configuration edits or patches separately from the upstream revision. Pinning this repository does not pin R dependencies or the changing OSM services; retain dependency versions, API caches, input/output digests, and run provenance when reproducibility requires them. The GeoJSON includes `generator_version`, but the script does not automatically embed these Git revisions.

## Repository contents

| Path | Purpose |
| --- | --- |
| [Toponymy Reference Contract](contracts/Toponymy%20Reference%20Contract.md) | OSM reference conventions for geographical identity, names, discrepancies, and provenance. |
| [Workbook Datasets — Source-of-Truth Contract](contracts/Workbook%20Datasets%20%E2%80%94%20Source-of-Truth%20Contract.md) | Draft conventions for source workbooks, worksheet roles, raw/calculated fields, keys, metadata, and extraction. |
| [src/osm_toponym.R](src/osm_toponym.R) | CSV-to-GeoJSON command-line utility using Nominatim and Overpass. |
| [examples/example_toponym.json](examples/example_toponym.json) | Illustrative single Feature with placeholder reference data, not a verified lookup. |
| [examples/input_data.normalized.csv](examples/input_data.normalized.csv) | One-site input with the required `id,latitude,longitude` columns. |
| [examples/input_data.toponyms.geojson](examples/input_data.toponyms.geojson) | Earlier lookup output for that example; predates the current status/provenance schema and contains an escaped attribution artifact. |
| [data-protocols.code-workspace](data-protocols.code-workspace) | VS Code workspace opening this directory. |
| [tests/test_osm_toponym.R](tests/test_osm_toponym.R) | Offline regression checks for service denials, diagnostics, cache reuse, and CLI status handling. |

The contracts are the authoritative protocol text. Workbook-specific metadata belongs in the source workbook, especially `meta__readme` and `meta__tables`.

`inputs/`, `outputs/`, and `local/` are ignored working directories, not distributed datasets. The current local batch uses `inputs/sites_2015.csv` and writes `outputs/sites_2015.toponyms.geojson`; those files are not supplied by a fresh clone.

## Setup and execution

The script requires R 4.2 or later for its native pipe with a named `_` placeholder (see the [R pipe documentation](https://stat.ethz.ch/R-manual/R-patched/RHOME/library/base/html/pipeOp.html) and [R 4.2 release announcement](https://stat.ethz.ch/pipermail/r-announce/2022/000683.html)). Install `httr2` and `jsonlite`; dependency versions are not locked. Use a UTF-8 locale to preserve geographical names and attribution.

From the repository root, install into an ignored local library:

```sh
mkdir -p local/R-library inputs outputs
Rscript -e 'install.packages(c("httr2", "jsonlite"), lib="local/R-library", repos="https://cloud.r-project.org")'
```

The script sends an identifying `data-protocols/osm_toponym/1.1.1` User-Agent by default. Set `OSM_CONTACT_EMAIL` to append a real project contact, or `OSM_USER_AGENT` to supply your own identifying application string. Empty or known placeholder User-Agents are rejected before processing. No fictitious contact is sent by default. Review `NOMINATIM_URL`, `OVERPASS_URL`, `NOMINATIM_ZOOM` (15), `NOMINATIM_DELAY` (1.10 seconds), `PLACE_NODE_RADIUS_M` (5,000 metres), and `PLACE_TYPES`. These service/search settings remain script constants, not environment-variable or command-line options. Keep any local configuration changes in downstream provenance when using a pinned upstream revision.

The CSV must contain `id`, `latitude`, and `longitude`; additional fields are not copied to the output. Coordinates are decimal degrees, with latitude in [-90, 90] and longitude in [-180, 180]. Missing/non-finite coordinates stop the batch. Input uses `read.csv()` type inference, so purely numeric IDs may lose leading zeros; prefer explicit textual IDs such as `S01G1`.

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

Successful API responses are cached under `.osm_toponym_cache/nominatim/` and `.osm_toponym_cache/overpass/`, relative to the process working directory. The commands above therefore use `local/.osm_toponym_cache/`. A run from the repository root creates a root cache that the current `.gitignore` does not exclude.

Rerunning reuses readable cached responses and retries requests whose responses were not cached; it rebuilds the output rather than resuming a partial GeoJSON file. Nominatim cache keys include coordinates and zoom; Overpass keys include coordinates and radius. Keys do not include service URLs, the accepted place-type list, or cache age. Preserve caches for reproducibility, and use a separate cache when changing those assumptions or deliberately refreshing source data. Earlier local Feature caches are not interchangeable with this version's full-response JSON caches.

**Read the [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/) before submitting coordinates.** The public service requires application identification, attribution, caching for bulk work, and at most one request per second. Small one-time bulk jobs must use one thread on one machine; recurring jobs and jobs lasting longer than a day are restricted to four requests per minute. The script delays each uncached Nominatim request by 1.10 seconds; it does not automatically implement the stricter recurring-job limit. Do not submit confidential material. Select suitable services and rate limits for the intended workload.

## HTTP failures and diagnosis

An HTTP 403 means the service denied the request; it does not mean that coordinates are invalid or a locality is absent. The original local `sites_2020.toponyms.geojson` had 48 unresolved records with the same 403 and no service context. The old script sent a placeholder contact, continued across all rows, embedded terminal formatting in JSON messages, and exited successfully despite every lookup failing. That output alone cannot establish whether the service rejected the identification, the network/IP, or another access condition.

The patched CLI was rerun on the same 48-site input on 2026-09-07: all 48 records resolved as `node_exact`, with IDs, order, and query coordinates verified. The original failure file is preserved locally as `local/sites_2020.before-fix.geojson`. The successful rerun supports application identification as a likely cause, but the original response details are insufficient to prove it.

Version `1.1.1` identifies Nominatim versus Overpass in errors and includes a bounded plain-text excerpt of the server response. HTTP 401/403 stops immediately; exhausted HTTP 429 retries also stop the batch. Existing output remains unchanged and completed responses remain cached. Correct the access/configuration problem before rerunning; repeatedly retrying a denied service will not fix it.

Requests have a 30-second timeout and at most four attempts, with exponential backoff and a 120-second retry budget. Transient HTTP 429/500/502/503/504 and transport failures are eligible for retries; server `Retry-After` guidance is handled by httr2. Permanent 401/403 responses are not retried. Other exhausted failures are recorded as unresolved with plain-text messages and cause CLI exit status `2`.

## Validation and maintenance

The latest local 2015 run on 2026-09-07 produced 78 records, all classified `node_exact`: 72 used Nominatim place nodes directly and six used Overpass matching. Input IDs, order, and query coordinates were checked. One HTTP 504 recovered on a cached rerun. Execution used a local copy with the placeholder User-Agent replaced; the tracked source was unchanged. This run checks execution and output structure, not the scientific correctness of every match.

Run the offline regression checks from the repository root:

```sh
R_LIBS_USER="$PWD/local/R-library" Rscript tests/test_osm_toponym.R
```

The checks intercept HTTP requests and use temporary caches; they do not call public services. They cover Nominatim/Overpass access denials, preserving existing outputs, diagnostic formatting, retry classification, cache reuse, and incomplete-run exit status. There is no R package manifest, dependency lockfile, or workbook converter in this repository. The tracked example output predates version 1.1.0 and is not a current regression fixture. When changing the utility, validate with controlled responses before live requests and inspect unresolved, ambiguous, and fallback results. When changing contracts, keep their status/version explicit and update downstream pins after adoption.

Keep source, contracts, and curated examples under version control. The `.gitignore` excludes OS metadata, R session state, editor/spreadsheet temporary files, local environment files, and the three working directories. CSV, JSON, GeoJSON, and workbook formats are not ignored globally.
