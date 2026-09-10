# Changelog

User-facing changes to this repository are recorded here, newest first. Repository release versions are distinct from utility and contract versions.

Record future changes under **Unreleased**, grouped under Added, Changed, Deprecated, Removed, Fixed, or Security as appropriate. At release time, move those entries into a versioned section with the actual release date in `YYYY-MM-DD` format and start a fresh Unreleased section. Omit empty categories.

## Unreleased

No changes recorded beyond the pending 0.1.0 release.

## 0.1.0 — Pending release

Initial repository release candidate. This entry describes the prepared contents; it does not indicate that a tag or release has been published. Replace “Pending release” with the actual release date when publishing.

### Added

- Scientific data contracts covering workbook structure and source preservation, identifiers and lineage, geographical coordinates, and OpenStreetMap-based toponymy.
- An R workbook compliance pipeline for XLSX/ODS snapshot preservation, extraction, validation, coordinate standardisation, revision comparison, and publication of validated builds. Failed checks preserve the last validated publication; individual stages support inspection without publication.
- Optional geographical enrichment and a standalone CSV-to-GeoJSON toponym utility combining Nominatim reverse geocoding, Overpass place-node matching, and disk caching.
- Configuration examples, synthetic XLSX/ODS workbooks, geographical examples, and a country-code reference with retained upstream notices.
- Offline regression suites for workbook compliance, toponym resolution, validation hardening, and fresh-process command-line and programmatic entry points, plus a GitHub Actions matrix for Linux and macOS.
- Usage and acceptance documentation, immutable implementation pins, and historical release-readiness evidence.
- An MIT licence for original project material, third-party notices, citation metadata and methodological citation guidance.
- A repository hex logo and README branding, plus this changelog for future releases.

### Fixed

- Malformed value constraints and identifier-profile declarations now fail validation even when tables are empty or contain only missing observations. Explicit empty vocabularies remain distinct from absent constraints, and full-year identifier ranges are validated without two-digit century ambiguity.
- Declared legacy missing codes are interpreted consistently across value and temporal checks while preserving required-field and identifier requirements.
- Required geographical enrichment is assessed after eligible lookups; incomplete or ineligible enrichment cannot silently satisfy required coverage or replace the current publication.
- ODS repeated-row and cell limits are checked before expansion, with per-worksheet resource limits aligned across workbook adapters.
- Incomplete or malformed Overpass responses are rejected before matching or success caching. Invalid historical cache entries are retained separately with failure diagnostics.
- Standalone CSV input preserves literal UTF-8 identifiers, including leading zeros and missing-token-like strings, and validates all records before network requests.
- Explicit JSON namespaces prevent collisions when the resolver is loaded alongside compliance helpers.
- Request throttling covers retries as well as initial attempts, with bounded attempts and timeouts, server retry guidance, and immediate stopping on access denials.

### Component versions and limitations

- Repository/compliance suite: `0.1.0`; standalone toponym generator: `1.1.2`.
- Workbook contract: `2.0.0-draft.1`; identifier and coordinate contracts: `1.0.0-draft.1`; toponymy contract: unversioned. A repository release does not itself adopt draft contracts.
- Validation assesses available evidence and does not certify scientific correctness or human review of geographical identities. The resolver's `verified` field denotes the run date.
- See the [release-readiness report](docs/Release%20Readiness.md) for historical test evidence and outstanding acceptance requirements. Representative source-export acceptance, remote CI results, and optional projected-CRS acceptance must be assessed for the release; this changelog does not assert that they have passed.
