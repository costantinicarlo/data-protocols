`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
scalar <- function(x, default = "") if (is.null(x) || !length(x) || is.na(x[[1]])) default else as.character(x[[1]])
sha_file <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
sha_object <- function(x) digest::digest(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA), algo = "sha256", serialize = FALSE)
read_json <- function(path) jsonlite::read_json(path, simplifyVector = FALSE)
write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = NA)
}
atomic_json <- function(x, path) {
  tmp <- tempfile("pointer-", tmpdir = dirname(path))
  on.exit(unlink(tmp))
  write_json(x, tmp)
  if (!file.rename(tmp, path)) stop("Could not atomically replace publication pointer: ", path)
}
require_columns <- function(x, names) all(names %in% colnames(x))
empty_cells <- function() data.frame(row = integer(), col = integer(), ref = character(), type = character(), value = character(), formula = character(), stringsAsFactors = FALSE)
col_name <- function(n) {
  out <- ""
  while (n > 0) { n <- n - 1L; out <- paste0(LETTERS[n %% 26L + 1L], out); n <- n %/% 26L }
  out
}
col_number <- function(x) Reduce(function(a, b) a * 26L + match(b, LETTERS), strsplit(x, "", fixed = TRUE)[[1]], init = 0L)
cell_ref <- function(row, col) paste0(col_name(col), row)
new_context <- function(config, source_id, run_dir) {
  e <- new.env(parent = emptyenv())
  e$config <- config; e$source_id <- source_id; e$run_dir <- run_dir
  e$findings <- list(); e$coverage <- list(); e$tables <- list(); e$metadata <- list()
  e$derived <- list(); e$declarations <- NULL; e$source_sha256 <- ""
  e
}
finding <- function(ctx, rule, severity, message, sheet = "", row = NA_integer_, field = "", value = NA_character_, action = "", record_id = "") {
  ref <- ""
  if (sheet %in% names(ctx$tables) && nzchar(field) && !is.na(row)) {
    col <- match(field, names(ctx$tables[[sheet]]$data))
    if (!is.na(col)) ref <- cell_ref(row, col)
  }
  if (!nzchar(record_id) && sheet %in% names(ctx$tables) && !is.na(row) && row > 1L) {
    tab <- ctx$tables[[sheet]]
    if (nzchar(scalar(tab$key_field)) && row <= nrow(tab$data) + 1L) record_id <- scalar(tab$data[[tab$key_field]][row - 1L])
  }
  ctx$findings[[length(ctx$findings) + 1L]] <- list(
    source_id = ctx$source_id, source_sha256 = ctx$source_sha256,
    rule_id = rule, severity = severity, sheet = sheet, source_row = row,
    cell = ref, field = field, record_id = record_id, original_value = value,
    message = message, proposed_action = action)
  invisible(NULL)
}
coverage <- function(ctx, check, state, reason = "", sheet = "") {
  ctx$coverage[[length(ctx$coverage) + 1L]] <- list(check = check, state = state, sheet = sheet, reason = reason)
}
has_errors <- function(ctx) any(vapply(ctx$findings, function(f) f$severity == "error", logical(1)))
field_rule <- function(ctx, sheet, field) {
  # Machine-relevant, selective field metadata is authoritative in the workbook.
  tab <- ctx$tables[["meta__fields"]]$data
  if (is.null(tab) || !require_columns(tab, c("sheet_name", "field_name"))) return(list())
  rows <- which(tab$sheet_name == sheet & tab$field_name == field)
  if (length(rows) != 1L) return(list())
  as.list(tab[rows, , drop = FALSE])
}
metadata_json <- function(ctx, item, fallback = NULL) {
  val <- ctx$metadata[[item]]
  if (is.null(val) || is.na(val) || !nzchar(val)) return(fallback)
  tryCatch(jsonlite::fromJSON(val, simplifyVector = FALSE), error = function(e) {
    finding(ctx, "metadata.invalid_json", "error", paste("Invalid JSON in meta__readme:", item), "meta__readme", field = "value", value = val)
    fallback
  })
}
read_external_csv <- function(path) read.csv(path, colClasses = "character", check.names = FALSE, na.strings = character(), strip.white = FALSE, encoding = "UTF-8")
write_character_csv <- function(data, path, missing = "") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  # write.table can substitute <U+....> under the C locale before encoding the
  # output connection. Escape CSV explicitly and write UTF-8 bytes unchanged.
  quote_csv <- function(x) paste0('"', gsub('"', '""', enc2utf8(x), fixed = TRUE), '"')
  columns <- lapply(data, function(x) {
    absent <- is.na(x)
    value <- if (is.numeric(x)) trimws(formatC(x, digits = 17L, format = "g", decimal.mark = ".")) else as.character(x)
    value[absent] <- missing
    quote_csv(value)
  })
  connection <- file(path, open = "wb")
  on.exit(close(connection))
  writeLines(enc2utf8(paste(quote_csv(names(data)), collapse = ",")), connection, useBytes = TRUE)
  if (nrow(data)) writeLines(enc2utf8(do.call(paste, c(unname(columns), list(sep = ",")))), connection, useBytes = TRUE)
}
