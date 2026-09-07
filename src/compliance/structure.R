validate_workbook <- function(ctx, workbook) {
  for (i in seq_along(workbook$sheets)) {
    sh <- workbook$sheets[[i]]; name <- sh$name; cells <- sh$cells
    role <- sub("__.*$", "", name)
    if (!grepl("^(data|ref|calc|meta)__[a-z][a-z0-9]*(?:_[a-z0-9]+)*$", name, perl = TRUE) || nchar(name) > 31L) {
      finding(ctx, "workbook.sheet_name", "error", "Unknown role or invalid worksheet name (including the 31-character limit)", name)
      role <- "unknown"
    }
    occupied <- cells[!is.na(cells$value) | !is.na(cells$formula), , drop = FALSE]
    height <- if (nrow(occupied)) max(occupied$row) else 0L
    width <- if (nrow(occupied)) max(occupied$col) else 0L
    tab <- list(index = i, role = role, cells = cells, rows = height, columns = width,
                usable = FALSE, data = NULL, types = NULL, excluded = character(), key_field = "", key_scope = "")
    ctx$tables[[name]] <- tab
    if (role %in% c("calc", "unknown")) {
      coverage(ctx, "table_structure", "not_applicable", "Excluded calculated or unrecognised worksheet", name)
      next
    }
    if (length(sh$merges)) finding(ctx, "workbook.merged_cells", "error", paste("Merged cells:", paste(sh$merges, collapse = ", ")), name)
    if (!height || !width) { finding(ctx, "workbook.empty_sheet", "error", "A header row beginning at A1 is required", name); next }
    if (as.double(height) * width > (ctx$config$max_cells %||% 1000000L)) {
      finding(ctx, "workbook.rectangle_limit", "error", "Logical rectangle exceeds configured cell limit", name); next
    }
    values <- matrix(NA_character_, nrow = height, ncol = width)
    types <- matrix("blank", nrow = height, ncol = width)
    for (j in seq_len(nrow(occupied))) {
      c <- occupied[j, ]; values[c$row, c$col] <- c$value; types[c$row, c$col] <- c$type
    }
    headers <- values[1, ]
    if (anyNA(headers) || any(!nzchar(headers)) || anyDuplicated(headers)) {
      finding(ctx, "workbook.headers", "error", "Headers must be nonblank and unique; the table must begin at A1", name, 1L)
      next
    }
    good_names <- grepl("^(?:calc__)?[a-z][a-z0-9]*(?:_[a-z0-9]+)*$", headers, perl = TRUE)
    for (h in headers[!good_names]) finding(ctx, "workbook.field_name", "error", "Invalid field name; correct it upstream", name, 1L, h, h)
    data <- as.data.frame(values[-1, , drop = FALSE], stringsAsFactors = FALSE, optional = TRUE)
    names(data) <- headers; colnames(types) <- headers
    excluded <- if (role %in% c("data", "ref")) headers[startsWith(headers, "calc__")] else character()
    tab$data <- data; tab$types <- types[-1, , drop = FALSE]; tab$excluded <- excluded; tab$usable <- all(good_names)
    ctx$tables[[name]] <- tab
    # Occupancy, not styling, defines real rows. Formula-only prefill is still occupied.
    if (height > 1L) for (r in 2:height) {
      if (!r %in% occupied$row) finding(ctx, "workbook.spacer_row", "error", "Blank spacer row inside logical table", name, r)
    }
    for (j in seq_len(nrow(occupied))) {
      c <- occupied[j, ]; field <- headers[c$col]
      excluded_cell <- c$row > 1L && field %in% excluded
      if (excluded_cell) next
      if (!is.na(c$formula)) finding(ctx, "workbook.raw_formula", "error", "Formula in retained raw or metadata content", name, c$row, field, c$formula, "Correct the authoritative workbook; do not use the cached formula result")
      if (c$type %in% c("error", "temporal_error")) finding(ctx, "workbook.cell_error", "error", paste("Invalid stored value:", c$type), name, c$row, field, c$value)
      if (!is.na(c$value) && c$type == "text" && !nzchar(trimws(c$value))) finding(ctx, "workbook.whitespace_value", "error", "Empty/whitespace text is not a genuinely blank observation", name, c$row, field, c$value)
    }
    coverage(ctx, "table_structure", "assessed", sheet = name)
  }
  for (required in c("meta__readme", "meta__tables")) {
    if (is.null(ctx$tables[[required]]) || !isTRUE(ctx$tables[[required]]$usable)) finding(ctx, "metadata.required_sheet", "error", paste("Missing or invalid", required), required)
  }
  readme <- ctx$tables[["meta__readme"]]$data
  if (!is.null(readme) && require_columns(readme, c("item", "value"))) {
    if (anyNA(readme$item) || anyDuplicated(readme$item)) finding(ctx, "metadata.duplicate_item", "error", "Metadata items must be present and unique", "meta__readme")
    else ctx$metadata <- as.list(setNames(readme$value, readme$item))
  } else finding(ctx, "metadata.readme_fields", "error", "meta__readme requires item and value fields", "meta__readme")
  for (key in c("workbook_id", "purpose", "curator", "source_reference", "contract_version", "locale")) {
    if (!nzchar(scalar(ctx$metadata[[key]]))) finding(ctx, "metadata.required_item", "error", paste("Missing source metadata:", key), "meta__readme")
  }
  if (nzchar(scalar(ctx$metadata$workbook_id)) && ctx$metadata$workbook_id != ctx$source_id) finding(ctx, "metadata.source_identity", "error", "workbook_id differs from the invocation's stable source ID", "meta__readme", value = ctx$metadata$workbook_id)
  if (nzchar(scalar(ctx$metadata$contract_version)) && ctx$metadata$contract_version != "2.0.0-draft.1") finding(ctx, "metadata.contract_version", "error", "This reader implements workbook contract 2.0.0-draft.1; explicitly migrate other versions", "meta__readme")
  declarations <- ctx$tables[["meta__tables"]]$data
  if (!is.null(declarations) && require_columns(declarations, c("sheet_name", "key_field", "key_scope", "record_unit"))) {
    ctx$declarations <- declarations
    if (anyNA(declarations$sheet_name) || anyDuplicated(declarations$sheet_name)) finding(ctx, "metadata.table_duplicates", "error", "Each exported sheet needs one declaration", "meta__tables")
    exported <- names(Filter(function(t) t$role %in% c("data", "ref"), ctx$tables))
    for (extra in setdiff(declarations$sheet_name, exported)) finding(ctx, "metadata.unknown_table", "error", "Key declaration does not name a data/ref worksheet", "meta__tables", value = extra)
    for (name in exported) {
      tab <- ctx$tables[[name]]; idx <- which(declarations$sheet_name == name)
      if (length(idx) != 1L) { finding(ctx, "metadata.key_declaration", "error", "Missing/duplicate key declaration", name); next }
      d <- declarations[idx, , drop = FALSE]
      key <- scalar(d$key_field); scope <- scalar(d$key_scope)
      if (!key %in% names(tab$data) || key %in% tab$excluded || !scope %in% c("row", "entity") || !nzchar(scalar(d$record_unit))) {
        finding(ctx, "metadata.key_declaration", "error", "Declare a retained key, row/entity scope, and record_unit", name); next
      }
      tab$key_field <- key; tab$key_scope <- scope; ctx$tables[[name]] <- tab
      if (scope == "entity" && (is.null(d$notes) || !nzchar(scalar(d$notes)))) finding(ctx, "metadata.entity_notes", "warning", "Document legitimate repeated entity observations", name)
    }
  } else finding(ctx, "metadata.tables_fields", "error", "meta__tables requires sheet_name, key_field, key_scope, record_unit", "meta__tables")
  fields <- ctx$tables[["meta__fields"]]$data
  if (!is.null(fields)) {
    if (!require_columns(fields, c("sheet_name", "field_name"))) finding(ctx, "metadata.fields_layout", "error", "meta__fields requires sheet_name and field_name", "meta__fields")
    else {
      keys <- paste(fields$sheet_name, fields$field_name, sep = "\r")
      if (anyDuplicated(keys)) finding(ctx, "metadata.fields_duplicates", "error", "Repeated selective field declaration", "meta__fields")
      for (i in seq_len(nrow(fields))) {
        sh <- fields$sheet_name[i]; fld <- fields$field_name[i]
        if (is.na(sh) || is.na(fld) || !fld %in% names(ctx$tables[[sh]]$data)) finding(ctx, "metadata.unknown_field", "error", "Selective metadata refers to an absent field", "meta__fields", i + 1L, value = keys[i])
      }
    }
  }
  coverage(ctx, "visual_meaning_and_pasted_formula_history", "not_assessed", "Stored XML exposes cell formulas, not editing history, physical labels, or the meaning of colours")
  invisible(ctx)
}
export_tables <- function(ctx) {
  missing <- scalar(ctx$config$missing_token, "\\N")
  catalogue <- list()
  for (name in names(ctx$tables)) {
    tab <- ctx$tables[[name]]
    if (!tab$usable || !tab$role %in% c("data", "ref", "meta")) next
    keep <- setdiff(names(tab$data), tab$excluded)
    data <- tab$data[, keep, drop = FALSE]
    if (any(vapply(data, function(x) any(x == missing, na.rm = TRUE), logical(1)))) {
      finding(ctx, "serialization.missing_collision", "error", "Missing token collides with a literal value; select another output token", name); next
    }
    folder <- if (tab$role == "meta") "documentation" else "original"
    relative <- file.path(folder, paste0(name, ".csv"))
    write_character_csv(data, file.path(ctx$run_dir, relative), missing)
    catalogue[[name]] <- list(path = relative, role = tab$role, sha256 = sha_file(file.path(ctx$run_dir, relative)),
                              key_field = tab$key_field, key_scope = tab$key_scope,
                              rows = nrow(data), fields = keep, excluded_fields = tab$excluded)
  }
  ctx$catalogue <- catalogue
  invisible(ctx)
}
