# Workbook datasets — source-of-truth contract

**Contract version:** 2.0.0-draft.1  
**Document date:** 2026-09-07  
**Status:** Proposed extension of version 1.0; review and adopt before enforcement.  
**Scope:** Source-of-truth Synology workbooks held in this folder.  
**Implementation status:** This document specifies required behaviour. The previously supplied XLSX ingestion scaffold does not yet implement this version.

## Purpose and responsibility

These workbooks support data generation and curation. Unchanged downloaded snapshots feed an R-based repository that publishes independent, keyed original CSV tables and, only where needed, derived or analysis-ready datasets.

**The source is responsible for the correctness and provenance of raw entries. The repository is responsible for faithful extraction, traceability, and reporting detectable contract violations. It must not repair the source or recreate its relational organisation.**

This is a stable set of conventions, not an exhaustive column schema. Ordinary columns may evolve without maintaining a parallel inventory in the repository. Presentation may support data entry; it must not be the sole carrier of information needed to interpret the data.

## At a glance

| Area | Rule |
|---|---|
| Machine-readable names | Use meaningful English `lower_snake_case`, ASCII letters and digits, and no spaces. Reserved role prefixes use two underscores. |
| Workbook identity | Use a stable descriptive name; do not encode each edit or export date into the live workbook name. |
| Worksheet roles | `data__` = observations; `ref__` = authoritative reference values; `calc__` = computed/support views; `meta__` = documentation. |
| Field roles | A field starting with exact, case-sensitive `calc__` is excluded from original data. All other fields in `data__` and `ref__` sheets are raw. |
| Table structure | One table beginning at A1; one header row; no blank separator rows or columns; no totals or embedded notes. Genuine missing cells are permitted. |
| Key | Every exported data/reference table declares one raw, nonmissing key field and what it identifies. Uniqueness depends on that declared meaning. |
| Numbers | Store numbers as numbers; use a decimal point, no thousands grouping, a defined unit and scale, and no embedded unit strings in numeric fields. |
| Dates and times | Full dates use `YYYY-MM-DD`; time uses a 24-hour clock. Record the timezone for clock times. Do not invent missing date or time components. |
| Missingness | Use a genuinely blank raw cell. Do not use zero, a space, `NA`, or a formula returning empty text as a substitute. Document any existing legacy missing codes. |
| Raw-data integrity | No cell-value formulas or pasted formula results in raw fields. Correct infringements upstream. |
| Presentation | Freeze headers/keys, use readable styles, and distinguish calculated columns visually as well as by their names. |
| Conditional formatting | Highlight existing values or explicit rules; never encode an observation solely by colour, an icon, or a border. |
| Publication | Retain the snapshot, exclude calculated content by name, validate raw tables, and publish only a valid build. Do not publish a partially repaired interpretation. |

---

## 1. Names and language

### 1.1 Machine names

Apply these rules to workbook basenames, worksheet role suffixes, and column field names:

- Use lowercase ASCII letters, digits, and single underscores between words; begin the ordinary name with a letter.
- Use English words or established scientific abbreviations with an unambiguous meaning. Prefer descriptive names to unexplained abbreviations.
- Do not use spaces, accents, punctuation, mathematical symbols, line breaks, leading/trailing whitespace, or case alone to distinguish names.
- Reserve double underscores for the role separator in `calc__field_name` and worksheet role prefixes. Do not introduce other double-underscore constructions.
- Keep names unique within their relevant scope. Do not silently repair invalid or duplicate names during extraction.

Ordinary name grammar:

```text
^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$
```

Field-name grammar in an exportable worksheet:

```text
^(?:calc__)?[a-z][a-z0-9]*(?:_[a-z0-9]+)*$
```

Examples:

| Prefer | Do not use |
|---|---|
| `sample_id` | `Sample ID`, `sample-id`, ` sample_id ` |
| `collection_date` | `Date (collection)`, `date1` |
| `chloride_mg_l` | `Cl- (mg/L)` |
| `conductivity_us_cm` | `Conductivité µS/cm` |
| `calc__watershed` | `CALC__watershed`, `calc_watershed` |

The numerical examples specify example units, not the actual units of an existing dataset. Do not rename a field to a unit suffix unless that suffix accurately describes its stored values.

Useful field suffixes are `_id` for identifiers, `_date` for full calendar dates, `_time` for clock times, and `_datetime` for date-and-time values. A unit suffix such as `_mg_l`, `_mm`, or `_s` is appropriate when it makes the quantity clearer. Document scientific qualifications that a short name cannot express, such as conductivity compensation temperature or the definition of salinity.

Do not reuse an existing name for a different quantity, unit, scale, or interpretation. A meaningful change must be named or documented explicitly. No automatic downstream aliasing is implied by similar names.

### 1.2 Workbook names and identity

Name the live source workbook for its subject and enduring scope, for example:

```text
peps_mangroves_larvae
peps_mangroves_water_chemistry
```

A year is appropriate when it defines a genuinely separate data collection, not merely the year of the latest edit. Avoid `final`, `final2`, `new`, contributor initials used as version labels, and daily export timestamps in the live source name.

Use the native Synology document name without inventing an XLSX/ODS suffix. A downloaded file receives its real extension, for example `peps_mangroves_larvae.ods`. Do not include the format extension in the logical dataset identifier.

Document a stable `workbook_id` and the Synology document link or identifier in `meta__readme`. The source registry in the pipeline uses this identity; it must not guess that a renamed or copied workbook is the same source. A live workbook rename or move is a controlled administrative change, not a reason to rewrite the entire column schema.

Snapshots may use timestamps and SHA-256 digests in the archive. Their identity is separate from the stable name of the editable source.

### 1.3 Worksheet names

Every worksheet has an explicit role prefix:

```text
^(?:data|ref|calc|meta)__[a-z][a-z0-9]*(?:_[a-z0-9]+)*$
```

Use no more than **31 characters in the complete worksheet name, including its prefix**, to retain Excel-compatible naming even when ODS is the primary export. Excel documents this limit. [S1]

Do not use tab order, tab colour, hidden state, or a name such as `Sheet1` to determine a worksheet's role. A role-prefix change is substantive: it changes extraction behaviour and requires review upstream.

### 1.4 Human language and literal values

English is the default language for machine names, newly defined categorical codes, and shared technical documentation. Where contributors need French or another language, provide translated explanations or labels without changing the machine codes; separate `label_en` and `label_fr` fields are suitable when both are useful.

This naming convention does **not** require translating or stripping accents from raw values. Preserve proper names, place names, literal specimen identifiers, scientific names with their correct capitalisation, and verbatim field notes. Notes may remain in their original language; document that language when interpretation requires it.

Do not silently lowercase, transliterate, translate, trim, or recode data during archival extraction. Contributors correct accidental whitespace and inconsistent coding upstream. Existing legitimate external codes remain exact, even when their spelling differs from the convention for newly coined codes.

---

## 2. Worksheet roles and what is exported

| Prefix | Meaning | Example | Treatment |
|---|---|---|---|
| `data__` | Entered/imported observations, specimens, sites, assays, or other primary records. | `data__samples` | Export one original CSV after excluding `calc__` columns and validating the raw table. |
| `ref__` | Authoritative entered/imported reference values or controlled vocabularies. | `ref__taxa` | Export one keyed reference CSV, catalogued separately from observation tables; exclude any `calc__` columns. |
| `calc__` | Computed views, LOOKUP-generated copies, summaries, dashboards, or formula-driven helper lists. | `calc__entry_checks` | Exclude the entire sheet from original/reference CSVs. Retain it in the unchanged workbook snapshot. |
| `meta__` | Documentation, table keys, units, methods, legends, and other interpretive metadata. | `meta__readme` | Retain in the snapshot and capture its tabular content as separately identified documentation/provenance, not as observations. |

**A lookup sheet is not automatically a calculated sheet.** A manually curated list of taxon codes and labels is authoritative reference information (`ref__taxa`), even when formulas consult it. A formula-generated copy of that list is a calculated view (`calc__taxa_view`). Classify by provenance and role, not by whether the sheet is used by LOOKUP.

Reference CSVs remain independent tables. Their preservation does not oblige the repository to implement foreign keys, reproduce spreadsheet relationships, or join them to observations. Consumers select reference information only when a particular product needs it.

An unrecognised or missing sheet-role prefix is a contract violation. The extractor must not guess, export an unknown sheet as observations, or silently ignore a potentially important table.

A minimal workbook could contain:

```text
meta__readme
meta__tables
data__samples
data__water
ref__taxa
calc__entry_checks
```

This is an example, not a required subject-matter schema. Create only the tables and helper views actually needed.

---

## 3. Rectangles, records, empty rows, and empty columns

### 3.1 The table boundary

Each `data__` and `ref__` worksheet contains a single contiguous table beginning at A1. Row 1 contains nonblank, unique headers; records begin in row 2. Each row represents the unit documented in `meta__tables`, and each column has one consistent meaning.

Do not put titles above the header, a second header row, units in a separate header row, repeated headers between batches, subtotals, footnotes, legends, charts, or another table beside or beneath the data. Move supporting material to a suitably prefixed sheet.

Do not merge cells. Do not use blank separator rows or columns, indentation, ditto marks, or a value entered once above several blank cells to mean “same as above.” Repeat an applicable recorded value on every record where it belongs; do not make the reader infer it from layout. General spreadsheet-organising guidance also recommends one rectangular table rather than embedded auxiliary material. [S2]

Sorting and filtering must act on complete records, not on an isolated subset of columns. A filtered view does not select which records are exported. Hidden rows and columns are still included according to their declared roles; hiding is never a data-exclusion instruction.

### 3.2 What “filled rectangle” means

**Rectangular completeness is structural, not a requirement that every measurement exists.**

| Situation | Required treatment |
|---|---|
| Entirely empty spacer row between records | Remove it upstream. Do not let the repository silently compact the table. |
| Empty separator column with no header or content | Remove it upstream. |
| Real row with a key but missing observations | Keep it. Record missingness according to section 6. |
| Real named variable whose observations are all missing | Keep it when the field remains part of the intended collection. Its absence of values is not proof that it is redundant. |
| Abandoned header-only placeholder column | Remove deliberately upstream when it is no longer part of the collection. Do not base automated deletion on an all-missing test. |
| Formula-only rows prefilled below the last real record | Remove or move the prefill upstream; they must not create apparent records without keys. |
| Blank grid outside the table | It is not data. It need not be physically deleted to the spreadsheet's maximum extent. |
| A declared table with headers but no records yet | It may represent a legitimate zero-row dataset. Retain its headers and key declaration, and report it as empty. |

Do not insert dummy values or fictional records to make the grid look full. Do not delete an incomplete real record merely because it causes validation to fail.

The extractor must determine the logical table from actual cell values, headers, and formula occupancy, not from the furthest styled cell. Formatting or data-validation ranges may extend into future entry rows without making those blank cells observations. A formula returning empty text is still a formula, not a genuinely unused cell.

### 3.3 Presentation-only sheets

`meta__` sheets should also use simple tables beginning at A1, with a single header row, so their documentation can be captured mechanically. Wrapped prose in a `value` or `description` cell is allowed. Avoid merged cells and spatial layouts that carry meaning.

Entirely excluded `calc__` sheets may contain charts or dashboard layouts when useful for data generation. Those layouts do not define the boundaries or contents of any raw table.

---

## 4. Keys without a relational rebuild

Every exported `data__` or `ref__` table declares a key field. The field is raw, is not prefixed `calc__`, and is present and nonmissing for each record.

Document what it identifies:

- `row`: the key identifies an individual record and must be unique within the table.
- `entity`: the key identifies a specimen, site, or other entity that may legitimately recur across observations; duplicates are not automatically errors.

Document any expected repetitions briefly. A table with an entity key need not acquire a synthetic row key solely to satisfy an unnecessary database design. Do not use the current row number or row position as the identity of an observation.

Store identifiers as literal text when leading zeros, long digit strings, case, or punctuation are part of identity. Set the entry cells to text before entering/importing such identifiers. A display format that makes `17` look like `00017` does not establish that the stored identifier is the text `00017`; Excel documents both automatic conversion risks and text-storage remedies. [S3]

Keep identifiers stable for the same identified object. A key-field rename or changed key interpretation requires an explicit upstream update of `meta__tables` and any affected ingestion configuration. This is part of the minimal contract, unlike ordinary non-key column drift.

Dropdowns may select a literal identifier from a reference table. Validation formulas that constrain such an entry do not make the selected literal value a calculated observation. A cell-value LOOKUP formula, however, belongs in a `calc__` field.

---

## 5. Raw fields and the `calc__` boundary

In `data__` and `ref__` worksheets, a column whose name begins with exact, case-sensitive `calc__` is excluded **in its entirety** from original/reference CSV output. Every other column is declared raw.

The prefix must remain present when formulas produce blanks, errors, unavailable cached results, or when a calculated field holds previously calculated literal values. A calculated result that becomes `NA` during export is still excluded by its header, not misrepresented as a missing raw observation.

Raw fields must not contain cell-value formulas, including arithmetic, unit-conversion, classification, or LOOKUP formulas. Spreadsheet-derived values pasted as literals into raw fields are also upstream infringements. Correct these in the source workbook; do not add repository exceptions, substitute missing values, delete selected cells or rows, or rename genuine raw observations as calculated merely to pass validation.

The exporter must not infer field roles from missingness, formula counts, colour, or the appearance of the values. Formula inspection is a validation safeguard. A detectable formula or spreadsheet error in a retained raw field blocks publication of the affected source build. Missing calculation results confined to excluded content do not invalidate otherwise valid raw extraction.

No importer can certify the editing history of a pasted literal when that history is absent from the export. Upstream permissions, practices, validation, and review remain responsible for such provenance.

**Formulas used by conditional-formatting rules or data-validation rules are not cell-value formulas.** They are permitted as editing aids as long as they do not replace raw cell contents or become the sole carrier of scientific information.

---

## 6. Values, units, numerical formats, and missingness

### 6.1 Numbers and units

Use a documented workbook locale that interprets a decimal point (`.`), and display data-entry numbers without thousands grouping. Synology documents workbook-level locale selection and number/date/time formatting; verify the chosen settings on the deployed instance. [S4]

For numeric fields:

- Enter numeric values as numbers, not strings containing units, spaces, explanatory text, or thousands separators. Use `1234.56`, not `1,234.56`, `1 234,56`, or `1234.56 mg/L`.
- Define one quantity, one unit, and one scale per field. A unit suffix is useful but not a substitute for documenting a scientifically ambiguous quantity.
- Do not overwrite original measurements with spreadsheet-calculated conversions. Keep the original quantity and put any source-side conversion in `calc__…`, or convert downstream.
- Use integers for genuinely integral counts. Zero is a measured or recorded zero, not a missing-value code.
- Preserve recorded precision. Display fewer decimal places only as a visual choice; never round and paste back into the raw field to achieve that appearance. If exact original decimal notation or measurement resolution matters, preserve it explicitly as reported text or metadata rather than relying on trailing zeros in the cell display.
- Scientific notation is acceptable for an actual numerical measurement when unambiguous; identifiers remain text.

Avoid percentage formatting in raw fields because it obscures the distinction between stored scale and visible scale. For newly defined fields, use a clearly named numeric scale, such as `_pct` with 0–100 or `_prop` with 0–1, and document it. Do not silently change the scale of an existing field to adopt this convention; any conversion must be explicit and must preserve the original observation.

A qualified result such as `<0.05` is not an ordinary number and is not equivalent to missingness, zero, or exactly `0.05`. Preserve the reported result in a clearly documented text field, or record the qualifier and limit in explicit fields when that is the source's chosen collection structure. Do not force censored observations into a misleading numeric representation.

### 6.2 Categories and text

Use one documented coding system per field. Prefer stable codes backed by `ref__` tables when a list is curated or shared. Do not mix equivalent new labels such as `female`, `Female`, and `femelle` in the same coded field. Do not silently recode genuine external identifiers or historical values merely to fit the default naming language.

A boolean field must use one defined representation consistently; do not mix logical values, 0/1, and yes/no labels without an explicit legacy explanation. Category ordering is not implied by colour or alphabetic order.

No leading or trailing whitespace in identifiers or controlled codes. Free-text notes may include normal punctuation, Unicode, and meaningful line breaks; preserve them using proper CSV quoting. Whitespace-only cells are not an approved missing-value representation.

One cell should contain one atomic value for the intended observation structure. Do not concatenate several independent sample IDs, measurements, or category memberships into a comma-separated cell to avoid recording the appropriate observations. A verbatim note or externally reported qualified result is a text value, not an instruction for the archive to split it automatically.

### 6.3 Missing observations

Use a genuinely blank cell for a missing raw observation. Do not introduce `NA`, `N/A`, `-`, zero, `999`, spaces, or a formula returning an empty string as interchangeable missing values.

Where an existing dataset has legitimate missing codes, document their exact scope and meaning in metadata and plan any correction upstream. The original-data extractor must not blindly turn every literal `NA` into missingness. Do not create new missing-code exceptions simply to avoid correcting invalid new entries.

If the reason matters, record it in an explicit field, for example `not_measured`, `not_applicable`, or `sample_lost`, with documented meanings. These are examples, not a mandatory global vocabulary. A reason code complements the blank measurement; it does not replace the measurement with an invented number.

The CSV writer's missing token is an output serialization decision, recorded in provenance. It is not an additional token that contributors should type into Synology. Genuine raw blanks and excluded calculation failures must never be merged in missing-data summaries.

---

## 7. Dates, times, durations, and timezone

### 7.1 Calendar dates

Use full calendar dates in year-month-day order, displayed and serialized as `YYYY-MM-DD`, for example `2026-09-07`. Do not use ambiguous slash dates, month names, two-digit years, or numeric date serials as the published representation.

For new full-date columns, native date cells displayed in this format are the default. A column of literal ISO-formatted date text is also acceptable when deliberately chosen and consistent; record that choice as a semantic exception, not as a second column-by-column schema. Do not mix native date cells, date serials, and arbitrary date text within a field.

A date-only value has no time of day or timezone. Do not append midnight and a timezone during serialization merely because an R reader represents it as a datetime. The converter must distinguish calendar dates from actual instants and validate the chosen export against known dates.

### 7.2 Times and timestamps

Use a 24-hour clock: `HH:MM` when minute precision is the observation, and `HH:MM:SS` when seconds are observed. Do not add fictitious seconds merely to make a column look uniform. Document precision when it affects interpretation.

Use `YYYY-MM-DDTHH:MM:SS` for fully specified date-and-time text, with the applicable timezone documented. For actual instants with a known UTC offset, the self-contained form `2026-09-07T14:30:00+00:00` or `2026-09-07T14:30:00Z` is appropriate; RFC 3339 defines this offset-bearing timestamp form. [S5]

A native spreadsheet datetime does not itself establish a timezone. `readxl` notes that Excel has no timezone model and uses UTC in its R representation; this is not evidence that the observation occurred in UTC. [S6] Specify the collection timezone in `meta__readme`, or per record when it varies. Use an IANA zone name where applicable. `Africa/Dakar` is an example for genuinely local observations, not an assumption to apply to every dataset in this folder.

Do not infer collection timezone from the server, the analyst's computer, or the date of export. If the timezone is unknown, say so; do not append `Z` or convert an unknown local time into an invented instant.

### 7.3 Partial dates and durations

Never turn a known month into the first day of that month, a known year into January 1, or an unknown time into midnight to satisfy formatting. Preserve the partial report and its precision explicitly, for example in a documented `collection_date_reported` text field and a precision field when needed. Such a field is not an exact `_date` field.

Record elapsed durations as quantities with a stated unit, for example seconds in `exposure_duration_s`, when that is how the observation is recorded. A duration is not a clock time and must not be allowed to wrap around at 24 hours. Spreadsheet-calculated durations belong in `calc__` fields; analytical durations are calculated downstream when needed.

---

## 8. Metadata without a second exhaustive schema

Use **one source-side location for each authoritative piece of metadata**. Do not copy a complete mutable column list into this folder README or maintain the same key mapping independently in several places.

### 8.1 Required small metadata sheets

`meta__readme` is a simple rectangular table with fields such as:

```text
item | value | description
```

Record the workbook ID, brief purpose, responsible curator/team, Synology source identifier or link, contract version, chosen locale, and temporal conventions/timezone where relevant. Include source-method references or access restrictions when necessary for proper use. Do not store credentials or access tokens in it.

`meta__tables` contains one row per `data__` or `ref__` worksheet:

```text
sheet_name | key_field | key_scope | record_unit | notes
```

Here `key_scope` is `row` or `entity`. `record_unit` states what a row represents; `notes` explains legitimate repetitions where relevant. The table is the source-side authority for the small key declaration. A future converter should read it directly rather than require a second hand-maintained mapping in its configuration.

Example entries:

| sheet_name | key_field | key_scope | record_unit | notes |
|---|---|---|---|---|
| `data__samples` | `sample_id` | `row` | One collected sample | Example only |
| `data__assays` | `sample_id` | `entity` | One assay observation | A sample may have repeated assay observations |
| `ref__taxa` | `taxon_code` | `row` | One curated taxon code | Example only |

These declarations specify keys and record meaning, not a relational schema. No foreign-key inventory or mandatory joins follow from them. A new exported table needs one key entry; adding an ordinary field does not.

### 8.2 Optional documentation, only when useful

| Sheet | Purpose |
|---|---|
| `meta__fields` | Selective definitions for ambiguous quantities, units, scales, missing codes, measurement precision, methods, and semantic exceptions. Not a required inventory of every column. |
| `meta__legend` | Meanings of source-side colours, conditional rules, flags, and their limits of interpretation. |
| `meta__methods` | Collection or instrument procedures and source references that are not more appropriately maintained in a separate protocol. |

A usable `meta__fields` table can contain `sheet_name`, `field_name`, `definition`, `unit`, and `notes`. Add rows where their meaning is necessary; do not require an exhaustive whitelist of fields before ingestion.

Authoritative lists of allowed codes and their meanings generally belong in `ref__` tables rather than in an informal colour legend. Human-facing explanations may include translated labels.

The archive generates its full observed field inventory, counts, types, exclusions, and change report from each export. These are provenance outputs, not an upstream schema that somebody must continually reconcile by hand. Important changes in quantity, scale, method, or key meaning still require human documentation; an automatic structural diff cannot recover those meanings.

---

## 9. Source-side visual formatting

These are editing and review conventions, not CSV appearance requirements.

Use a readable font, adequate column widths, wrapped long headers or notes, a distinct single header row, and frozen headers and key columns. Keep the key near the left of the table. Group raw fields coherently and place `calc__` helpers together, preferably to the right when practical. Use borders or shading to separate groups rather than blank columns.

Use a consistent, restrained visual system across workbooks. For example: a subtle key-field accent; an ordinary light background for editable raw fields; muted grey for calculated helpers; warning emphasis for possible issues; distinct emphasis for hard contract violations. These are recommended roles, not mandatory colour codes.

Do not make red-versus-green the only visible distinction. Combine colour with a written label, a flag, a rule message, or another cue where a user must interpret the state. The field name remains the authority for raw/calculated status.

Protect headers, keys where appropriate, and calculated ranges against inadvertent editing while leaving the intended entry fields editable. Synology documents range/sheet protection. [S7] Verify permissions and behaviour on the deployed installation; protection is an editing safeguard, not a substitute for an auditable source contract.

Do not store scientific meaning solely in bold, font colour, italics, comments, notes attached to cells, hidden state, or a border. Promote any necessary observation or adjudication to an explicit raw field; put general explanations in metadata. Comments may support a discussion but must not be the only surviving record of a decision relevant to analysis.

Number/date formatting needs special care: cosmetic styling is disposable, but numeric scale, native date interpretation, and identifier text storage affect meaning. The acceptance test must check stored values and types, not only whether the workbook looks correct.

---

## 10. Conditional formatting and entry validation

Use conditional formatting to make relevant patterns and possible errors easy to see. Use data validation to constrain entries when a hard rule is justified. Synology documents both conditional formatting and a data-validation option that rejects invalid input. [S8] A highlight alone does not prevent an invalid value.

Recommended source-side rules:

| Purpose | Rule or trigger | Interpretation |
|---|---|---|
| Missing key | A row contains a record but its declared key is blank. | Contract violation. A blank unused grid row is not a violation. |
| Duplicate row key | A nonblank key repeats where `key_scope` is `row`. | Contract violation. Do not apply to legitimate repeated entity keys. |
| Formula in a raw field | Observable cell-value formula outside a marked calculated column. | Contract violation; correct upstream. |
| Invalid code | A coded entry is outside the defined allowed values. | Reject when the list is authoritative; otherwise flag for review. |
| Type or impossible-value error | For example text in a defined numeric field or a negative integral count. | Hard validation only where the constraint is scientifically justified. |
| Unusual observation | A measurement exceeds a review threshold. | Review warning, not proof that the observation is wrong. Do not censor or replace it automatically. |
| Repeated observations | The same entity key occurs across legitimate replicates. | Structural aid, not an error. |
| Missingness with context | A measurement is blank when the recorded protocol requires it. | Review the actual acquisition requirement; do not label every blank as an error. |

A conditional rule may refer to formulas without placing formulas in raw cell values. A helper flag computed into a cell must use `calc__`, for example `calc__qc_flag`, and is excluded downstream. A curator's independently entered judgement can be a raw field such as `review_status`, with a documented meaning; it is not a licence to paste a computed flag into a raw column.

Record each scientifically meaningful visual rule in `meta__legend`, with a short description of its condition, applicable fields, severity, and any threshold/unit needed to interpret it. Avoid duplicating presentation-only details that do not affect understanding. Do not use an unexplained colour gradient as a biological classification.

Entry rules should be carried forward when records are appended. Styling and validation may cover future blank entry cells; do not prefill cell-value formulas far below existing records to achieve this. Check coverage after importing or pasting blocks and after structural edits. Test at least one known invalid value and one valid edge case when adopting a hard rule; do not assume highlighting or protection constitutes proof of validity.

---

## 11. Source maintenance, export, and publication

### 11.1 Contributor workflow

Maintain and correct the live source in Synology. Before exporting, check role prefixes, table boundaries, keys, stored identifier/date/number types, missing-value conventions, and outstanding hard violations. Remove structural spacer rows/columns and formula-only prefill, not real records with missing measurements.

Ordinary raw fields may be added, removed, renamed, or reordered without revising an exhaustive schema. Follow the naming and provenance conventions from the moment a field is created. Update selective semantic metadata when interpretation changes. Adding or renaming a table or key requires updating `meta__tables`.

Export directly to the validated ODS or XLSX format and complete the download before ingestion starts. Do not open/resave the download or edit generated CSVs to repair source errors. Correct Synology, export again, and let the changed digest trigger a fresh ingestion attempt.

### 11.2 Required behaviour of the revised extractor

1. Retain each completed accepted download byte-for-byte and calculate SHA-256. Retention is evidence preservation, not a certificate of validity.
2. Read the worksheet role prefixes and essential metadata. Reject unknown roles rather than guess. Record all discovered worksheets, including excluded and documentation sheets.
3. For each `data__` or `ref__` worksheet, identify the logical rectangle, enforce names and declared keys, and exclude `calc__` fields before interpreting raw missingness. Audit the excluded fields.
4. Validate observable conditions in retained fields, including formulas, spreadsheet errors, header structure, and key requirements. Report the workbook, sheet, field, and cell or record when possible. Do not infer that undetectable editing history has been certified.
5. Serialize the retained raw values under explicit CSV rules, including text escaping, decimal representation, missing tokens, and date/time conventions. Preserve identifiers and meaningful literal text; do not silently repair or recode them.
6. Catalogue observation CSVs, reference CSVs, and documentation sidecars with distinct roles. Keep source and output digests, field inventories, and structural changes. Reference preservation does not imply joins.
7. Publish a coherent validated build only after its required checks succeed. On failure, retain diagnostics and the snapshot while keeping the last validated publication current. Do not mix new and old parts of a source workbook into a supposedly current successful build.

Changes to workbook bytes, relevant extraction code, configuration, or the adopted machine-relevant contract rules must invalidate the appropriate builds. The SHA-256 check is performed on each pipeline invocation; it is not a continuous filesystem watcher.

Presentation-only deviations can be advisory unless they conceal or alter meaning. Missing calculation results in excluded content need not block valid raw-data extraction. Loss or alteration of raw values, headers, roles, or essential key/temporal metadata makes an export unacceptable.

### 11.3 Export acceptance test

Before adopting an export format, compare representative source values with the exported package and resulting CSVs. Include text identifiers with zeros, large digit strings, decimals, genuine blanks, literal strings resembling missing codes, Unicode, quoted text, full and partial dates where present, times, calculated fields without usable results, and reference/metadata sheets.

Check stored values, worksheet/field names, types, and dimensions rather than only the visual appearance. Missing calculated results are acceptable because the fields are excluded by name; missing or damaged raw observations are not. Repeat the acceptance check after a material source/exporter/reader change.

---

## 12. Adoption and maintenance of this contract

This draft extends version 1.0 with worksheet roles, naming and value conventions, lightweight metadata, and source-side presentation rules. Adopting role prefixes is a deliberate migration, not something the archiving repository should silently perform.

Retain a pre-migration source snapshot; rename and classify existing workbooks/sheets/fields upstream; populate the small key metadata; correct source violations without overwriting observations with calculated replacements; test an export; then activate the matching converter rules. Changing a prefix is not a legitimate shortcut for discarding difficult observations.

Keep the shared contract text/version consistent across dataset folders. Maintain workbook-specific information in `meta__readme` and `meta__tables`, and only necessary semantic details in optional metadata. Do not copy mutable inventories into every folder README.

**This document does not claim that any Synology server, workbook, or R pipeline has already been modified or validated.**

## Sources and rationale

The exact prefixes, role mapping, language convention, minimal metadata layout, and failure/publication policy are project design choices. External sources below support specific format constraints, software capabilities, or general organisation principles, not every policy choice. In particular, this contract deliberately permits genuine blank observations and all-missing named variables; it does not require inventing values to fill every cell.

- **[S1] Microsoft Support.** *Rename a worksheet.* Excel worksheet-name constraints, including the 31-character limit. <https://support.microsoft.com/en-us/excel/rename-a-worksheet>
- **[S2] Broman, K. W., and Woo, K. H. (2018).** *Data organization in spreadsheets.* The American Statistician 72(1): 2–10. DOI: 10.1080/00031305.2017.1375989. Author-maintained companion, especially “Make it a rectangle”: <https://kbroman.org/dataorg/pages/rectangle.html>
- **[S3] Microsoft Support.** *Keeping leading zeros and large numbers.* <https://support.microsoft.com/en-us/excel/keeping-leading-zeros-and-large-numbers>
- **[S4] Synology Knowledge Center.** *Formatting Data*, Synology Office, DSM 7. Workbook locale and number/date/time formatting. <https://kb.synology.com/en-global/DSM/help/Spreadsheet/sheet_formatting_data?version=7>
- **[S5] IETF / RFC Editor.** *RFC 3339: Date and Time on the Internet: Timestamps.* <https://www.rfc-editor.org/info/rfc3339/>
- **[S6] readxl documentation.** *Cell and Column Types.* Date/time representation and the absence of an Excel timezone model. <https://readxl.tidyverse.org/articles/cell-and-column-types.html>
- **[S7] Synology Knowledge Center.** *Protecting a Range or Sheet*, Synology Office, DSM 7. <https://kb.synology.com/en-global/DSM/help/Spreadsheet/sheet_protecting_a_range_or_sheet?version=7>
- **[S8] Synology Knowledge Center.** *Working with Data*, Synology Office, DSM 7. Data validation and conditional formatting. <https://kb.synology.com/en-global/DSM/help/Spreadsheet/sheet_working_with_data?version=7>

Documentation consulted on 2026-09-07. Verify feature availability and exact controls on the installed Synology Office version before operational adoption.
