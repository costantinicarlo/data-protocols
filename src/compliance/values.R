strict_number <- function(x) !is.na(x) & grepl("^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$", x, perl = TRUE) & is.finite(suppressWarnings(as.numeric(x)))
json_values <- function(ctx, text, sheet, field) {
  if (!nzchar(scalar(text))) return(NULL)
  tryCatch(unlist(jsonlite::fromJSON(text, simplifyVector = FALSE)), error = function(e) {
    finding(ctx, "metadata.field_json", "error", "Invalid field JSON metadata", sheet, field = field, value = text); NULL
  })
}
validate_values <- function(ctx) {
  for (name in names(ctx$tables)) {
    tab <- ctx$tables[[name]]
    if (!tab$usable || !tab$role %in% c("data", "ref")) next
    declared <- 0L
    for (field in setdiff(names(tab$data), tab$excluded)) {
      x <- tab$data[[field]]; rule <- field_rule(ctx, name, field)
      type <- scalar(rule$type); if (nzchar(type)) declared <- declared + 1L
      if (nzchar(type) && !type %in% c("text", "number", "integer", "boolean", "date", "datetime", "time", "duration", "partial_date")) finding(ctx, "metadata.unknown_type", "error", "Unrecognised selective field type", name, field = field, value = type)
      missing_codes <- json_values(ctx, rule$missing_codes, name, field)
      values <- json_values(ctx, rule$allowed_values, name, field)
      if (nzchar(scalar(rule$ref_sheet))) {
        ref <- ctx$tables[[scalar(rule$ref_sheet)]]
        ref_field <- scalar(rule$ref_field)
        if (is.null(ref) || ref$role != "ref" || !ref_field %in% setdiff(names(ref$data), ref$excluded)) finding(ctx, "value.reference_definition", "error", "Controlled vocabulary must name a retained ref__ field", name, field = field)
        else values <- ref$data[[ref_field]]
      }
      for (i in seq_along(x)) {
        value <- x[i]
        if (is.na(value)) {
          if (scalar(rule$required) == "true") finding(ctx, "value.required", "error", "Declared required observation is blank", name, i + 1L, field)
          next
        }
        if (value %in% missing_codes) {
          finding(ctx, "value.legacy_missing_code", "information", "Documented legacy missing code retained verbatim", name, i + 1L, field, value); next
        }
        if (type == "text" && tab$types[i, field] != "text") finding(ctx, "value.text_type", "error", "Declared text field is not stored as literal text", name, i + 1L, field, value)
        if (type %in% c("number", "integer")) {
          if (!strict_number(value) || tab$types[i, field] != "number") {
            finding(ctx, "value.numeric_type", "error", "Declared numeric field is not stored as a finite number", name, i + 1L, field, value); next
          }
          num <- as.numeric(value)
          if (type == "integer" && num != trunc(num)) finding(ctx, "value.integer", "error", "Non-integral value in integer field", name, i + 1L, field, value)
          for (bound in c("minimum", "maximum")) if (nzchar(scalar(rule[[bound]]))) {
            limit <- suppressWarnings(as.numeric(rule[[bound]]))
            if (!is.finite(limit)) finding(ctx, "metadata.numeric_bound", "error", "Invalid numeric bound", name, field = field)
            else if ((bound == "minimum" && num < limit) || (bound == "maximum" && num > limit)) finding(ctx, "value.bound", "error", paste("Value violates declared", bound), name, i + 1L, field, value)
          }
        }
        if (type == "boolean" && !value %in% c("TRUE", "FALSE")) finding(ctx, "value.boolean", "error", "Boolean must use consistent TRUE/FALSE representation or an explicit categorical profile", name, i + 1L, field, value)
        if (!is.null(values) && !value %in% values) finding(ctx, "value.controlled_code", "error", "Value absent from declared controlled vocabulary", name, i + 1L, field, value)
        if (!is.null(values) && value != trimws(value)) finding(ctx, "value.code_whitespace", "error", "Controlled code has leading/trailing whitespace", name, i + 1L, field, value)
      }
    }
    coverage(ctx, "declared_values", "assessed", paste(declared, "fields have selective type declarations"), name)
    coverage(ctx, "undeclared_units_and_semantics", "not_assessed", "Units, scale, and scientific bounds cannot be inferred for undeclared fields", name)
  }
}
valid_date <- function(x) {
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) return(FALSE)
  d <- suppressWarnings(tryCatch(as.Date(x, format = "%Y-%m-%d"), error = function(e) NA))
  !is.na(d) && format(d, "%Y-%m-%d") == x
}
valid_clock <- function(x) {
  if (!grepl("^[0-9]{2}:[0-9]{2}(?::[0-9]{2}(?:\\.[0-9]+)?)?$", x, perl = TRUE)) return(FALSE)
  parts <- as.numeric(strsplit(x, ":", fixed = TRUE)[[1]])
  parts[1] < 24 && parts[2] < 60 && (length(parts) == 2L || parts[3] < 60)
}
duration_seconds <- function(x) {
  match <- regmatches(x, regexec("^P(?:(\\d+(?:\\.\\d+)?)D)?(?:T(?:(\\d+(?:\\.\\d+)?)H)?(?:(\\d+(?:\\.\\d+)?)M)?(?:(\\d+(?:\\.\\d+)?)S)?)?$", x, perl = TRUE))[[1]]
  if (!length(match) || !grepl("[0-9]", x)) return(NA_real_)
  numbers <- suppressWarnings(as.numeric(match[-1])); numbers[is.na(numbers)] <- 0
  sum(numbers * c(86400, 3600, 60, 1))
}
validate_temporal_fields <- function(ctx) {
  for (name in names(ctx$tables)) {
    tab <- ctx$tables[[name]]
    if (!tab$usable || !tab$role %in% c("data", "ref")) next
    for (field in setdiff(names(tab$data), tab$excluded)) {
      rule <- field_rule(ctx, name, field); type <- scalar(rule$type)
      inferred <- if (grepl("_datetime$", field)) "datetime" else if (grepl("_date$", field)) "date" else if (grepl("_time$", field)) "time" else ""
      if (!nzchar(type)) type <- inferred
      native <- unique(tab$types[, field]); native <- setdiff(native, "blank")
      if (!nzchar(type) && length(native) == 1L && native %in% c("date", "datetime", "time", "duration")) type <- native
      if (!type %in% c("date", "datetime", "time", "duration", "partial_date")) next
      zone <- scalar(rule$timezone, scalar(ctx$metadata$timezone))
      if (nzchar(zone) && !zone %in% c("unknown", "UTC", OlsonNames())) finding(ctx, "temporal.timezone", "error", "Unknown timezone declaration", name, field = field, value = zone)
      x <- tab$data[[field]]
      for (i in which(!is.na(x))) {
        value <- x[i]; valid <- TRUE
        if (type == "date") valid <- valid_date(value)
        if (type == "time") {
          if (tab$types[i, field] == "duration") {
            seconds <- duration_seconds(value)
            if (is.finite(seconds) && seconds >= 0 && seconds < 86400) {
              # A declared clock field resolves the ODS duration/clock ambiguity.
              value <- excel_temporal(seconds / 86400, "time", FALSE)$value
              tab$data[[field]][i] <- value
              finding(ctx, "temporal.clock_serialization", "information", "ODS typed time serialized as the declared clock field", name, i + 1L, field, x[i])
            }
          }
          valid <- valid_clock(value)
          if (!nzchar(zone)) finding(ctx, "temporal.timezone_missing", "error", "Clock field requires timezone or explicit 'unknown'", name, i + 1L, field)
        }
        if (type == "datetime") {
          pieces <- strsplit(value, "T", fixed = TRUE)[[1]]
          offset <- regmatches(value, regexpr("(?:Z|[+-][0-9]{2}:[0-9]{2})$", value, perl = TRUE))
          time <- if (length(pieces) == 2L) sub("(?:Z|[+-][0-9]{2}:[0-9]{2})$", "", pieces[2], perl = TRUE) else ""
          valid <- length(pieces) == 2L && valid_date(pieces[1]) && valid_clock(time)
          if (length(offset) && nzchar(offset) && offset != "Z") {
            offsets <- as.numeric(strsplit(sub("^[+-]", "", offset), ":", fixed = TRUE)[[1]])
            valid <- valid && offsets[1] <= 23 && offsets[2] <= 59
          }
          if ((!length(offset) || !nzchar(offset)) && !nzchar(zone)) finding(ctx, "temporal.timezone_missing", "error", "Naive timestamp requires timezone or explicit 'unknown'; UTC is not inferred", name, i + 1L, field, value)
        }
        if (type == "duration") {
          valid <- is.finite(duration_seconds(value)) || (strict_number(value) && nzchar(scalar(rule$unit)) && as.numeric(value) >= 0)
        }
        if (type == "partial_date") valid <- grepl("^[0-9]{4}(?:-(?:0[1-9]|1[0-2]))?$", value, perl = TRUE) || valid_date(value)
        if (!valid) finding(ctx, "temporal.invalid", "error", paste("Invalid or ambiguous", type, "value; original representation retained"), name, i + 1L, field, x[i])
      }
      if (zone == "unknown") coverage(ctx, "temporal_instant", "not_assessed", "Timezone explicitly unknown; no invented UTC conversion", name)
      coverage(ctx, paste0("temporal_", field), "assessed", sheet = name)
    }
    ctx$tables[[name]] <- tab
  }
}
validate_toponymy <- function(ctx) {
  fields <- metadata_json(ctx, "toponym_fields", list())
  if (!length(fields)) { coverage(ctx, "toponymy", "not_assessed", "No topographical reference mapping declared; live geocoding is opt-in"); return(invisible(NULL)) }
  for (name in names(fields)) {
    tab <- ctx$tables[[name]]; map <- fields[[name]]
    if (is.null(tab) || !tab$usable) { finding(ctx, "toponymy.mapping", "error", "Toponymy mapping names an unavailable table", name); next }
    required <- c("name", "osm_type", "osm_id", "status")
    mapped <- vapply(required, function(x) scalar(map[[x]], x), character(1))
    if (!all(mapped %in% setdiff(names(tab$data), tab$excluded))) { finding(ctx, "toponymy.fields", "error", "Mapping must identify name, osm_type, osm_id, status fields", name); next }
    for (i in seq_len(nrow(tab$data))) {
      get <- function(k) tab$data[[mapped[k]]][i]
      status <- get("status")
      if (is.na(status) || !status %in% c("node_exact", "osm_fallback", "ambiguous", "unresolved")) finding(ctx, "toponymy.status", "error", "Missing or unknown resolution status", name, i + 1L)
      else if (status != "node_exact") finding(ctx, "toponymy.review", "warning", paste("Review", status, "reference before adopting locality identity"), name, i + 1L)
      if (!is.na(status) && status != "unresolved" && (is.na(get("name")) || !get("osm_type") %in% c("node", "way", "relation") || is.na(get("osm_id")) || !grepl("^[0-9]+$", get("osm_id")))) finding(ctx, "toponymy.reference", "error", "Resolved reference needs a name and valid OSM type/identifier", name, i + 1L)
      if (identical(status, "node_exact") && !identical(get("osm_type"), "node")) finding(ctx, "toponymy.node_status", "error", "node_exact status conflicts with non-node object", name, i + 1L)
    }
    coverage(ctx, "toponymy", "assessed", "Field consistency only; automated matches and run dates do not certify human verification", name)
  }
}
