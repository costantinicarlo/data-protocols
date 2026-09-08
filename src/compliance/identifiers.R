finite_integer_declaration <- function(x, lower, upper) is.numeric(x) && length(x) == 1L && is.finite(x) && x == trunc(x) && x >= lower && x <= upper
collection_profile <- function(ctx, profile, sheet, field) {
  digits <- if ("serial_width" %in% names(profile)) profile$serial_width else 5L
  year_digits <- if ("year_digits" %in% names(profile)) profile$year_digits else 2L
  if (!finite_integer_declaration(digits, 1, 30) || !finite_integer_declaration(year_digits, 2, 4) || !year_digits %in% c(2, 4)) {
    finding(ctx, "identifier.profile_definition", "error", "serial_width must be an integer 1..30 and year_digits must be 2 or 4", sheet, field = field); return(NULL)
  }
  years <- profile$year_range
  if ((!is.list(years) && !is.numeric(years)) || !is.null(names(years)) || length(years) != 2L ||
      !all(vapply(years, finite_integer_declaration, logical(1), lower = 0, upper = 9999))) {
    finding(ctx, "identifier.year_range", "error", "year_range must be two integer years in 0..9999", sheet, field = field); return(NULL)
  }
  years <- unlist(years, use.names = FALSE)
  if (years[1] > years[2] || (year_digits == 2 && years[2] - years[1] > 99)) {
    finding(ctx, "identifier.year_range", "error", "Ordered year_range required; two-digit years allow at most 100 distinct suffixes", sheet, field = field); return(NULL)
  }
  list(digits = as.integer(digits), year_digits = as.integer(year_digits), years = years)
}
validate_identifiers <- function(ctx) {
  profiles <- metadata_json(ctx, "identifier_profiles", list())
  codes <- read.delim(file.path(COMPLIANCE_ROOT, "references", "iso3166.tab"), comment.char = "#", header = FALSE, colClasses = "character", quote = "")[[1]]
  for (name in names(ctx$tables)) {
    tab <- ctx$tables[[name]]
    if (!tab$usable || !tab$role %in% c("data", "ref") || !nzchar(tab$key_field)) next
    fields <- unique(c(tab$key_field, names(tab$data)[vapply(names(tab$data), function(f) nzchar(scalar(field_rule(ctx, name, f)$identifier_profile)), logical(1))]))
    for (field in setdiff(fields, tab$excluded)) {
      values <- tab$data[[field]]
      rule <- field_rule(ctx, name, field)
      profile_name <- scalar(rule$identifier_profile, scalar(ctx$metadata$default_identifier_profile))
      profile <- profiles[[profile_name]]
      if (is.null(profile)) {
        finding(ctx, "identifier.profile_missing", "error", "Declare an identifier_profile in meta__fields (or workbook default) and its definition in identifier_profiles", name, field = field)
        coverage(ctx, "identifier_profile", "not_assessed", "Missing profile", name)
      }
      namespace <- scalar(profile$namespace)
      if (!is.null(profile) && !nzchar(namespace)) finding(ctx, "identifier.namespace", "error", "Identifier profile needs a stable namespace", name, field = field)
      if (!is.null(profile) && !scalar(profile$type, "regex") %in% c("field_collection", "regex", "legacy", "external")) {
        finding(ctx, "identifier.profile_definition", "error", "Unknown identifier profile type", name, field = field, value = scalar(profile$type))
      }
      collection <- if (!is.null(profile) && scalar(profile$type) == "field_collection") collection_profile(ctx, profile, name, field) else NULL
      declaration <- validated_field_rule(ctx, name, field)
      for (i in seq_along(values)) {
        value <- values[i]
        required <- field == tab$key_field || scalar(rule$required) == "true"
        if (is.na(value)) {
          if (required) finding(ctx, "identifier.missing", "error", "Required identifier is blank", name, i + 1L, field)
          next
        }
        if (legacy_missing(value, declaration)) {
          finding(ctx, "identifier.missing", "error", "A legacy missing code is not an assigned identity", name, i + 1L, field, value); next
        }
        if (tab$types[i, field] != "text") finding(ctx, "identifier.storage", "error", "Identifier is not stored as literal text", name, i + 1L, field, value)
        if (value != trimws(value)) finding(ctx, "identifier.whitespace", "error", "Identifier contains leading/trailing whitespace", name, i + 1L, field, value, "Reconcile against source assignment; do not silently trim")
        if (is.null(profile)) next
        type <- scalar(profile$type, "regex")
        pattern <- scalar(profile$pattern)
        width <- profile$width
        if (type == "field_collection") {
          if (is.null(collection)) next
          digits <- collection$digits; year_digits <- collection$year_digits
          suffix <- scalar(profile$child_pattern)
          pattern <- paste0("^[A-Z]{2}[0-9]{", year_digits, "}_[0-9]{", digits, "}", suffix, "$")
          if (grepl(pattern, value, perl = TRUE)) {
            country <- substr(value, 1, 2)
            if (!country %in% codes) finding(ctx, "identifier.country", "error", "Country prefix is not in the bundled country-code list", name, i + 1L, field, value)
            serial <- substr(value, 4L + year_digits, 3L + year_digits + digits)
            if (grepl("^0+$", serial)) finding(ctx, "identifier.zero_serial", "error", "Zero serial is reserved as unissued", name, i + 1L, field, value)
            years <- collection$years
            yr <- as.integer(substr(value, 3, 2L + year_digits))
            valid_year <- if (year_digits == 4L) yr >= years[1] && yr <= years[2] else yr %in% (seq.int(years[1], years[2]) %% 100)
            if (!valid_year) finding(ctx, "identifier.year", "error", "Year prefix lies outside the declared collection range", name, i + 1L, field, value)
            if (nzchar(suffix) && grepl("_0+$|_[A-Z]+0+$", substring(value, 4L + year_digits + digits))) finding(ctx, "identifier.zero_child", "error", "Zero child serial is reserved as unissued", name, i + 1L, field, value)
          }
        }
        if (!nzchar(pattern)) { finding(ctx, "identifier.profile_pattern", "error", "Profile requires an explicit pattern", name, field = field); break }
        matches <- tryCatch(grepl(pattern, value, perl = TRUE), error = function(e) FALSE)
        if (!matches) finding(ctx, "identifier.syntax", "error", paste("Identifier does not match profile", profile_name), name, i + 1L, field, value)
        if (!is.null(width) && nchar(value) != as.integer(width)) finding(ctx, "identifier.width", "error", "Identifier has incorrect fixed width", name, i + 1L, field, value)
        if (!type %in% c("legacy", "external") && !grepl("^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*$", value, perl = TRUE)) finding(ctx, "identifier.lexical", "error", "New project identifier violates the uppercase ASCII lexical rule", name, i + 1L, field, value)
      }
      if (field == tab$key_field && tab$key_scope == "row") {
        duplicate <- duplicated(values) | duplicated(values, fromLast = TRUE)
        for (i in which(duplicate & !is.na(values))) finding(ctx, "identifier.duplicate_row_key", "error", "Repeated row key", name, i + 1L, field, values[i])
      }
      coverage(ctx, "identifier_profile", if (is.null(profile)) "not_assessed" else "assessed", sheet = name)
    }
  }
  # Register and aliases are optional, but missing evidence is always explicit.
  registry <- ctx$reference_data$registry
  if (is.null(registry)) coverage(ctx, "assignment_uniqueness_and_retirement", "not_assessed", "No authoritative current/retired allocation register supplied")
  else if (!require_columns(registry, c("namespace", "identifier", "entity_reference", "status"))) finding(ctx, "identifier.registry_layout", "error", "Registry needs namespace, identifier, entity_reference, status")
  else {
    required_values <- as.matrix(registry[, c("namespace", "identifier", "entity_reference", "status")])
    if (anyNA(required_values) || any(!nzchar(required_values))) finding(ctx, "identifier.registry_missing", "error", "Allocation register has blank required values")
    key <- paste(registry$namespace, registry$identifier, sep = "\r")
    if (anyDuplicated(key)) finding(ctx, "identifier.registry_collision", "error", "Allocation register contains duplicate namespace/identifier assignments")
    previous <- ctx$previous_reference_data$registry
    if (!is.null(previous) && require_columns(previous, c("namespace", "identifier", "entity_reference"))) {
      prior_key <- paste(previous$namespace, previous$identifier, sep = "\r")
      if (length(setdiff(prior_key, key))) finding(ctx, "identifier.registry_removed", "error", "Previously registered identifiers were removed; retain retirement history")
      common <- intersect(prior_key, key)
      for (id in common) if (!identical(previous$entity_reference[match(id, prior_key)], registry$entity_reference[match(id, key)])) finding(ctx, "identifier.registry_reassignment", "error", "Previously validated identifier now points to another entity_reference; adjudicate rather than silently reassign", value = gsub("\r", ":", id))
    }
    for (name in names(ctx$tables)) {
      tab <- ctx$tables[[name]]
      if (!tab$usable || !nzchar(tab$key_field)) next
      rule <- field_rule(ctx, name, tab$key_field)
      p <- profiles[[scalar(rule$identifier_profile, scalar(ctx$metadata$default_identifier_profile))]]
      ns <- scalar(p$namespace)
      for (i in seq_len(nrow(tab$data))) {
        id <- tab$data[[tab$key_field]][i]; if (is.na(id)) next
        found <- which(key == paste(ns, id, sep = "\r"))
        if (!length(found)) finding(ctx, "identifier.unregistered", "error", "Identifier absent from supplied authoritative allocation register", name, i + 1L, tab$key_field, id)
        else if (registry$status[found[1]] %in% c("retired", "void", "consumed", "missing")) finding(ctx, "identifier.retired_reference", "information", "Historical observation refers to a retired/consumed identifier; this alone is not reassignment", name, i + 1L, tab$key_field, id)
      }
    }
    coverage(ctx, "assignment_uniqueness_and_retirement", "assessed", "Register consistency checked; physical identity and undocumented reuse remain outside available evidence")
  }
  aliases <- ctx$reference_data$aliases
  if (is.null(aliases)) coverage(ctx, "provider_aliases", "not_assessed", "No provider mapping supplied")
  else if (!require_columns(aliases, c("provider", "external_id", "namespace", "identifier"))) finding(ctx, "identifier.alias_layout", "error", "Alias table requires provider, external_id, namespace, identifier")
  else {
    groups <- split(seq_len(nrow(aliases)), paste(aliases$provider, aliases$external_id, sep = "\r"))
    for (idx in groups) if (length(unique(paste(aliases$namespace[idx], aliases$identifier[idx]))) > 1L) finding(ctx, "identifier.alias_collision", "error", "A provider accession maps to several project identifiers", value = aliases$external_id[idx[1]])
    coverage(ctx, "provider_aliases", "assessed")
  }
  coverage(ctx, "physical_labels_and_identity", "not_assessed", "A workbook cannot certify label attachment, scanning, or undocumented identity changes")
}
validate_lineage <- function(ctx) {
  lineage <- ctx$reference_data$lineage
  if (is.null(lineage)) { coverage(ctx, "lineage", "not_assessed", "No lineage table selected"); return(invisible(NULL)) }
  if (!require_columns(lineage, c("namespace", "child_id", "parent_id", "relationship"))) {
    finding(ctx, "lineage.layout", "error", "Lineage requires namespace, child_id, parent_id, relationship (optional parent_namespace)"); return(invisible(NULL))
  }
  parent_ns <- if ("parent_namespace" %in% names(lineage)) lineage$parent_namespace else lineage$namespace
  child <- paste(lineage$namespace, lineage$child_id, sep = "\r")
  parent <- paste(parent_ns, lineage$parent_id, sep = "\r")
  if (anyNA(lineage[, c("namespace", "child_id", "parent_id", "relationship")]) || any(!nzchar(lineage$child_id) | !nzchar(lineage$parent_id) | !nzchar(lineage$relationship))) finding(ctx, "lineage.missing", "error", "Lineage contains blank identities or relationship types")
  if (any(child == parent)) finding(ctx, "lineage.self_parent", "error", "Entity is its own parent")
  edges <- split(parent, child)
  visited <- new.env(hash = TRUE, parent = emptyenv()); active <- new.env(hash = TRUE, parent = emptyenv())
  visit <- function(node) {
    if (isTRUE(active[[node]])) return(TRUE)
    if (isTRUE(visited[[node]])) return(FALSE)
    active[[node]] <- TRUE
    cycle <- any(vapply(edges[[node]] %||% character(), visit, logical(1)))
    active[[node]] <- FALSE; visited[[node]] <- TRUE
    cycle
  }
  if (any(vapply(unique(child), visit, logical(1)))) finding(ctx, "lineage.cycle", "error", "Parent-child graph contains a cycle")
  registry <- ctx$reference_data$registry
  if (!is.null(registry) && require_columns(registry, c("namespace", "identifier"))) {
    known <- paste(registry$namespace, registry$identifier, sep = "\r")
    for (id in setdiff(unique(c(child, parent)), known)) finding(ctx, "lineage.unknown_entity", "error", "Lineage reference absent from allocation register", value = gsub("\r", ":", id))
  } else coverage(ctx, "lineage_reference_existence", "not_assessed", "No allocation register")
  coverage(ctx, "lineage", "assessed", "Recorded relationships checked, not actual material provenance")
}
