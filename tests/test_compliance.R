#!/usr/bin/env Rscript
run_compliance_tests <- function() {
old_options <- options(httr2_mock = function(req) stop("Unexpected public request during offline tests"))
old_wd <- getwd()
on.exit({options(old_options); setwd(old_wd)}, add = TRUE)
stopifnot(requireNamespace("httr2", quietly = TRUE))
root <- normalizePath(".")
source("src/compliance/load.R")
load_compliance(root)
work <- tempfile("workbook-compliance-tests-"); dir.create(work)
on.exit(unlink(work, recursive = TRUE), add = TRUE)
fixtures <- file.path(work, "fixtures")
status <- system2("python3", c(shQuote(file.path(root, "tests", "make_workbook_fixtures.py")), shQuote(fixtures)))
stopifnot(status == 0L)
check <- function(condition, message) if (!isTRUE(condition)) stop(message, call. = FALSE)
run <- function(variant, format, state = file.path(work, format), config = list(), stage = "all") {
  suppressMessages(run_compliance(file.path(fixtures, paste0(variant, ".", format)), state, "demo_collection", config, stage = stage))
}
for (format in c("xlsx", "ods")) {
  first <- run("valid", format)
  check(first$exit_status == 0L, paste("Valid fixture failed", format, paste(vapply(first$context$findings, `[[`, character(1), "message"), collapse = "; ")))
  publication <- file.path(work, format, "demo_collection", "current.json")
  pointer <- read_json(publication)
  check(first$manifest$snapshot$sha256 == sha_file(file.path(fixtures, paste0("valid.", format))), "Snapshot is not byte-identical")
  original <- read.csv(file.path(pointer$run_dir, "original", "data__samples.csv"), colClasses = "character", na.strings = "\\N", check.names = FALSE)
  check(identical(original$sample_id, c("SN26_00001", "SN26_00002")), "Identifiers changed")
  check(!"calc__helper" %in% names(original), "Calculated column leaked")
  check(nrow(original) == 2L && all(is.na(original$optional)), "All-missing field or real rows lost")
  check(original$note[2] == "NA", "Literal NA was converted to missing")
  check(original$note[1] == 'Médina  Djikoye\nquoted "note"\tend', "Rich text/Unicode changed")
  check(identical(original$collection_date, c("2026-09-07", "2026-09-08")), "Native dates changed")
  derived <- read.csv(file.path(pointer$run_dir, "derived", "data__samples__coordinates.csv"))
  check(abs(derived$latitude_dd[2] - 13.5) < 1e-12 && abs(derived$longitude_dd[2] + 16.2) < 1e-12, "DMS conversion incorrect")
  repeat_run <- run("valid", format)
  check(!repeat_run$manifest$source_changed && !repeat_run$manifest$build_inputs_changed, "Unchanged download not recognised")
  check(repeat_run$manifest$build_signature == first$manifest$build_signature, "Same inputs have different signatures")
  reconfigured <- run("valid", format, config = list(max_cells = 900000))
  check(!reconfigured$manifest$source_changed && reconfigured$manifest$build_inputs_changed, "Config change did not invalidate build inputs")
  changed <- run("changed", format)
  check(changed$exit_status == 0L && changed$manifest$source_changed, "Changed download not ingested")
  changes <- read_json(file.path(changed$manifest$run_dir, "changes.json"))
  check("SN26_00003" %in% unlist(changes$sheets$data__samples$records$added_ids), "New record not detected")
  check("SN26_00002" %in% unlist(changes$sheets$data__samples$records$modified_ids), "Changed observation not detected")
  latest_valid <- read_json(publication)
  for (variant in c("formula", "duplicate", "coordinate", "numeric_id", "zero_serial", "spacer", "bad_date", "whitespace", "missing_crs", "unknown_role", "merged", "cell_error")) {
    failure <- run(variant, format)
    check(failure$exit_status == 2L, paste("Invalid fixture published:", format, variant))
    check(identical(read_json(publication), latest_valid), paste("Failure replaced current publication:", variant))
    check(file.exists(file.path(failure$manifest$run_dir, "findings.json")), "Failure diagnostics missing")
    check(!dir.exists(file.path(failure$manifest$run_dir, "original")), "Invalid workbook produced original publication tables")
  }
  for (variant in c("native_times", "date1904", "shared_strings", "empty")) {
    additional <- run(variant, format)
    check(additional$exit_status == 0L, paste("Additional fixture failed:", format, variant, paste(vapply(additional$context$findings, `[[`, character(1), "message"), collapse = "; ")))
    if (variant == "native_times") {
      t <- additional$context$tables$data__samples$data
      check(t$observation_time[1] == "13:30:00", "Native clock serialization failed")
      check(duration_seconds(t$elapsed_duration[1]) == 176400, "Long duration wrapped or changed")
      check(t$observation_datetime[1] == "2026-09-07T13:30:00", "Native datetime serialization failed")
    }
    if (variant == "empty") check(nrow(additional$context$tables$data__samples$data) == 0L, "Header-only table lost")
  }
  entity <- run("entity", format)
  check(entity$exit_status == 0L, "Legitimate repeated entity keys rejected")
  pointer <- read_json(publication)
  staged <- run("valid", format, stage = "coordinates")
  check(staged$exit_status == 0L && identical(read_json(publication), pointer), "Partial assessment changed publication")
  strict <- run("valid", format, config = list(required_assessments = list("assignment_uniqueness_and_retirement")))
  check(strict$exit_status == 2L, "Missing required evidence was accepted")
}
# Important coordinate edge cases are isolated from workbook parsing.
for (case in list(c("0", "latitude", "0"), c("90 N", "latitude", "90"), c("180 W", "longitude", "-180"), c("13:30:00 N", "latitude", "13.5"), c("0° 30' 0\" S", "latitude", "-0.5"))) {
  parsed <- parse_coordinate(case[1], case[2]); check(!nzchar(parsed$error) && abs(parsed$value - as.numeric(case[3])) < 1e-12, paste("Coordinate case failed", case[1]))
}
for (value in c("-13 N", "13 S N", "13° 60' N", "13,5", "91", "13 30", "Inf", "13' 30°", "13° 30\"", "13::30", "13°° 30'")) check(nzchar(parse_coordinate(value, "latitude")$error), paste("Ambiguous coordinate accepted:", value))
check(parse_coordinate("13,5", "latitude", ",")$value == 13.5, "Declared decimal comma failed")
check(parse_coordinate("-0.5", "latitude")$value == -0.5, "Negative decimal lost")
check(excel_temporal("60", "date", FALSE)$type == "temporal_error", "Excel fictitious leap day accepted")
check(excel_temporal("0", "date", TRUE)$value == "1904-01-01", "1904 date system incorrect")
check(excel_temporal("61", "date", FALSE)$value == "1900-03-01", "1900 date system incorrect")
check(!valid_date("2026-02-31") && valid_date("2024-02-29"), "Calendar validation incorrect")
# Diagnostics keep record identity, and declared text storage is actually checked.
ctx <- new_context(list(), "test", work)
ctx$tables <- first$context$tables
ctx$metadata <- first$context$metadata
ctx$reference_data <- list()
ctx$tables$data__samples$types[1, "category"] <- "number"
validate_values(ctx)
typed <- Filter(function(x) x$rule_id == "value.text_type", ctx$findings)
check(length(typed) == 1L && typed[[1]]$record_id == "SN26_00001" && typed[[1]]$cell == "F2", "Text storage check or record provenance missing")
profiles <- jsonlite::fromJSON(ctx$metadata$identifier_profiles, simplifyVector = FALSE)
profiles$field$type <- "misspelled_profile"
ctx$metadata$identifier_profiles <- as.character(jsonlite::toJSON(profiles, auto_unbox = TRUE))
validate_identifiers(ctx)
check(any(vapply(ctx$findings, function(x) x$rule_id == "identifier.profile_definition", logical(1))), "Unknown identifier profile accepted")
# A corrupted package must still be retained without replacing validated output.
writeLines("not a zip file", file.path(fixtures, "corrupt.xlsx"))
bad <- run("corrupt", "xlsx")
check(bad$exit_status == 2L && file.exists(bad$manifest$snapshot$path), "Corrupt snapshot not retained")
# Source IDs isolate unrelated mutable workbooks. Mismatched source metadata fails.
wrong <- suppressMessages(run_compliance(file.path(fixtures, "valid.xlsx"), file.path(work, "separate"), "other_collection"))
check(wrong$exit_status == 2L, "Mismatched workbook identity accepted")
# Lineage semantics: multiple parents are valid; cycles and missing references fail.
ctx <- new_context(list(), "test", work)
ctx$reference_data <- list(lineage = data.frame(namespace = c("demo", "demo"), child_id = c("POOL_1", "POOL_1"), parent_id = c("ITEM_1", "ITEM_2"), relationship = c("pooled_from", "pooled_from")))
validate_lineage(ctx); check(!has_errors(ctx), "Valid pool rejected")
ctx$reference_data$lineage <- data.frame(namespace = c("demo", "demo"), child_id = c("A", "B"), parent_id = c("B", "A"), relationship = c("child", "child"))
validate_lineage(ctx); check(has_errors(ctx), "Lineage cycle accepted")
# External allocation evidence is retained and a later reassignment blocks publication.
registry_path <- file.path(work, "registry.csv")
registry <- data.frame(namespace = c("demo", "demo", "demo_codes"), identifier = c("SN26_00001", "SN26_00002", "ok"),
                       entity_reference = c("SPECIMEN_1", "SPECIMEN_2", "CODE_OK"), status = c("issued", "issued", "issued"))
write.csv(registry, registry_path, row.names = FALSE)
configuration <- list(references = list(registry = list(path = registry_path)))
registered <- run("valid", "xlsx", file.path(work, "registry_state"), configuration)
check(registered$exit_status == 0L, "Valid allocation register rejected")
retained <- file.path(registered$manifest$run_dir, "reference_inputs", "registry.csv")
check(sha_file(retained) == sha_file(registry_path), "Allocation evidence not retained verbatim")
registry$entity_reference[1] <- "DIFFERENT_SPECIMEN"
write.csv(registry, registry_path, row.names = FALSE)
reassigned <- run("valid", "xlsx", file.path(work, "registry_state"), configuration)
check(reassigned$exit_status == 2L && reassigned$manifest$build_inputs_changed, "Reassignment or reference mutation not detected")
check(any(vapply(reassigned$context$findings, function(f) f$rule_id == "identifier.registry_reassignment", logical(1))), "Reassignment diagnosis missing")
# Optional enrichment is tested using response-cache replay, never public requests.
enrichment_state <- file.path(work, "enrichment")
cache <- file.path(enrichment_state, "demo_collection", "geocoding", ".osm_toponym_cache", "nominatim")
dir.create(cache, recursive = TRUE)
for (xy in list(c(13.63332, -16.3874), c(13.5, -16.2))) {
  response <- list(name = "Fixture locality", osm_type = "node", osm_id = 123,
                   lat = as.character(xy[1]), lon = as.character(xy[2]), category = "place", type = "village", address = list(country_code = "sn"))
  write_json(response, file.path(cache, sprintf("%.7f_%.7f_zoom15.json", xy[1], xy[2])))
}
options(httr2_mock = function(req) stop("Unexpected public request during offline tests"))
enriched <- run("entity", "xlsx", enrichment_state, list(enrich_toponyms = TRUE))
check(enriched$exit_status == 0L, "Cached enrichment failed")
geo <- read_json(file.path(enriched$manifest$run_dir, "derived", "data__samples__toponyms.geojson"))
check(length(geo$features) == 2L && all(vapply(geo$features, function(f) f$properties$source_id == "SN26_00001", logical(1))), "Enrichment lost repeated entity IDs")
check(identical(vapply(geo$features, function(f) as.integer(f$properties$source_row), integer(1)), c(2L, 3L)), "Enrichment lost source row identity")
for (artifact in enriched$manifest$artifacts) check(artifact$sha256 == sha_file(file.path(enriched$manifest$run_dir, artifact$path)), "Artifact digest mismatch")
options(httr2_mock = function(req) stop("Unexpected public request during offline tests"))
# Source literals and exported Unicode must not depend on the host locale.
registry$entity_reference[1] <- "Spécimen_1"
write_character_csv(registry, registry_path)
cli_config <- file.path(work, "cli_config.json")
write_json(list(references = list(registry = list(path = registry_path))), cli_config)
for (format in c("xlsx", "ods")) {
  cli_state <- file.path(work, paste0("c_locale_", format))
  cli_log <- file.path(work, paste0("c_locale_", format, ".log"))
  cli_status <- system2(file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(root, "src", "run_compliance.R")), shQuote(file.path(fixtures, paste0("valid.", format))),
      shQuote(cli_state), "--source-id", "demo_collection", "--config", shQuote(cli_config)), env = "LC_ALL=C", stdout = cli_log, stderr = cli_log)
  check(cli_status == 0L, paste("C-locale CLI failed:", paste(readLines(cli_log), collapse = "\n")))
  published <- read_json(file.path(cli_state, "demo_collection", "current.json"))
  exported <- read.csv(file.path(published$run_dir, "original", "data__samples.csv"), colClasses = "character", fileEncoding = "UTF-8")
  check(exported$note[1] == 'Médina  Djikoye\nquoted "note"\tend', "C-locale CLI changed Unicode text")
  evidence <- readRDS(file.path(published$run_dir, "reference_evidence.rds"))
  check(identical(evidence$registry$entity_reference[1], "Spécimen_1"), "C-locale CLI changed external reference text")
}
cat("All workbook compliance regression checks passed.\n")
unlink(work, recursive = TRUE)

}
run_compliance_tests()
