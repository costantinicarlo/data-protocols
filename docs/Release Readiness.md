# v0.1.0 release-readiness report

**Recommendation: do not release yet.** The committed technical candidate passes all four mandatory offline suites, including 138 hardening groups, with container networking disabled. Source-code licensing needs a maintainer decision, representative Synology exporter acceptance is unavailable, and remote CI has not run. No push, merge, tag, release, permission change or branch-protection change was performed.

## Baseline and scope

Work began on clean `main` at `6c30c1754f92bd9c765480892dd0f990de4bd30f`, the audited SHA. `origin` is `https://github.com/costantinicarlo/data-protocols.git`. Read-only `git ls-remote origin HEAD 'refs/tags/*'` returned the same HEAD and no tags; the GitHub releases endpoint returned an empty array on 2026-09-08. No upstream changes were discarded. There were no applicable repository `AGENTS.md` files. Work is on local branch `fix/v0.1.0-release-hardening`.

Generator `1.1.2` is distinct from the unreleased repository/compliance candidate `0.1.0`. Workbook `2.0.0-draft.1`, identifier `1.0.0-draft.1`, and coordinate `1.0.0-draft.1` versions remain unchanged; the toponymy contract remains unversioned. Implementation notes clarify existing requirements, without mechanically adopting or version-bumping a workbook contract.

The implementation snapshot is commit `4270181a45d1cc4f82d44bf281989f96985878be` (`Fix release-candidate validation, lookup integrity, and request throttling`). [Tested content](release-evidence/tested-content.json) records SHA-256 for every tracked file in that commit. The subsequent report/pin commit changes documentation and forensic evidence only (no production or mandatory-test files) and is deliberately not identified by a self-referential SHA.

Changed implementation paths: `src/compliance/values.R`, `identifiers.R`, `workbook.R`, `pipeline.R`, and `src/osm_toponym.R`. Supporting changes: all four contracts' implementation notes, `README.md`, `docs/Dataset Compliance.md`, `.gitignore`, `.github/workflows/regression.yml`, both existing tests and the fixture generator, plus `tests/make_hardening_fixtures.py`, `test_hardening.R`, `test_entrypoints.R`, and `run_all.R`.

## Findings and evidence

All F01–F09 hypotheses were confirmed by executed regressions against pristine baseline source. The original two suites passed after configuring a compatible runtime. The initial new regression suite had 104 failing groups out of 128; later additions expand coverage. [Sanitised baseline checks](release-evidence/baseline-checks.txt) retain the observed assertion failures; [initial test digests](release-evidence/baseline-test-digests.json) distinguish that initial regression revision from the final expanded suite. No failures from missing dependencies are counted as defect reproductions. The initial F09 high-level mock assertions alone do not establish actual baseline retry spacing: httr2 1.3.0 returns high-level mocks before its internal retry loop. A separate [transport-level baseline reproduction](release-evidence/reproduce-baseline-retry.R) runs the audited code with httr2's retry body unchanged and only transport/clock/sleeper bindings shadowed in a private environment. It observed attempts at fake times `15, 15` with configured interval 15 and `Retry-After: 0`; [observed output](release-evidence/baseline-retry.txt) demonstrates the zero-second gap. No package namespace is mutated. To repeat it, extract the audited commit into a temporary directory and pass that directory to `Rscript docs/release-evidence/reproduce-baseline-retry.R BASELINE_ROOT`; this historical forensic command is separate from the current-candidate regression entry point.

| Finding | Disposition and source evidence | Regression evidence |
| --- | --- | --- |
| F01 | Confirmed and fixed. `validated_field_rule()` and `json_values()` in `values.R` validate supplied declarations before observations, cache per-field results, preserve absent versus empty vocabulary, reject malformed shapes and incompatible bounds. Inline/reference constraints both apply. | `F01` groups cover rows, zero rows, all-missing columns, bounds/type/required typos, homogeneous scalar representations, malformed JSON, empty and disallowed vocabulary, single metadata findings, and failed full publication with retained pointer/snapshot. |
| F02 | Confirmed and fixed. `overpass_problem()`, `query_place_nodes()` and `retain_lookup_failure()` in `osm_toponym.R` reject incomplete responses and malformed candidates before success caching or selection. | `F02 rejected envelope`, `old error cache and valid empty`, `valid candidates and fallback`, and `CLI and enriched publication reject incomplete Overpass` test error/partial/unknown remarks, malformed arrays/elements, valid empty/candidates, quarantined bytes, CLI status 2 and publication failure. |
| F03 | Confirmed and fixed. `main()` reads literal UTF-8 CSV strings and verifies exact headers/record widths; `resolve_toponyms()` validates all IDs/coordinates before any lookup. | `F03 actual CSV path preserves identifiers` covers numeric-only and mixed batches, zeros, long strings, NA-like literals, Unicode, surrounding whitespace, duplicates and order; `prevalidation preserves output and makes zero requests` covers invalid rows/headers. Fresh subprocess CLI checks verify actual GeoJSON strings. |
| F04 | Confirmed and fixed. `legacy_missing()` and `report_legacy_missing()` give value/temporal validators one field-scoped interpretation and one informational finding per exception. Identifiers cannot be missing codes; required evidence remains required. | `F04` groups exercise each temporal category, declared/undeclared codes, exact CSV/diagnostic literals, blanks, required codes, invalid dates, ambiguous timestamps, absent timezone and missing keys. Existing suite retains native temporal checks. |
| F05 | Confirmed and fixed. `run_compliance()` performs core validation, eligible full-run enrichment, then final required coverage. `run_toponym_enrichment()` reports no eligible lookup as `not_assessed`. | `F05 required eligible enrichment`, disabled/empty/unknown/core-error/stage cases; fresh-process successful/failed enrichment with retained current pointer, snapshot, repeated entity IDs and artifact digests. All named stages are nonpublishing. |
| F06 | Confirmed and fixed. `read_ods()` reserves cumulative repeated-row occupancy before expanding any cell; `ods_positive_integer()` validates repetitions/indices. Both adapters retain per-worksheet budget scope and omit empty trailing grid from observation materialisation. | `F06` groups cover 100 repeated rows × two cells, multiple groups, formula-only/excluded sheets, exact limits, empty repeats, fractional/zero/oversized/index values. The materialisation guard proves rejection precedes cell expansion; XLSX exact/over-limit cases match scope. |
| F07 | Confirmed and fixed. `collection_profile()` validates integer declaration shapes before observations; four-digit years compare directly to full bounds. Only two-digit ranges require unique century suffixes. | `F07 long full-year range` accepts 1850 and 2026; out-of-range, ambiguous two-digit intervals, malformed/fractional/object/empty/null widths/ranges fail, including empty tables. A 100-year interval remains valid. |
| F08 | Confirmed and fixed. Package JSON calls in `osm_toponym.R` explicitly use `jsonlite::`; no global helper is removed or overwritten by the implementation. | `F08 global JSON helper collision` and `test_entrypoints.R` run standalone CLI, compliance CLI and global programmatic loading in fresh processes, test cache misses/hits and actual GeoJSON/cache files, and check working-directory/options restoration on success/failure. |
| F09 | Confirmed and fixed. `perform_api_request()` explicitly controls attempts with nested retries/redirects disabled, service limiter/cooldowns, injectable monotonic time, bounded attempts/timeouts and longest applicable wait. | `F09` timestamp groups test success, transport/transient HTTP/429, shorter/longer/malformed/missing/date retry hints, attempt/budget exhaustion, permanent denials, cross-record cooldowns and cache hits. Fresh-process two-table requests are spaced at least 15 seconds with fake time. |

## Executed environment and commands

The host had no accessible R runtime on PATH. Its existing local R library contained macOS binaries incompatible with the Linux container, and the container's startup environment prioritised an old `rlang`. These setup attempts failed and are not test passes. A separate ignored `local/hardening-R-library/` was populated using CRAN; existing libraries/caches/source data were preserved. Disabling container startup overrides selected the compatible library for all subprocesses.

Executed runtime: R 4.4.3, Linux aarch64, Ubuntu 24.04.2, Python 3.12.3. Docker image `costantinicarlo/rocker-verse_arm64:4.4.3`, immutable digest `sha256:684e3953beadfcfbd0f4ae047a12ce24a79e409aae335879ffc4eb193fe85556`. Packages: `jsonlite` 2.0.0, `xml2` 1.3.8, `digest` 0.6.37, `httr2` 1.3.0, `curl` 8.0.0, `rlang` 1.3.0. `sf` was unavailable; no projected-CRS acceptance pass is claimed. C-locale subprocesses and UTF-8 literal preservation are mandatory in the existing compliance suite.

Observed final result for committed snapshot `4270181a45d1cc4f82d44bf281989f96985878be`: `Rscript tests/run_all.R` exited **0**. Both existing suites passed, all **138** hardening groups passed, and fresh-process CLI/programmatic checks passed, including the bundled XLSX/ODS examples, every named partial stage, failed snapshots/current-pointer preservation, and artifact digests. [Sanitised final check output](release-evidence/candidate-checks.txt) records these results. No mandatory checks were skipped; optional `sf`/real-export/remote-matrix checks remain explicitly unavailable or unexecuted.

Static checks executed successfully: `git diff --check`; Python fixture-generator compilation; workflow YAML parsing with three matrix entries and read-only permissions; local Markdown target links; fenced JSON/config examples; generator/User-Agent strings; cache ignore rules at root/nested locations; SHA-256 verification of component content against the shared implementation pin; final diff/private-data review. Historical outputs, example workbook bytes, and third-party notices were not replaced. README/report/evidence additions after the tested commit do not alter executable files or contract/component bytes.


Reproduce with installed compatible dependencies from the repository root:

```sh
Rscript tests/test_compliance.R
Rscript tests/test_osm_toponym.R
Rscript tests/run_all.R
```

The combined entry point also runs `test_hardening.R` and `test_entrypoints.R`, fails on missing dependencies and supplies an unexpected-HTTP guard to child processes. Every geocoding response is mocked or replayed from a synthetic cache. The actual local test invocation additionally disabled container networking:

```sh
docker run --rm --network none --entrypoint Rscript \
  -e R_ENVIRON=/dev/null -e R_ENVIRON_USER=/dev/null \
  -e R_PROFILE=/dev/null -e R_PROFILE_USER=/dev/null \
  -e R_LIBS_USER=/test-library \
  -v "$PWD/local/hardening-R-library:/test-library:ro" \
  -v "$PWD:/work:ro" -w /work \
  costantinicarlo/rocker-verse_arm64@sha256:684e3953beadfcfbd0f4ae047a12ce24a79e409aae335879ffc4eb193fe85556 \
  tests/run_all.R
```

Dependency installation may use CRAN; tests may not access public geocoding services. R package DESCRIPTION requirements checked locally: httr2 requires R >= 4.1, rlang >= 4.0.0, curl >= 3.0.0. These declarations are compatible with the documented R 4.2 minimum; actual minimum/current-R and macOS runtime execution remains a CI gate, not an inferred pass. The fixture generator's Python 3.12-only f-string syntax was corrected for Python 3.10 compatibility.

## Compatibility, cache and policy

Previously ignored invalid metadata now blocks publication, including on empty tables. Explicit empty inline vocabularies remain empty even if a reference list is supplied. Arrays permit homogeneous strings, finite numbers or booleans; string comparison semantics and required/key interactions are documented in [Dataset Compliance](Dataset%20Compliance.md#selective-declaration-semantics-in-the-corrected-implementation). Genuine blanks, all-missing named variables, repeated entity keys, original text and immutable source bytes remain preserved. No source correction, global CSV/JSON ignore rule, cache deletion or state-directory replacement was introduced.

Successful cache/state directories retain their layout. Invalid old Overpass responses move unchanged into `.osm_toponym_cache/failures/` with separate failure markers; fresh failed responses create bounded diagnostic markers rather than successful-response cache entries. All nonempty remarks are rejected; there is no informational allowlist. `verified` still means run date. Requested incomplete enrichment cannot replace `current.json`.

The [official Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/) was checked on 2026-09-08: one-thread/one-machine bulk use, caching and application identification apply, with recurring/long-running jobs limited to four requests per minute. The integration retains >=15-second actual-attempt spacing (default 15.1); standalone 1.10-second spacing is only for appropriate one-off use. The limiter does not coordinate independent processes. The [official httr2 retry API](https://httr2.r-lib.org/reference/req_retry.html) and [error-control API](https://httr2.r-lib.org/reference/req_error.html) informed explicit attempt control, then actual behavior was exercised with httr2 1.3.0.

## CI, acceptance and decisions

`.github/workflows/regression.yml` uses pull requests and pushes to main/fix branches, read-only `contents`, and `persist-credentials: false`. Actions pins were resolved by `git ls-remote` and verified against the official immutable action metadata: checkout `d23441a48e516b6c34aea4fa41551a30e30af803` (v6) and r-lib/actions `465b7d8e732ca3921382b1674c59bada9cbf3399` (v2), both Node 24. The matrix requests Linux R 4.2.3/current release and macOS current release. Dependencies are installed explicitly; no mandatory integration test is skipped. No privileged pull-request trigger is used. **Remote CI: not run; the branch has not been pushed.**

**Licence: `maintainer_decision_required`.** No tracked project source licence or explicit selection was evidenced. No licence or ownership assertion was invented. The bundled country-code reference's public-domain notice and OSM data attribution remain intact; OSM data licensing is not applied to project source.

**Real exports: unavailable/not executed.** Included XLSX/ODS examples and generated fixtures are synthetic. The [representative Synology acceptance checklist](Dataset%20Compliance.md#representative-synology-export-acceptance) records how to compare actual authorised source values, types, dimensions and digests. Private downloads or server links were not used as test fixtures or committed. No live geocoder run or historical rerun was fabricated. Historical README results remain explicitly historical.

Release requires maintainer licence resolution, documented representative exporter acceptance for intended formats, and a passing remote CI matrix after separately authorised branch publication. Optional projected-CRS/sf acceptance is additionally required if that functionality is adopted operationally. Technical regression success alone is insufficient to mark v0.1.0 ready.
