#!/usr/bin/env Rscript

# osm_toponym.R
#
# Resolve latitude/longitude coordinates to canonical OpenStreetMap
# settlement/locality references using Nominatim.
#
# Input:
#   CSV containing at least:
#     id, latitude, longitude
#
# Output:
#   GeoJSON FeatureCollection
#
# Example:
#   Rscript osm_toponym.R sites.csv toponyms.geojson
#
# Dependencies:
#   install.packages(c("httr2", "jsonlite"))
#
# IMPORTANT:
#   The public Nominatim service permits at most 1 request/second.
#   A meaningful User-Agent is required.
#
#   For substantial recurring workloads, use a locally hosted Nominatim
#   instance or another policy-compliant OSM geocoding service.

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
})

# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------

NOMINATIM_URL <- "https://nominatim.openstreetmap.org/reverse"

# Identify your application/project clearly.
# Replace the contact information with an appropriate project contact.
USER_AGENT <- paste0(
  "scientific-toponymy/1.0 ",
  "(research use; contact: your.email@example.org)"
)

# Nominatim zoom levels:
# 13 = village/suburb
# 14 = neighbourhood
# 15 = any settlement
#
# 15 is a useful default for ecological/field localities.
ZOOM <- 15L

# Public server limit is <= 1 request/sec.
REQUEST_DELAY <- 1.05


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

stop_bad_coordinates <- function(lat, lon, id = NA_character_) {

  if (
    is.na(lat) || is.na(lon) ||
    !is.finite(lat) || !is.finite(lon) ||
    lat < -90 || lat > 90 ||
    lon < -180 || lon > 180
  ) {
    stop(
      sprintf(
        "Invalid coordinates for '%s': latitude=%s longitude=%s",
        id, lat, lon
      ),
      call. = FALSE
    )
  }
}


osm_url <- function(osm_type, osm_id) {

  if (is.null(osm_type) || is.null(osm_id) ||
      is.na(osm_type) || is.na(osm_id)) {
    return(NA_character_)
  }

  sprintf(
    "https://www.openstreetmap.org/%s/%s",
    osm_type,
    osm_id
  )
}


reverse_osm <- function(lat, lon) {

  req <- request(NOMINATIM_URL) |>
    req_user_agent(USER_AGENT) |>
    req_url_query(
      format = "jsonv2",
      lat = lat,
      lon = lon,
      zoom = ZOOM,
      layer = "address",
      addressdetails = 1,
      namedetails = 1
    ) |>
    req_retry(
      max_tries = 4,
      backoff = ~ 2^.x
    )

  resp <- req_perform(req)

  resp_body_json(
    resp,
    simplifyVector = FALSE
  )
}


first_nonempty <- function(...) {

  values <- list(...)

  for (x in values) {
    if (!is.null(x) &&
        length(x) > 0 &&
        !is.na(x[[1]]) &&
        nzchar(as.character(x[[1]]))) {
      return(as.character(x[[1]]))
    }
  }

  NA_character_
}


extract_name <- function(x) {

  # Prefer the actual name attached to the returned OSM object.
  if (!is.null(x$name) && nzchar(x$name)) {
    return(x$name)
  }

  # Defensive fallback if Nominatim supplies the settlement through
  # address components rather than x$name.
  address <- x$address

  first_nonempty(
    address$hamlet,
    address$village,
    address$town,
    address$city,
    address$municipality,
    address$suburb,
    address$neighbourhood
  )
}


make_feature <- function(source_id, query_lat, query_lon, x) {

  canonical_name <- extract_name(x)

  returned_lat <- suppressWarnings(as.numeric(x$lat))
  returned_lon <- suppressWarnings(as.numeric(x$lon))

  if (!is.finite(returned_lat) || !is.finite(returned_lon)) {
    returned_lat <- query_lat
    returned_lon <- query_lon
  }

  country_code <- if (!is.null(x$address$country_code)) {
    x$address$country_code
  } else {
    NA_character_
  }

  list(
    type = "Feature",

    geometry = list(
      type = "Point",
      coordinates = list(
        returned_lon,
        returned_lat
      )
    ),

    properties = list(
      source_id = source_id,

      name = canonical_name,

      reference_system = "OpenStreetMap",

      osm_type = x$osm_type,
      osm_id = x$osm_id,

      osm_url = osm_url(
        x$osm_type,
        x$osm_id
      ),

      verified = format(
        Sys.Date(),
        "%Y-%m-%d"
      ),

      country_code = country_code,

      osm_category = x$category,
      osm_place_type = x$type,

      display_name = x$display_name,

      query_latitude = query_lat,
      query_longitude = query_lon
    )
  )
}


make_unresolved_feature <- function(
    source_id,
    query_lat,
    query_lon,
    message = NA_character_
) {

  list(
    type = "Feature",

    geometry = list(
      type = "Point",
      coordinates = list(
        query_lon,
        query_lat
      )
    ),

    properties = list(
      source_id = source_id,

      name = NA_character_,

      reference_system = "OpenStreetMap",

      osm_type = NA_character_,
      osm_id = NA_character_,
      osm_url = NA_character_,

      verified = format(
        Sys.Date(),
        "%Y-%m-%d"
      ),

      status = "unresolved",
      message = message,

      query_latitude = query_lat,
      query_longitude = query_lon
    )
  )
}


# -------------------------------------------------------------------
# Batch processing
# -------------------------------------------------------------------

resolve_toponyms <- function(data) {

  required <- c(
    "id",
    "latitude",
    "longitude"
  )

  missing <- setdiff(
    required,
    names(data)
  )

  if (length(missing) > 0) {
    stop(
      paste(
        "Missing required columns:",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  features <- vector(
    "list",
    nrow(data)
  )

  for (i in seq_len(nrow(data))) {

    source_id <- as.character(data$id[[i]])
    lat <- as.numeric(data$latitude[[i]])
    lon <- as.numeric(data$longitude[[i]])

    stop_bad_coordinates(
      lat,
      lon,
      source_id
    )

    message(
      sprintf(
        "[%d/%d] %s: %.6f, %.6f",
        i,
        nrow(data),
        source_id,
        lat,
        lon
      )
    )

    result <- tryCatch(
      reverse_osm(lat, lon),
      error = function(e) e
    )

    if (inherits(result, "error")) {

      warning(
        sprintf(
          "Could not resolve %s: %s",
          source_id,
          conditionMessage(result)
        ),
        call. = FALSE
      )

      features[[i]] <- make_unresolved_feature(
        source_id,
        lat,
        lon,
        conditionMessage(result)
      )

    } else {

      features[[i]] <- make_feature(
        source_id,
        lat,
        lon,
        result
      )
    }

    # Respect the public Nominatim usage policy.
    if (i < nrow(data)) {
      Sys.sleep(REQUEST_DELAY)
    }
  }

  list(
    type = "FeatureCollection",

    attribution =
      "© OpenStreetMap contributors, ODbL 1.0",

    generated = format(
      Sys.time(),
      "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    ),

    features = features
  )
}


# -------------------------------------------------------------------
# CLI
# -------------------------------------------------------------------

args <- commandArgs(
  trailingOnly = TRUE
)

if (length(args) != 2) {

  cat(
    paste0(
      "\nUsage:\n",
      "  Rscript osm_toponym.R input.csv output.geojson\n\n",
      "Input CSV columns:\n",
      "  id,latitude,longitude\n\n"
    )
  )

  quit(
    status = 1
  )
}

input_file <- args[[1]]
output_file <- args[[2]]

dat <- read.csv(
  input_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

geojson <- resolve_toponyms(dat)

write_json(
  geojson,
  path = output_file,
  pretty = TRUE,
  auto_unbox = TRUE,
  na = "null",
  digits = NA
)

message(
  sprintf(
    "Wrote %d toponym records to %s",
    length(geojson$features),
    output_file
  )
)
