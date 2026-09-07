# Data Standard Operating Protocols

Shared conventions for reproducible scientific data curation and geographical references, with an R utility for resolving coordinates against OpenStreetMap (OSM).

## Workspace contents

| Path | Purpose |
| --- | --- |
| [Toponymy Reference Contract](contracts/Toponymy%20Reference%20Contract.md) | Defines OSM as the default external reference for geographical names, with guidance on identity, alternative names, discrepancies, and provenance. |
| [Workbook Datasets — Source-of-Truth Contract](contracts/Workbook%20Datasets%20%E2%80%94%20Source-of-Truth%20Contract.md) | Defines source workbook conventions, worksheet roles, raw/calculated fields, keys, metadata, and extraction requirements. Version `2.0.0-draft.1`, dated 2026-09-07; review and adopt before enforcement. |
| [src/osm_toponym.R](src/osm_toponym.R) | Command-line reverse-geocoding utility: CSV coordinates to a GeoJSON FeatureCollection using Nominatim. |
| [examples/example_toponym.json](examples/example_toponym.json) | Illustrative single GeoJSON Feature with example coordinates and an OSM identifier; not a verified lookup or a complete batch output. |
| [data-protocols.code-workspace](data-protocols.code-workspace) | VS Code workspace opening this directory. |

The contracts are the authoritative protocol text. Workbook-specific metadata belongs in the source workbook, especially `meta__readme` and `meta__tables`. The workbook ingestion and validation pipeline described by the draft contract is not included here.

## Run the toponym utility

Use R 4.1 or later (the script uses the native `|>` pipe), with `Rscript` available on your PATH. Install the two dependencies:

```sh
Rscript -e 'install.packages(c("httr2", "jsonlite"), repos = "https://cloud.r-project.org")'
```

Before running, edit the configuration in `src/osm_toponym.R`: replace the placeholder contact in `USER_AGENT` with your project contact and select an appropriate `NOMINATIM_URL`. These are script constants, not environment variables or CLI options. The default endpoint is the public Nominatim reverse service; network access is required.

**Public-service use:** read the [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/) before submitting coordinates. It limits traffic to at most one request per second and requires application identification and attribution. Small one-time bulk jobs must use one thread on one machine and cache results; recurring jobs or jobs longer than a day are limited to four requests per minute. Do not submit confidential coordinates. Use an appropriate alternative service or your own instance for substantial workloads.

The script processes rows sequentially with a 1.05-second delay between rows, but has no query cache or resume support and does not implement the recurring-job limit. Arrange caching and the applicable rate limit before using the public service for batch work; the delay alone does not establish compliance.

Prepare a CSV with these required columns (additional columns are not copied to the output):

```csv
id,latitude,longitude
SITE_001,12.54310,-16.12320
```

Use decimal-degree latitude and longitude. Latitude must be between -90 and 90, and longitude between -180 and 180; missing or non-finite coordinates stop processing. Use textual IDs such as `SITE_001`: input is read with `read.csv()` type inference, so purely numeric identifiers can lose leading zeros.

From the workspace root, with your input saved as `local/sites.csv`:

```sh
mkdir -p local outputs
Rscript src/osm_toponym.R local/sites.csv outputs/toponyms.geojson
```

Create the input CSV before invoking `Rscript`. The script requires exactly two positional arguments, does not create output directories, and overwrites an existing output file at the supplied path.

## Output and review

The output is a GeoJSON `FeatureCollection` with OSM attribution, a UTC generation timestamp, and one Feature per input row. Features contain the source ID, returned name, OSM object type/ID/URL, lookup date (`verified`), geographical context, and original query coordinates. GeoJSON Point coordinates are ordered **longitude, latitude** and normally use the returned object's coordinates, which may differ from the query location.

Request errors caught by the script produce a Feature at the query coordinates with `status: "unresolved"`, an error message, and null reference fields. Invalid input coordinates abort the run; malformed service responses may also interrupt processing. Output is written only after the batch completes.

Review returned objects and unresolved records against the Toponymy Reference Contract before adopting names. The script's `verified` field records the lookup date; it does not certify human verification or that the returned object is the intended locality. Alternative-name curation and contract enforcement remain separate work.

## Maintenance and local files

Keep protocol changes, source code, and curated examples under version control. Use `local/` for working inputs and `outputs/` for generated results; both are ignored. The `.gitignore` also excludes OS metadata, R session state, editor/spreadsheet temporary files, and local environment files. CSV, JSON, GeoJSON, and workbook formats are not ignored globally, so intentional reference material can be versioned outside those local directories.

This workspace currently has no R package manifest, dependency lockfile, automated test suite, or workbook converter. Dependency versions are not pinned. When changing the utility, check input validation and output structure with controlled responses before making live service requests. When changing contracts, keep their status/version explicit and distinguish proposed requirements from implemented behaviour.
