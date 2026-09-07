parse_coordinate <- function(value, axis, decimal_mark = ".", format = "auto") {
  fail <- function(reason) list(value = NA_real_, method = "unresolved", error = reason)
  if (is.na(value)) return(list(value = NA_real_, method = "missing", error = ""))
  text <- trimws(gsub("−", "-", value, fixed = TRUE))
  hemisphere <- character()
  if (grepl("^[NSEW]", text, ignore.case = TRUE)) { hemisphere <- c(hemisphere, toupper(substr(text, 1, 1))); text <- trimws(substring(text, 2)) }
  if (grepl("[NSEW]$", text, ignore.case = TRUE)) { hemisphere <- c(hemisphere, toupper(substring(text, nchar(text)))); text <- trimws(substr(text, 1, nchar(text) - 1L)) }
  if (length(hemisphere) > 1L) return(fail("More than one hemisphere marker"))
  if (!format %in% c("auto", "dd", "dm", "dms")) return(fail("Unknown coordinate format declaration"))
  if (length(hemisphere) && !hemisphere %in% (if (axis == "latitude") c("N", "S") else c("E", "W"))) return(fail("Hemisphere marker conflicts with coordinate axis"))
  if (!decimal_mark %in% c(".", ",")) return(fail("Declare decimal_mark as '.' or ','"))
  if (grepl(",", text, fixed = TRUE)) {
    if (decimal_mark != "," || grepl(".", text, fixed = TRUE)) return(fail("Ambiguous decimal/grouping separator"))
    text <- gsub(",", ".", text, fixed = TRUE)
  }
  numeric_pattern <- "^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"
  if (grepl("[°º]$", text) && grepl(numeric_pattern, trimws(sub("[°º]$", "", text)), perl = TRUE)) text <- trimws(sub("[°º]$", "", text))
  if (grepl(numeric_pattern, text, perl = TRUE)) {
    if (!format %in% c("auto", "dd")) return(fail("Value is not in the declared sexagesimal representation"))
    number <- suppressWarnings(as.numeric(text)); method <- "decimal_degrees"
  } else {
    marked <- grepl("[°º'\"′″’:d]", text, perl = TRUE)
    if (format == "dd" || (!marked && format == "auto")) return(fail("Coordinate representation is not unambiguous"))
    symbols <- gsub("[ºd]", "°", text)
    symbols <- gsub("[′’]", "'", symbols)
    symbols <- gsub("″", "\"", symbols, fixed = TRUE)
    colon_form <- grepl("^[+-]?[0-9]+\\s*:\\s*[0-9]+(?:\\.[0-9]+)?(?:\\s*:\\s*[0-9]+(?:\\.[0-9]+)?)?$", symbols, perl = TRUE)
    symbol_form <- grepl("^[+-]?[0-9]+\\s*°\\s*[0-9]+(?:\\.[0-9]+)?\\s*'(?:\\s*[0-9]+(?:\\.[0-9]+)?\\s*\")?$", symbols, perl = TRUE)
    if (marked && !colon_form && !symbol_form) return(fail("Degree, minute, and second markers are incomplete or out of order"))
    stripped <- gsub("[°º'\"′″’:d]", " ", text, perl = TRUE)
    parts <- strsplit(trimws(stripped), "[[:space:]]+")[[1]]
    if (!length(parts) %in% c(2L, 3L) || !all(grepl("^[+-]?[0-9]+(?:\\.[0-9]+)?$", parts, perl = TRUE))) return(fail("Invalid degrees/minutes/seconds syntax"))
    nums <- as.numeric(parts)
    if (nums[1] != trunc(nums[1]) || any(nums[-1] < 0) || any(nums[-1] >= 60) || (length(nums) == 3L && nums[2] != trunc(nums[2]))) return(fail("Invalid degree, minute, or second components"))
    if ((format == "dms" && length(nums) != 3L) || (format == "dm" && length(nums) != 2L)) return(fail("Value conflicts with declared coordinate format"))
    number <- abs(nums[1]) + nums[2] / 60 + if (length(nums) == 3L) nums[3] / 3600 else 0
    if (startsWith(parts[1], "-")) number <- -number
    method <- if (length(nums) == 3L) "degrees_minutes_seconds" else "degrees_decimal_minutes"
  }
  if (length(hemisphere)) {
    negative <- hemisphere %in% c("S", "W")
    if ((startsWith(text, "-") && !negative) || (startsWith(text, "+") && negative)) return(fail("Explicit sign conflicts with hemisphere"))
    number <- abs(number) * if (negative) -1 else 1
    method <- paste0(method, "_hemisphere")
  }
  bound <- if (axis == "latitude") 90 else 180
  if (!is.finite(number) || abs(number) > bound) return(fail(paste("Coordinate outside", -bound, "to", bound)))
  list(value = number, method = method, error = "")
}
coordinate_mapping <- function(ctx, name, tab) {
  # Explicit source-side metadata takes precedence. Multiple pairs require explicit roles.
  map <- metadata_json(ctx, "coordinate_fields", list())[[name]]
  if (!is.null(map)) return(map)
  fields <- setdiff(names(tab$data), tab$excluded)
  lat <- fields[tolower(fields) %in% c("latitude", "lat", "decimal_latitude", "latitude_dd")]
  lon <- fields[tolower(fields) %in% c("longitude", "lon", "long", "lng", "decimal_longitude", "longitude_dd")]
  if (!length(lat) && !length(lon)) {
    if (any(tolower(fields) %in% c("x", "y", "easting", "northing"))) finding(ctx, "coordinate.mapping_required", "error", "Projected/generic axes require explicit coordinate_fields and a source CRS", name)
    coverage(ctx, "coordinates", if (any(fields %in% c("x", "y", "easting", "northing"))) "not_assessed" else "not_applicable", "No unambiguous latitude/longitude field pair", name)
    return(NULL)
  }
  if (length(lat) != 1L || length(lon) != 1L) {
    finding(ctx, "coordinate.ambiguous_fields", "error", "Missing partner or multiple candidate coordinate fields; declare coordinate_fields", name)
    return(NULL)
  }
  list(latitude = lat, longitude = lon, crs = scalar(ctx$metadata$coordinate_crs),
       decimal_mark = scalar(ctx$metadata$coordinate_decimal_mark, "."), format = "auto")
}
validate_coordinates <- function(ctx) {
  for (name in names(ctx$tables)) {
    tab <- ctx$tables[[name]]
    if (!tab$usable || !tab$role %in% c("data", "ref")) next
    map <- coordinate_mapping(ctx, name, tab); if (is.null(map)) next
    lat_field <- scalar(map$latitude); lon_field <- scalar(map$longitude)
    if (!all(c(lat_field, lon_field) %in% setdiff(names(tab$data), tab$excluded)) || lat_field == lon_field) {
      finding(ctx, "coordinate.mapping_invalid", "error", "Coordinate mapping must name two distinct retained fields", name); next
    }
    crs <- scalar(map$crs, scalar(ctx$metadata$coordinate_crs))
    if (!nzchar(crs)) { finding(ctx, "coordinate.crs_unknown", "error", "Declare source CRS; numeric ranges do not establish WGS84", name); coverage(ctx, "coordinate_crs", "not_assessed", "Missing CRS", name); next }
    geographic <- toupper(crs) %in% c("EPSG:4326", "OGC:CRS84", "WGS84")
    n <- nrow(tab$data)
    output <- data.frame(source_row = seq_len(n) + 1L,
      source_id = if (nzchar(tab$key_field)) tab$data[[tab$key_field]] else rep(NA_character_, n),
      latitude_original = tab$data[[lat_field]], longitude_original = tab$data[[lon_field]],
      latitude_dd = rep(NA_real_, n), longitude_dd = rep(NA_real_, n),
      source_crs = rep(crs, n), target_crs = rep("OGC:CRS84", n), conversion_method = rep("", n),
      status = rep("unresolved", n), stringsAsFactors = FALSE)
    if (!geographic && !requireNamespace("sf", quietly = TRUE)) {
      finding(ctx, "coordinate.transform_dependency", "error", "Install sf for explicit CRS transformations; coordinates were not guessed", name); next
    }
    for (i in seq_len(n)) {
      lat <- tab$data[[lat_field]][i]; lon <- tab$data[[lon_field]][i]
      if (is.na(lat) && is.na(lon)) {
        output$status[i] <- "missing"
        if (isTRUE(map$required)) finding(ctx, "coordinate.required", "error", "Required coordinate pair is missing", name, i + 1L)
        next
      }
      if (is.na(lat) || is.na(lon)) { finding(ctx, "coordinate.incomplete_pair", "error", "Only one coordinate is present", name, i + 1L); next }
      if (geographic) {
        a <- parse_coordinate(lat, "latitude", scalar(map$decimal_mark, "."), scalar(map$format, "auto"))
        b <- parse_coordinate(lon, "longitude", scalar(map$decimal_mark, "."), scalar(map$format, "auto"))
        for (axis in c("latitude", "longitude")) {
          result <- if (axis == "latitude") a else b
          if (nzchar(result$error)) finding(ctx, "coordinate.invalid", "error", result$error, name, i + 1L,
                                           if (axis == "latitude") lat_field else lon_field, if (axis == "latitude") lat else lon)
        }
        if (nzchar(a$error) || nzchar(b$error)) next
        output$latitude_dd[i] <- a$value; output$longitude_dd[i] <- b$value
        output$conversion_method[i] <- paste(a$method, b$method, sep = ";")
      } else {
        if (!all(grepl("^[+-]?[0-9]+(?:\\.[0-9]+)?$", c(lat, lon), perl = TRUE))) {
          finding(ctx, "coordinate.projected_syntax", "error", "Projected coordinates require explicit numeric x/y values", name, i + 1L); next
        }
        transformed <- tryCatch({
          point <- sf::st_sfc(sf::st_point(c(as.numeric(lon), as.numeric(lat))), crs = crs)
          xy <- sf::st_coordinates(sf::st_transform(point, crs = "OGC:CRS84", allow_ballpark = FALSE))
          if (nrow(xy) != 1L || any(!is.finite(xy)) || abs(xy[1, 1]) > 180 || abs(xy[1, 2]) > 90) stop("Invalid transformation result")
          xy
        }, error = identity)
        if (inherits(transformed, "error")) { finding(ctx, "coordinate.transform_failed", "error", conditionMessage(transformed), name, i + 1L); next }
        output$longitude_dd[i] <- transformed[1, 1]; output$latitude_dd[i] <- transformed[1, 2]
        output$conversion_method[i] <- "explicit_crs_transform"
      }
      output$status[i] <- "converted"
      bounds <- unlist(map$bounds)
      if (length(bounds) == 4L && (output$longitude_dd[i] < bounds[1] || output$latitude_dd[i] < bounds[2] || output$longitude_dd[i] > bounds[3] || output$latitude_dd[i] > bounds[4])) finding(ctx, "coordinate.expected_extent", "warning", "Coordinate is outside declared review bounds; do not automatically swap axes or remove it", name, i + 1L)
    }
    # Display strings are separate from full precision numeric derived fields.
    if (!is.null(map$display_digits)) {
      digits <- as.integer(map$display_digits)
      if (is.na(digits) || digits < 0 || digits > 15) finding(ctx, "coordinate.display_digits", "error", "display_digits must be 0..15", name)
      else {
        output$latitude_display <- ifelse(is.na(output$latitude_dd), NA_character_, formatC(output$latitude_dd, format = "f", digits = digits))
        output$longitude_display <- ifelse(is.na(output$longitude_dd), NA_character_, formatC(output$longitude_dd, format = "f", digits = digits))
      }
    }
    ctx$derived[[name]] <- output
    coverage(ctx, "coordinates", "assessed", "Representation and bounds checked; positional accuracy and actual sampling identity require evidence", name)
  }
}
standardize_coordinates <- function(ctx) {
  for (name in names(ctx$derived)) {
    path <- file.path(ctx$run_dir, "derived", paste0(name, "__coordinates.csv"))
    write_character_csv(ctx$derived[[name]], path, scalar(ctx$config$missing_token, "\\N"))
  }
}
