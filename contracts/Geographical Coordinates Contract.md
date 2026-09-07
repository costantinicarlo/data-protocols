# Geographical Coordinates Contract

**Contract version:** `1.0.0-draft.1`

**Document date:** 2026-09-07

**Status:** Draft for adoption. Specifies coordinate representation and derived conversions without authorising alteration of immutable source downloads.

**Implementation:** The workbook compliance suite implements the checks described in [Dataset Compliance](../docs/Dataset%20Compliance.md). Its coverage reports distinguish assessed conditions from missing evidence.

## 1. Meaning and preservation

A coordinate locates an observation or geographical reference under a declared coordinate reference system (CRS). A numeric pair alone does not establish its CRS, axis order, precision, uncertainty, or scientific meaning.

Retain downloaded workbook bytes and the original coordinate values. Correct erroneous observations in the source of truth. Deterministic conversions MAY produce separate derived coordinates, with the input values, source location, method, and CRS retained in provenance. They MUST NOT overwrite the archival original table.

Sampling coordinates and OSM anchor coordinates are different observations. A toponym lookup MUST NOT replace the sampling position with a settlement node. Apply the [Toponymy Reference Contract](Toponymy%20Reference%20Contract.md) when adopting geographical references.

## 2. Fields and reference systems

Identify coordinate roles explicitly in source metadata where labels or multiple coordinate pairs could be ambiguous. Common labels such as `latitude`, `lat`, `longitude`, `lon`, and `lng` may identify candidates; generic `x`, `y`, `easting`, and `northing` require a declared mapping and CRS.

Declare the source CRS for each pair or as a workbook default. Do not infer WGS84 solely because coordinates fall within geographic ranges. Projected values require their actual source CRS and an explicit transformation; do not interpret metres as degrees or infer a projection from the collection country.

The canonical derived output for the current geocoding workflow is WGS84 longitude/latitude in decimal degrees. GeoJSON uses longitude first, followed by latitude, with WGS84 as its geographic reference system. See [RFC 7946, sections 3.1.1 and 4](https://www.rfc-editor.org/rfc/rfc7946.html).

The workbook adapter's mapping uses `longitude` for the source x/easting field and `latitude` for y/northing during an explicitly declared CRS transformation. Those mapping labels do not claim the original values were already angular coordinates.

## 3. Values and representations

For decimal-degree geographic coordinates, latitude MUST be finite and between -90 and 90 inclusive; longitude MUST be finite and between -180 and 180 inclusive. Zero is a valid coordinate, not an automatic missing-value marker. A partially missing pair is invalid; both coordinates may be blank unless the collection declares the pair required.

Supported convertible representations include signed decimal degrees, decimal degrees with a hemisphere, degrees and decimal minutes, and degrees/minutes/seconds. Hemisphere markers MUST agree with the axis and any explicit sign. Minutes and seconds must be nonnegative and less than 60; the resulting degree value must still satisfy the axis bounds.

Decimal commas require an explicit decimal-mark declaration. Mixed or ambiguous separators, conflicting hemispheres, unknown formats, and ambiguous axis mappings require review. Suspected latitude/longitude swaps or unexpected geographical extents MUST NOT trigger automatic swapping, deletion, or substitution.

A bare pair of whitespace-separated numbers is not automatically assumed to mean degrees and minutes; declare its format if that is the recorded convention. Projected-coordinate conversion requires suitable transformation software and an available transformation for the declared CRS. Failed or unavailable transformations remain failures; the pipeline must not invent approximate coordinates.

## 4. Precision and display

Decimal degrees describe a representation, not a fixed five-decimal numeric type. `13.6` and `13.60000` denote the same number. Appending zeros does not improve positional accuracy, and rounding a more precise observation to five decimals discards information.

Preserve the original observation and available precision in the numeric derived values. A requested five-decimal presentation MAY be emitted in separate display fields such as `latitude_display` and `longitude_display`. Do not use those rounded strings as replacements for the original or full-precision derived coordinates.

Record measurement resolution or positional uncertainty explicitly where available. The number of digits in a serialised coordinate does not establish its uncertainty; see [RFC 7946, section 3.1.10](https://www.rfc-editor.org/rfc/rfc7946.html#section-3.1.10).

## 5. Source metadata and conversion evidence

Keep the authoritative mapping in `meta__readme`, using `coordinate_crs` for a default or a `coordinate_fields` JSON object for individual tables. The machine-readable layout and examples are defined in the [pipeline guide](../docs/Dataset%20Compliance.md#source-metadata).

For each converted record, retain the source sheet/row, record identifier where present, original coordinate strings, full-precision derived values, source and target CRS, conversion method, and outcome. Record the snapshot digest, software/configuration fingerprints, and optional geospatial-library versions in the run manifest.

Conversion outcomes are `converted`, `missing`, or `unresolved`. A representation that was already decimal degrees can have `converted` status because it was parsed and validated; the method records `decimal_degrees`. This status does not certify field positioning accuracy or geographical identity.

Expected geographical extents MAY supply review warnings. They must be documented for the actual collection and MUST NOT be inferred solely from an identifier prefix or an OSM result. Missing observations, failed conversions, and review warnings remain distinguishable.

## 6. Adoption

Adopt coordinate mappings and representations in the source workbook; preserve existing downloads and literal values during migration. The general [Workbook Datasets — Source-of-Truth Contract](Workbook%20Datasets%20%E2%80%94%20Source-of-Truth%20Contract.md) continues to govern raw tables, source corrections, and publication.

This contract does not require collecting invented precision, an assumed hemisphere, or a guessed CRS. Missing metadata must be supplied from evidence before dependent conversions or publication can be considered validated. Pin this contract's own Git revision after committing it; the draft label alone does not identify exact text.
