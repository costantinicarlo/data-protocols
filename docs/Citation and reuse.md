# Citation and reuse

## Purpose

A citation to `data-protocols` identifies the data-handling rules adopted by a study and makes those rules inspectable. The repository contains both written contracts and executable utilities. Following a contract does not imply that the supplied utility was used; executing a validator does not establish compliance with requirements outside its assessed evidence.

Use the [repository citation metadata](../CITATION.cff) and cite the particular release or full Git commit actually adopted, rather than an unspecified moving branch. Name the applicable contracts and describe any study-specific departures in the dataset documentation. Retain implementation revisions, configuration, findings, and run manifests when the utilities are used.

These are recommendations for methodological traceability, not additional conditions of the [MIT License](../LICENSE). Preserve the notices required by that licence independently of any scholarly citation. External data may need its own attribution: see [Third-party notices](../THIRD_PARTY_NOTICES.md).

## What to cite

The repository-wide bibliographic title is **data-protocols: Data standard operating protocols**. Use the authors and version metadata in `CITATION.cff` from the adopted release. A single repository citation can support multiple applicable contracts; listing those contracts in the study documentation makes the adopted scope explicit without creating a separate bibliography entry for every file.

A repository release, a utility's internal version, and a contract's declared version are different identifiers. Do not cite generator version `1.1.2` as though it were the repository release `0.1.0`. Full commit references remain useful when a contract is unversioned or when a study deliberately uses an unreleased revision. Keep local modifications or adopted deviations separately identified; do not describe patched content as byte-identical to upstream.

Where an archive has assigned a DOI for the exact release, use that version-specific identifier and retain the corresponding Git revision in the study provenance. A DOI is not required to begin citing an inspectable Git revision. Do not invent a DOI or a publication date while preparing a release.

## Example Methods wording

The following are templates. Replace the bracketed fields with the actual study information, and keep only claims supported by the study's evidence.

**Contracts adopted; no claim about the implementation:**

> Data curation and exchange followed the applicable contracts in *data-protocols: Data standard operating protocols*, version [repository version] ([bibliographic citation]). The adopted contracts and any study-specific departures are identified in the dataset documentation.

**Contracts and supplied utilities used:**

> Data handling followed the applicable contracts in *data-protocols*, version [repository version] ([bibliographic citation]). Source workbooks were retained unchanged and processed using implementation revision [full commit]. The dataset provenance records the configuration, assessed checks, findings, and any requirements requiring separate source-side review.

**An unreleased revision adopted:**

> Data handling followed the specified contracts in *data-protocols* at Git commit [full commit] ([bibliographic citation]). The dataset documentation identifies the applicable contract files and any departures from that snapshot.

A successful process exit is not a claim that every requirement was assessed, that every geographical identity was human-reviewed, or that the scientific observations are true. Match the Methods wording to the actual coverage.

## Citation metadata at release time

`CITATION.cff` is the maintained bibliographic source. Its initial `version` field is prepared for the forthcoming repository release `0.1.0`; the file alone is not evidence that the release already exists.

In the release-preparation commit, confirm the authors and title, set the actual repository version, and add `date-released` as a quoted ISO date. Add an ORCID or DOI only when verified. Do not put the hash of the very commit containing the file into that file: that would create a self-reference. The release tag and external study manifest can identify the final commit.

After publication, obtain BibTeX from GitHub's **Cite this repository** control or generate it from `CITATION.cff`, then import it into the study's bibliography. Check that its version and date correspond to the release actually used. A study-specific BibTeX record should resolve to that release, archived snapshot, or full commit, not merely the latest default branch. Keep that bibliographic record with the paper rather than maintaining a second manually synchronised citation file in this repository.

The expected reference structure, once the release exists, is:

> Costantini, C. ([release year]). *data-protocols: Data standard operating protocols* (Version [repository version]). [Exact release or archive reference].

## Adapting the contracts

The MIT licence permits adaptation. Documenting the upstream version and the changes makes an adapted protocol interpretable; it does not turn that adaptation into an official upstream revision. Keep permission to reuse, scientific credit, and evidence of compliance as separate questions.

## Format and licence references

[GitHub's citation-file documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-citation-files) explains the `CITATION.cff` integration and supported citation exports. The [Citation File Format](https://citation-file-format.github.io/) specifies the metadata format. The [standard MIT licence](https://opensource.org/license/mit) provides the permission and disclaimer text used by this repository.
