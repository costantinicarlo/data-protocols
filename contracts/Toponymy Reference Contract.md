# Toponymy Reference Contract

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

---

## 6. OSM disagreement or error

OSM is a reference system, not an assumption of correctness.

Where reliable evidence indicates that an OSM name or geographical entity is erroneous, the discrepancy SHOULD be investigated rather than propagated automatically.

Where appropriate and consistent with OSM policies, verified local or authoritative information SHOULD be used to correct or enrich OSM. This is preferable to maintaining an unnecessary private geographical nomenclature that cannot be resolved outside the project.

Until a discrepancy is resolved, the project MAY retain both the OSM reference and the independently supported name, with the disagreement explicitly documented.

---

## 7. Geographical entities absent from OSM

Absence from OSM does not imply that a geographical entity does not exist or that its locally established name is invalid.

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

For geographical entities that are important analytical or sampling units, the following information SHOULD be retained where practicable:

```yaml
locality_id: SEN-XXXX
name: "Canonical toponym"

reference:
  system: OpenStreetMap
  osm_type: node
  osm_id: 000000000
  verified: YYYY-MM-DD

coordinates:
  latitude: 00.000000
  longitude: 00.000000

alternative_names:
  - "Alternative spelling"
  - "Local or historical name"
```

Not every scientific output needs to expose all these fields. The underlying curated data SHOULD nevertheless retain sufficient information to reconstruct the geographical reference.

Coordinates MUST NOT be publicly disclosed where legitimate scientific, conservation, ethical, legal, security or privacy considerations require geographical information to be generalized or withheld.

---

## 12. Citation and reporting

A scientific report or publication does not need to cite OSM repeatedly for every occurrence of a standardized place name.

Where toponymic standardization is methodologically relevant, the Methods, data documentation, repository documentation or equivalent SHOULD state that geographical names were standardized against OpenStreetMap and give the relevant date or period of verification.

Where the identity or naming of a particular geographical entity is disputed, unusual, or scientifically important, its specific OSM reference and relevant alternative evidence SHOULD be documented explicitly.

---

## 13. Governing rule

When choosing between competing toponyms, ask first:

> **Which representation gives an independent reader the clearest globally accessible and reproducible anchor to the geographical entity meant by this scientific record?**

Under this contract, OpenStreetMap provides the default answer.

Local usage, national authorities, historical documents and other sources remain essential evidence about geographical names. They complement the common reference rather than being discarded by it.

**The objective is not to impose a universal name on a place. It is to make every geographical reference in the scientific record independently resolvable.**