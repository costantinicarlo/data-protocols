COMPLIANCE_VERSION <- "0.1.0"
snapshot_source <- function(input, state, source_id) {
  if (!file.exists(input) || dir.exists(input)) stop("Input workbook does not exist")
  extension <- tolower(tools::file_ext(input))
  if (!extension %in% c("xlsx", "ods")) stop("Only completed .xlsx or .ods downloads are accepted")
  before <- file.info(input)[, c("size", "mtime")]
  digest <- sha_file(input)
  directory <- file.path(state, source_id, "snapshots", digest)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  destination <- file.path(directory, paste0("source.", extension))
  tmp <- tempfile("download-", tmpdir = directory)
  on.exit(unlink(tmp))
  if (!file.copy(input, tmp)) stop("Could not preserve downloaded workbook")
  after <- file.info(input)[, c("size", "mtime")]
  if (!identical(before, after) || sha_file(input) != digest || sha_file(tmp) != digest) stop("Download changed while snapshotting; finish the download and retry")
  if (file.exists(destination)) {
    if (sha_file(destination) != digest) stop("Archived snapshot has been altered; refusing to overwrite evidence")
  } else if (!file.rename(tmp, destination)) stop("Could not finalise snapshot")
  list(path = normalizePath(destination), sha256 = digest, original_filename = basename(input), size = unname(before$size), format = extension)
}
file_fingerprints <- function(paths) {
  lapply(paths, function(path) {
    relative <- substring(normalizePath(path), nchar(COMPLIANCE_ROOT) + 2L)
    commit <- tryCatch(system2("git", c("-C", shQuote(COMPLIANCE_ROOT), "log", "-1", "--format=%H", "--", shQuote(relative)), stdout = TRUE, stderr = FALSE), error = function(e) character())
    list(path = relative, sha256 = sha_file(path), last_commit = if (length(commit)) commit[1] else NULL)
  })
}
inventory <- function(ctx) {
  lapply(names(ctx$tables), function(name) {
    t <- ctx$tables[[name]]
    list(sheet = name, role = t$role, rows = if (!is.null(t$data)) nrow(t$data) else max(0L, t$rows - 1L),
         columns = t$columns, fields = names(t$data), excluded_fields = t$excluded,
         key_field = t$key_field, key_scope = t$key_scope,
         types = if (!is.null(t$data)) lapply(names(t$data), function(f) list(field = f, types = unique(t$types[, f]), missing = sum(is.na(t$data[[f]])))) else list(),
         content_sha256 = sha_object(t$cells))
  })
}
compare_snapshots <- function(ctx, previous, current) {
  old <- if (!is.null(previous) && file.exists(file.path(previous$run_dir, "inventory.json"))) read_json(file.path(previous$run_dir, "inventory.json")) else list()
  by_name <- function(x) setNames(x, vapply(x, function(s) scalar(s$sheet), character(1)))
  a <- by_name(old); b <- by_name(current)
  changes <- list(added_sheets = setdiff(names(b), names(a)), removed_sheets = setdiff(names(a), names(b)), sheets = list())
  for (name in intersect(names(a), names(b))) {
    changes$sheets[[name]] <- list(rows_before = a[[name]]$rows, rows_after = b[[name]]$rows,
      added_fields = setdiff(unlist(b[[name]]$fields), unlist(a[[name]]$fields)),
      removed_fields = setdiff(unlist(a[[name]]$fields), unlist(b[[name]]$fields)),
      field_order_changed = !identical(unlist(a[[name]]$fields), unlist(b[[name]]$fields)),
      content_changed = !identical(a[[name]]$content_sha256, b[[name]]$content_sha256),
      key_definition_changed = !identical(a[[name]]$key_field, b[[name]]$key_field) || !identical(a[[name]]$key_scope, b[[name]]$key_scope))
    # Compare only unambiguous row keys. Repeated entity keys need an explicit
    # observation identity; never align them by row position and invent matches.
    tab <- ctx$tables[[name]]
    prior_path <- if (!is.null(previous)) file.path(previous$run_dir, "table_evidence.rds") else ""
    if (tab$key_scope == "row" && !is.null(tab$data) && file.exists(prior_path)) {
      oldtab <- readRDS(prior_path)[[name]]
      key <- tab$key_field
      if (!is.null(oldtab) && key %in% names(oldtab) && !anyNA(oldtab[[key]]) && !anyNA(tab$data[[key]]) && !anyDuplicated(oldtab[[key]]) && !anyDuplicated(tab$data[[key]])) {
        before <- oldtab[[key]]; after <- tab$data[[key]]; common <- intersect(before, after)
        fields <- intersect(names(oldtab), names(tab$data))
        modified <- common[vapply(common, function(id) !identical(as.list(oldtab[match(id, before), fields, drop = FALSE]), as.list(tab$data[match(id, after), fields, drop = FALSE])), logical(1))]
        changes$sheets[[name]]$records <- list(added_ids = setdiff(after, before), removed_ids = setdiff(before, after), modified_ids = modified)
      }
    } else if (tab$key_scope == "entity") changes$sheets[[name]]$record_comparison <- "not_assessed: repeated entity keys do not identify individual observations"
  }
  changes
}
load_reference_data <- function(ctx, config_dir) {
  ctx$reference_data <- list(); ctx$reference_hashes <- list()
  refs <- ctx$config$references %||% list()
  for (kind in names(refs)) {
    if (!kind %in% c("registry", "aliases", "lineage")) stop("Unknown reference kind: ", kind)
    spec <- refs[[kind]]
    if (!is.null(spec$path)) {
      path <- scalar(spec$path)
      if (!grepl("^(/|[A-Za-z]:)", path)) path <- file.path(config_dir, path)
      if (!file.exists(path)) stop("Missing reference file: ", path)
      before <- sha_file(path)
      ctx$reference_data[[kind]] <- read_external_csv(path)
      retained <- file.path(ctx$run_dir, "reference_inputs", paste0(kind, ".csv"))
      dir.create(dirname(retained), recursive = TRUE, showWarnings = FALSE)
      if (!file.copy(path, retained) || sha_file(path) != before || sha_file(retained) != before) stop("Reference file changed while reading: ", path)
      ctx$reference_hashes[[kind]] <- list(path = normalizePath(path), sha256 = before)
    } else if (!is.null(spec$sheet)) {
      table <- ctx$tables[[scalar(spec$sheet)]]
      if (is.null(table) || !table$usable || table$role != "ref") stop("Reference must name a usable ref__ sheet")
      ctx$reference_data[[kind]] <- table$data[, setdiff(names(table$data), table$excluded), drop = FALSE]
    } else stop("Reference specification requires path or sheet")
  }
}
run_toponym_enrichment <- function(ctx) {
  if (!isTRUE(ctx$config$enrich_toponyms)) return(invisible(NULL))
  if (has_errors(ctx)) { coverage(ctx, "live_toponym_enrichment", "not_assessed", "Validation errors prevent network enrichment"); return(invisible(NULL)) }
  previous_wd <- getwd(); on.exit(setwd(previous_wd))
  dir.create(file.path(ctx$state_root, ctx$source_id, "geocoding"), showWarnings = FALSE)
  setwd(file.path(ctx$state_root, ctx$source_id, "geocoding"))
  engine <- new.env(parent = globalenv())
  eval(parse(file.path(COMPLIANCE_ROOT, "src", "osm_toponym.R"), encoding = "UTF-8", keep.source = FALSE), envir = engine)
  # Persist response caches across successful and failed downloads of this workbook.
  engine$NOMINATIM_DELAY <- ctx$config$geocoding_delay %||% 15.1
  if (!is.finite(engine$NOMINATIM_DELAY) || engine$NOMINATIM_DELAY < 15) stop("Recurring enrichment must use geocoding_delay >= 15 seconds")
  for (name in names(ctx$derived)) {
    data <- ctx$derived[[name]]; data <- data[data$status == "converted", , drop = FALSE]
    if (!nrow(data)) next
    # Use temporary row IDs so repeated entity keys do not collapse observations.
    query <- data.frame(id = paste0("ROW_", data$source_row), latitude = data$latitude_dd, longitude = data$longitude_dd)
    geo <- engine$resolve_toponyms(query)
    for (i in seq_along(geo$features)) {
      geo$features[[i]]$properties$source_id <- data$source_id[i]
      geo$features[[i]]$properties$source_row <- data$source_row[i]
    }
    write_json(geo, file.path(ctx$run_dir, "derived", paste0(name, "__toponyms.geojson")))
    statuses <- vapply(geo$features, function(f) f$properties$status, character(1))
    if (any(statuses == "unresolved")) finding(ctx, "toponymy.enrichment_failure", "error", "Requested enrichment contains unresolved records", name)
    if (any(statuses %in% c("ambiguous", "osm_fallback"))) finding(ctx, "toponymy.enrichment_review", "warning", "Enrichment includes ambiguous/fallback references requiring review", name)
  }
  coverage(ctx, "live_toponym_enrichment", "assessed", "Automated OSM lookup is not human verification")
}
build_compliance_report <- function(ctx, manifest) {
  write_json(ctx$findings, file.path(ctx$run_dir, "findings.json"))
  write_json(ctx$coverage, file.path(ctx$run_dir, "coverage.json"))
  corrections <- Filter(function(f) nzchar(f$proposed_action) || f$severity == "error", ctx$findings)
  write_json(corrections, file.path(ctx$run_dir, "correction_proposals.json"))
  inv <- inventory(ctx); write_json(inv, file.path(ctx$run_dir, "inventory.json"))
  saveRDS(lapply(ctx$tables, function(t) t$data), file.path(ctx$run_dir, "table_evidence.rds"))
  for (name in names(ctx$tables)) {
    tab <- ctx$tables[[name]]
    write_character_csv(tab$cells, file.path(ctx$run_dir, "cell_evidence", sprintf("sheet_%03d.csv", tab$index)))
  }
  write_json(manifest, file.path(ctx$run_dir, "manifest.json"))
  escape <- function(s) gsub("[\r\n]", " ", gsub("|", "\\|", scalar(s), fixed = TRUE))
  lines <- c("# Dataset compliance report", "", paste("Source:", ctx$source_id), paste("Snapshot SHA-256:", ctx$source_sha256),
             paste("Status:", manifest$status), paste("Run:", manifest$run_id), "",
             "This report assesses observable evidence. It does not certify undocumented history, physical identity, or scientific truth.", "",
             "| Severity | Rule | Sheet / row | Finding |", "| --- | --- | --- | --- |")
  for (f in ctx$findings) lines <- c(lines, paste0("| ", f$severity, " | ", f$rule_id, " | ", escape(f$sheet), " / ", scalar(f$source_row), " | ", escape(f$message), " |"))
  lines <- c(lines, "", "## Coverage", "", "| Check | State | Reason |", "| --- | --- | --- |")
  for (c in ctx$coverage) lines <- c(lines, paste0("| ", c$check, " | ", c$state, " | ", escape(c$reason), " |"))
  writeLines(lines, file.path(ctx$run_dir, "report.md"), useBytes = TRUE)
}
run_compliance <- function(input, state, source_id, config = list(), config_dir = getwd(), stage = "all") {
  if (!grepl("^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$", source_id, perl = TRUE)) stop("source-id must be stable lower_snake_case")
  allowed <- c("max_cells", "missing_token", "references", "required_assessments", "enrich_toponyms", "geocoding_delay")
  if (length(setdiff(names(config), allowed))) stop("Unknown config fields: ", paste(setdiff(names(config), allowed), collapse = ", "))
  if (!is.null(config$max_cells) && (length(config$max_cells) != 1L || !is.numeric(config$max_cells) || !is.finite(config$max_cells) || config$max_cells < 1 || config$max_cells != trunc(config$max_cells))) stop("max_cells must be a positive integer")
  if (!is.null(config$missing_token) && (!is.character(config$missing_token) || length(config$missing_token) != 1L || !nzchar(config$missing_token) || grepl("[\r\n]", config$missing_token))) stop("missing_token must be one nonempty string without newlines")
  if (!is.null(config$enrich_toponyms) && (!is.logical(config$enrich_toponyms) || length(config$enrich_toponyms) != 1L || is.na(config$enrich_toponyms))) stop("enrich_toponyms must be a JSON boolean")
  dir.create(file.path(state, source_id), recursive = TRUE, showWarnings = FALSE)
  state <- normalizePath(state); source_dir <- file.path(state, source_id)
  lock <- file.path(source_dir, ".lock")
  if (!dir.create(lock, showWarnings = FALSE)) stop("Source is already locked; inspect any interrupted run before removing its lock")
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  snapshot <- snapshot_source(input, state, source_id)
  id <- paste0(format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC"), "-", Sys.getpid(), "-", substr(basename(tempfile()), 1, 20))
  id <- gsub("[^A-Za-z0-9_.-]", "_", id)
  run_dir <- file.path(source_dir, "runs", id); dir.create(run_dir, recursive = TRUE)
  ctx <- new_context(config, source_id, run_dir)
  ctx$source_sha256 <- snapshot$sha256; ctx$state_root <- state; ctx$reference_data <- list(); ctx$reference_hashes <- list()
  ctx$catalogue <- list()
  prior <- if (file.exists(file.path(source_dir, "latest_attempt.json"))) read_json(file.path(source_dir, "latest_attempt.json")) else NULL
  current <- if (file.exists(file.path(source_dir, "current.json"))) read_json(file.path(source_dir, "current.json")) else NULL
  paths <- c(list.files(file.path(COMPLIANCE_ROOT, "src"), "\\.R$", full.names = TRUE, recursive = TRUE),
             list.files(file.path(COMPLIANCE_ROOT, "contracts"), "\\.md$", full.names = TRUE),
             list.files(file.path(COMPLIANCE_ROOT, "references"), full.names = TRUE))
  fingerprints <- file_fingerprints(sort(paths))
  result <- tryCatch({
    if (stage != "snapshot") {
      workbook <- inspect_dataset(snapshot$path, config$max_cells %||% 1000000L)
      ctx$workbook <- workbook
      validate_workbook(ctx, workbook)
      if (!stage %in% c("inspect", "workbook")) {
        load_reference_data(ctx, config_dir)
        ctx$previous_reference_data <- if (!is.null(current) && file.exists(file.path(current$run_dir, "reference_evidence.rds"))) readRDS(file.path(current$run_dir, "reference_evidence.rds")) else list()
        saveRDS(ctx$reference_data, file.path(run_dir, "reference_evidence.rds"))
        if (stage %in% c("all", "extract", "identifiers", "lineage", "report")) validate_identifiers(ctx)
        if (stage %in% c("all", "extract", "values", "report")) validate_values(ctx)
        if (stage %in% c("all", "extract", "temporal", "report")) validate_temporal_fields(ctx)
        if (stage %in% c("all", "extract", "coordinates", "report")) validate_coordinates(ctx)
        if (stage %in% c("all", "extract", "lineage", "report")) validate_lineage(ctx)
        if (stage %in% c("all", "extract", "toponymy", "report")) validate_toponymy(ctx)
        if (stage %in% c("all", "extract", "report")) {
          for (required in unlist(config$required_assessments %||% list())) {
            found <- Filter(function(x) x$check == required, ctx$coverage)
            if (!length(found) || any(vapply(found, function(x) x$state == "not_assessed", logical(1)))) finding(ctx, "publication.required_coverage", "error", paste("Required assessment incomplete:", required))
          }
          run_toponym_enrichment(ctx)
          if (!has_errors(ctx)) export_tables(ctx)
        }
        standardize_coordinates(ctx)
      }
    }
    NULL
  }, error = function(e) {
    finding(ctx, "pipeline.failure", "error", conditionMessage(e), action = "Inspect source/package/configuration diagnostics; existing publication remains unchanged")
    e
  })
  inv <- inventory(ctx)
  changes <- compare_snapshots(ctx, prior, inv)
  write_json(changes, file.path(run_dir, "changes.json"))
  packages <- c("jsonlite", "xml2", "digest", "httr2", "sf")
  versions <- setNames(lapply(packages, function(p) if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else NULL), packages)
  signature <- sha_object(list(source = snapshot$sha256, files = fingerprints, config = config,
                               references = ctx$reference_hashes, R = as.character(getRversion()), packages = versions, stage = stage))
  status <- if (has_errors(ctx)) "failed" else if (stage == "all") "validated" else "assessed_stage_only"
  manifest <- list(pipeline_version = COMPLIANCE_VERSION, source_id = source_id, run_id = id,
    run_dir = run_dir, stage = stage, status = status, timestamp_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    snapshot = snapshot, build_signature = signature, previous_attempt = prior, previous_validated_run = current,
    source_changed = is.null(prior) || !identical(prior$source_sha256, snapshot$sha256),
    build_inputs_changed = is.null(prior) || !identical(prior$build_signature, signature),
    files = fingerprints, config = config, external_references = ctx$reference_hashes,
    R_version = as.character(getRversion()), packages = versions, missing_token = scalar(config$missing_token, "\\N"),
    catalogue = ctx$catalogue, error_count = sum(vapply(ctx$findings, function(f) f$severity == "error", logical(1))))
  build_compliance_report(ctx, manifest)
  artifacts <- list.files(run_dir, full.names = TRUE, recursive = TRUE)
  artifacts <- setdiff(artifacts, file.path(run_dir, "manifest.json"))
  manifest$artifacts <- lapply(artifacts, function(path) list(path = substring(path, nchar(run_dir) + 2L), sha256 = sha_file(path)))
  if (requireNamespace("sf", quietly = TRUE)) manifest$geospatial_libraries <- as.list(sf::sf_extSoftVersion())
  write_json(manifest, file.path(run_dir, "manifest.json"))
  pointer <- list(run_id = id, run_dir = run_dir, source_sha256 = snapshot$sha256, build_signature = signature)
  atomic_json(pointer, file.path(source_dir, "latest_attempt.json"))
  if (status == "validated") atomic_json(pointer, file.path(source_dir, "current.json"))
  message("Status: ", status, "\nReport: ", file.path(run_dir, "report.md"))
  list(exit_status = if (has_errors(ctx)) 2L else 0L, manifest = manifest, context = ctx)
}
