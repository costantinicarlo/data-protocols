# Toponymy Reference Contract

**Document revised:** 2026-09-07

**Implementation reference:** [osm_toponym.R](../src/osm_toponym.R), generator version `1.1.2`; see the separately recorded [immutable component pins](../README.md#pinning-source-code-and-contracts).

**Versioning:** This contract has no declared semantic version. Pin its own Git revision separately from the utility's revision; a utility source commit does not identify this contract revision.

## Purpose

This document defines the reference convention for geographical names used in scientific work.

The contract applies to **all representations of project information**, including source workbooks, tabular datasets, databases, analysis files, maps, figures, reports, manuscripts, publications, repositories, metadata records, archived datasets, and shared data objects.

Its purpose is not to determine the legally, administratively, historically, or locally "correct" name of a geographical entity. Its purpose is to ensure that a geographical name used in scientific work provides a **stable and independently accessible reference anchor that can be resolved by a reader anywhere in the world**.

Accordingly, accessibility and reproducibility take precedence over institutional authority when selecting the reference form of a toponym.

---

## 1. Primary reference system

**OpenStreetMap (OSM) is the default reference system for toponymy.**

Where an appropriate geographical entity exists in OSM:

1. the project's standard toponym SHOULD correspond to the name of that entity in OSM;
2. the OSM object SHOULD be regarded as the external geographical reference for the entity;
3. where provenance is recorded, the OSM object type and identifier SHOULD be retained;
4. for curated or archival datasets, the date on which the OSM reference was verified SHOULD also be retained where practicable.

The canonical reference therefore consists, where possible, of both:

> **OSM geographical entity + toponym**

rather than the character string of the name alone.

This distinction is essential because names can change, spelling can be corrected, and homonymous places can exist, while the referenced geographical entity remains the same.

### 1.1 Choose an anchor appropriate to the entity

For a settlement or named locality, an appropriate OSM `place=*` node SHOULD be preferred when it can be established without guessing. A reverse-geocoding result representing an administrative boundary or another surrounding feature may provide useful context without identifying the locality itself.

This preference is specific to locality resolution. A node MUST NOT automatically replace a way or relation when the scientific entity of interest is an area, boundary, river, or another feature represented by that object. The geographical meaning of the entity takes precedence over its OSM object type.

Nominatim and Overpass are retrieval tools used by the current utility; OSM remains the reference system. An automated selection is a proposed reference anchor subject to this contract, not independent authority for the name or identity of a place.

---

## 2. Rationale

A scientific toponym must allow an independent reader to determine which geographical entity is being referenced.

The preferred reference system should therefore be:

- globally accessible;
- freely searchable;
- non-proprietary;
- usable without institutional credentials;
- geographically explicit;
- capable of distinguishing homonymous entities;
- capable of representing alternative, historical, local and language-specific names;
- inspectable and correctable;
- sufficiently persistent to support reproducible scientific work.

OSM is adopted as the default because it satisfies these requirements particularly well and provides a common geographical reference independent of commercial mapping providers and of national information systems that may not be universally accessible.

The choice of OSM **does not imply that OSM is intrinsically more authoritative than local knowledge or competent national authorities**. It establishes OSM as the common *reference namespace* used by the scientific work.

---

## 3. Referenceability and authority are distinct

The following questions MUST NOT be conflated:

> **What is the locally or officially authoritative name of this place?**

and

> **What globally accessible reference allows another person to identify the place meant by this scientific record?**

Local usage may provide the strongest evidence concerning the actual name of a locality. A competent national authority may define its official administrative name. Historical sources may establish earlier forms.

These are valuable evidence, but they do not necessarily provide a universally accessible scientific reference.

Consequently, local, governmental, historical and other sources MAY be used to verify, interpret, correct or enrich a toponym without replacing OSM as the project's normal external reference system.

---

## 4. Geographical identity is independent of spelling

A geographical entity MUST NOT be identified solely by the character string used as its name.

Homonymy is common, and orthography can vary substantially between languages, administrative traditions, historical sources and local usage.

Where relevant, geographical identity SHOULD therefore be established using a combination of:

- a stable project locality or geographical-entity identifier;
- the OSM object identifier;
- geographical coordinates;
- administrative or geographical context.

For example, two settlements carrying the same name remain distinct geographical entities and MUST receive distinct project identifiers.

Changes in spelling MUST NOT be interpreted as changes in geographical identity.

The input record identifier and the selected OSM identifier serve different purposes. Several sampling records MAY share one locality anchor without becoming the same scientific record. A change in selected OSM object MUST NOT silently change the project record's identity.

Sampling coordinates and OSM anchor coordinates MUST remain distinguishable. Selecting a locality node does not relocate the observation or establish that it occurred at that node. The utility's GeoJSON geometry represents the selected anchor, while `query_latitude` and `query_longitude` retain the supplied coordinates. Its point representation of a fallback way or relation does not supply that object's boundary geometry.

---

## 5. Canonical and alternative names

Where several names or spellings refer to the same geographical entity, one form SHOULD be designated as the **canonical project toponym**.

Unless there is a documented reason otherwise, this SHOULD be the current OSM name.

Alternative forms MAY be retained as metadata, including:

- local names;
- alternative spellings;
- official names;
- language-specific names;
- historical names;
- names appearing in original field records.

Alternative names MUST NOT be silently substituted for one another during data processing when doing so would destroy provenance.

In particular, the original spelling contained in immutable or archival source records SHOULD be preserved even when the standardized project toponym differs.

Normalisation MAY be used to compare names, including case folding, transliteration, and punctuation/whitespace handling. A normalised comparison string MUST NOT replace the original source spelling or the chosen OSM name in curated data. Equality after normalisation is evidence of name compatibility, not proof of geographical identity.

---

## 6. OSM disagreement or error

OSM is a reference system, not an assumption of correctness.

Where reliable evidence indicates that an OSM name or geographical entity is erroneous, the discrepancy SHOULD be investigated rather than propagated automatically.

Where appropriate and consistent with OSM policies, verified local or authoritative information SHOULD be used to correct or enrich OSM. This is preferable to maintaining an unnecessary private geographical nomenclature that cannot be resolved outside the project.

Until a discrepancy is resolved, the project MAY retain both the OSM reference and the independently supported name, with the disagreement explicitly documented.

---

## 7. Geographical entities absent from OSM

Absence from OSM does not imply that a geographical entity does not exist or that its locally established name is invalid.

A failed service request, an empty search within a configured radius, or an inability to match a name MUST NOT be interpreted as proof that the entity is absent from OSM. Investigate the scope and outcome of the lookup before applying the absence procedure below.

When an entity is absent:

1. its identity SHOULD be established from available geographical evidence;
2. its coordinates and project identifier SHOULD be recorded;
3. its locally established or otherwise best-supported name MAY be used;
4. the source of that name SHOULD be documented where practicable.

If the entity legitimately belongs in OSM and sufficient evidence exists, contributing it to OSM is encouraged. This converts otherwise locally restricted geographical knowledge into a globally accessible reference.

Project-defined analytical constructs, sampling units, clusters, study zones, or other entities that are not genuine geographical features MUST NOT be added to OSM merely to obtain an external identifier.

---

## 8. National and governmental sources

Sources produced by competent authorities of the country concerned are important evidence and SHOULD be preferred when the objective is specifically to establish an **official** administrative name or boundary.

They MAY also be used to validate or correct OSM.

However, an inaccessible governmental source SHOULD NOT normally determine the canonical scientific toponym solely by virtue of its official status. A reference that cannot reasonably be inspected by independent readers does not fulfil the principal purpose of this contract.

Governmental authority and scientific referenceability are therefore recorded separately where necessary.

---

## 9. Proprietary geographical services

Commercial or proprietary mapping services MAY be consulted for investigation or corroboration where legally and scientifically appropriate.

They SHOULD NOT normally constitute the primary authority for project toponymy when an adequate open reference exists.

In particular, a spelling found only in a proprietary geographical service MUST NOT automatically override the OSM reference.

This convention avoids making access to scientific geographical references dependent upon a particular commercial provider, account, licence, jurisdiction, or future availability of a proprietary service.

---

## 10. Application across scientific objects

This contract applies consistently regardless of medium.

A locality appearing in a source workbook, derived CSV file, analysis table, GIS layer, figure, manuscript, repository, data publication, supplementary file or metadata record SHOULD use the same canonical project toponym.

Consequently, toponymic standardization SHOULD occur as far upstream as is compatible with preservation of original source information.

Derived scientific objects SHOULD NOT independently introduce new spellings or alternative names without documented justification.

Where abbreviated labels are required for figures, maps or tables, the abbreviation MAY differ from the canonical name for presentation purposes, provided that the geographical identity remains unambiguous.

---

## 11. Recommended provenance

### 11.1 Curated reference record

For geographical entities that are important analytical or sampling units, the following information SHOULD be retained where practicable:

```yaml
locality_id: SEN-XXXX
name: "Canonical toponym"

reference:
  system: OpenStreetMap
  osm_type: node
  osm_id: "000000000"  # Illustrative placeholder, not a verified object.
  verified: YYYY-MM-DD

query_coordinates:
  latitude: 00.000000
  longitude: 00.000000

osm_anchor_coordinates:
  latitude: 00.000000
  longitude: 00.000000

alternative_names:
  - "Alternative spelling"
  - "Local or historical name"
```

Not every scientific output needs to expose all these fields. The underlying curated data SHOULD nevertheless retain sufficient information to reconstruct the geographical reference.

In a curated record, document what `verified` means and who or what performed the verification. The utility currently populates its `verified` field with the **run date**, including for cached responses and unresolved records. It MUST NOT be presented as the date of fresh API retrieval or human verification. Record human review and its date separately where performed; do not infer review from a successful process exit or an automated status.

Coordinates MUST NOT be publicly disclosed where legitimate scientific, conservation, ethical, legal, security or privacy considerations require geographical information to be generalized or withheld.

### 11.2 Current automated resolution procedure

The following describes the implemented engine in version `1.1.2`. Search parameters are implementation defaults, not universal geographical definitions or guarantees of a correct match.

1. Reverse-geocode the supplied coordinates with Nominatim at zoom 15, requesting address and name details.
2. If the returned object has `osm_type = node` and `category = place`, retain it directly. This branch does not perform an Overpass search, check the 5 km search radius, or restrict the place subtype to the Overpass list below. It can therefore retain neighbourhood nodes as well as settlements.
3. Otherwise, use Overpass to search within 5,000 metres of the supplied coordinates for named nodes with `place` equal to `city`, `town`, `village`, `hamlet`, `isolated_dwelling`, or `locality`.
4. Collect target names from the Nominatim object's name, settlement-related address components, and name details. Compare them with each node's `name`, alternative/local/official/short/historical names, and language-specific `name:*` tags. Node-name values separated by semicolons are considered individually. Matching uses equality after transliteration where possible, lowercasing, and punctuation/whitespace normalisation; it is not fuzzy spelling matching.
5. Select an Overpass node only when exactly one candidate has a compatible name. Retain its `name` spelling. If multiple candidates match, retain the original Nominatim object and flag ambiguity. Candidates are ordered by distance for inspection; neither closeness nor settlement class breaks the ambiguity.
6. If no candidate matches, retain the original Nominatim object as a fallback. Preserve its original object reference even when a place node replaces it.

The utility does not independently validate administrative containment, source-locality identity, or the scientific suitability of a directly returned place node. These remain matters for review. A configurable search radius bounds a lookup; it does not define locality membership or positional accuracy.

### 11.3 Outcome interpretation and review

| Utility status | Meaning | Contract interpretation |
| --- | --- | --- |
| `node_exact` | A Nominatim place node was retained directly, or exactly one name-compatible Overpass node was selected. | An automated node selection. “Exact” does not certify human verification, sampling-location accuracy, or identity beyond the lookup's evidence. |
| `osm_fallback` | No matching place node was established; the original Nominatim object was retained. | Preserve the available reference and review its suitability for the intended entity before adopting it as canonical. |
| `ambiguous` | Multiple name-compatible nodes were found; the original Nominatim object was retained. | Preserve the alternatives and uncertainty. Do not silently promote the nearest candidate or treat the fallback as a resolved locality identity. |
| `unresolved` | A caught error prevented completion of the lookup. | Preserve the source record and error. Do not invent a reference or interpret service failure as geographical absence. |

Uncertainty MUST survive downstream transformations until a documented adjudication resolves it. A curator MAY adopt or replace an automated anchor using geographical evidence, recording the reason and the previous reference. Automated output MUST NOT silently overwrite independently reviewed locality identities.

HTTP access denials and exhausted rate-limit responses stop the current utility's batch; they do not produce a new completed output. Other caught failures produce unresolved records and a nonzero exit status. Consumers MUST check that an output belongs to the intended run: an existing GeoJSON file can be left unchanged after a failed invocation. Service access requirements and operational commands are maintained in the [repository README](../README.md).

### 11.4 Reproducible execution and evidence

For automated standardisation, provenance SHOULD include the input record ID, supplied coordinates, selected OSM type/ID/name, resolution status and method, original Nominatim object reference, candidate summaries where available, and any subsequent review decision. Retain the distance to the anchor where supplied; it is not a confidence score.

The utility exposes these through fields including `source_id`, `query_latitude`, `query_longitude`, `osm_type`, `osm_id`, `name`, `status`, `resolution_method`, `reverse_osm_type`, `reverse_osm_id`, `reverse_osm_url`, `candidate_place_nodes`, and `distance_to_osm_anchor_m`. The GeoJSON is a summary; it does not contain every source tag or the full API responses.

For reproducible or archival work, retain the successful response caches and record the utility commit, contract commit, execution configuration and dependencies, input/output digests, and run time. A generator version string alone does not identify the executed source or any local modifications. Pinning source code alone does not freeze external geographical data.

Cache reuse SHOULD preserve the evidence used in a run. The current utility does not expire cached responses automatically or record their original retrieval time in the GeoJSON. Its cache keys also omit service endpoints and some matching configuration. Document whether responses were reused or refreshed, and separate caches when changing assumptions that their keys do not distinguish. A deliberate refresh or new matching rule SHOULD trigger review of changed anchors rather than an unexplained replacement of curated references.

---

## 12. Citation and reporting

A scientific report or publication does not need to cite OSM repeatedly for every occurrence of a standardized place name.

Where toponymic standardization is methodologically relevant, the Methods, data documentation, repository documentation or equivalent SHOULD state that geographical names were standardized against OpenStreetMap and give the relevant date or period of verification.

When the utility is used, distinguish the automated lookup/run period from human review, and identify the pinned implementation and contract in the underlying provenance. Report retained uncertainty where it affects interpretation; do not describe all `node_exact` records as independently verified localities.

Where the identity or naming of a particular geographical entity is disputed, unusual, or scientifically important, its specific OSM reference and relevant alternative evidence SHOULD be documented explicitly.

---

## 13. Governing rule

When choosing between competing toponyms, ask first:

> **Which representation gives an independent reader the clearest globally accessible and reproducible anchor to the geographical entity meant by this scientific record?**

Under this contract, OpenStreetMap provides the default answer.

Local usage, national authorities, historical documents and other sources remain essential evidence about geographical names. They complement the common reference rather than being discarded by it.

**The objective is not to impose a universal name on a place. It is to make every geographical reference in the scientific record independently resolvable.**

### Implementation correction notes (generator 1.1.2)

A completed Overpass search requires a valid response envelope and candidate array. Nonempty remarks, including unknown remarks, invalidate a fresh or cached search; partial candidates cannot prove uniqueness. Failed old caches are retained separately with failure markers. Only genuine successful empty searches may support fallback. Standalone input identifiers are read as exact UTF-8 strings, including missing-token-like literals, with full input validation before requests. The explicit request loop spaces actual attempts, retries included, within bounded time/attempt limits and server guidance. See the [implementation guide](../README.md#release-candidate-hardening) for supported scope. The legacy `verified` field retains its run-date meaning and does not imply human review.
