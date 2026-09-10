# Licensing scope and third-party notices

## Original project material

Unless an item carries a different notice, the repository's original source code, scientific protocol documents, narrative documentation, configuration, workflow files, and original synthetic examples and test fixtures are covered by the [MIT License](LICENSE). Reusable code examples within the documentation are covered by the same licence. There is no separate Creative Commons licence for the project's original protocol text.

This scope statement identifies the material covered by the licence; it does not add conditions to or modify the standard MIT licence text. Third-party material is not relicensed merely because it is stored in this repository.

## Country-code reference table

`references/iso3166.tab` is an upstream country-code table distributed with the IANA time-zone database. Its retained header declares the file to be in the public domain and attributes that clarification to Arthur David Olson on 2009-05-17. The bundled header also records Paul Eggert's 2025-07-01 description and the underlying 2024-02-29 country-code reference.

Preserve the [file's upstream notice](references/iso3166.tab) and provenance. The project's MIT copyright notice does not assert ownership of this table. The table's public-domain notice should not be generalised to other ISO publications or other files that have their own terms.

## OpenStreetMap-derived material

OpenStreetMap data is made available by the OpenStreetMap Foundation under the [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/). Retain the applicable attribution to **OpenStreetMap contributors** and identify the data licence when sharing OSM-derived material. Consult the [OSM copyright page](https://www.openstreetmap.org/copyright) and [attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines) for the intended form of redistribution.

This includes relevant OSM-derived content in historical example outputs such as `examples/input_data.toponyms.geojson`, and in response caches or enriched outputs when redistributed. MIT licensing of the resolver does not replace these data terms. The treatment of a particular database, extract, or produced work depends on its contents and use; this notice does not declare every output, or every field in an output, to be ODbL-licensed.

A citation to `data-protocols` is not a substitute for OSM attribution. Synthetic placeholders are not evidence that an OSM object was retrieved or verified; follow each example's stated provenance.

## User-supplied data and dependencies

Running these tools does not, by itself, change the rights, confidentiality, or access restrictions applicable to source workbooks, observations, or externally supplied reference files. The project licence grants no rights in such material on behalf of its owners. Original measurements remain distinct from externally retrieved geographical data.

R, Python, installed packages, and external workflow actions retain their own licences. A dependency declaration does not relicense those components. When redistributing dependency source, binaries, containers, or other third-party material, retain and comply with the applicable notices and terms for the versions actually distributed.

## Maintenance

Retain existing notices when replacing reference snapshots or adding external material, and extend this inventory where needed. Do not remove a third-party notice in order to make the repository appear uniformly MIT-licensed.

For scholarly citation and descriptions of contract adoption, see [Citation and reuse](docs/Citation%20and%20reuse.md). For the exact permission and disclaimer terms covering original project material, see [LICENSE](LICENSE).
