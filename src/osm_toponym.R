#!/usr/bin/env Rscript

# =====================================================================
# osm_toponym.R
# =====================================================================
#
# Resolve latitude/longitude coordinates to canonical OpenStreetMap
# toponym references.
#
# Strategy
# --------
#
# 1. Reverse-geocode the supplied coordinate with Nominatim at
#    settlement level (zoom = 15).
#
# 2. Use the returned settlement name/address context to identify the
#    intended named locality.
#
# 3. Search nearby OSM `place=*` NODES with Overpass.
#
# 4. Prefer an unambiguous matching `place=*` node over a boundary
#    relation or way returned by Nominatim.
#
# 5. Preserve the original Nominatim result as provenance.
#
# 6. If no matching place node can be established safely, retain the
#    Nominatim result rather than guessing.
#
# 7. If several plausible matching nodes exist, mark the record as
#    ambiguous and retain the Nominatim object as the canonical anchor.
#
#
# Input CSV
# ---------
#
# Required columns:
#
#   id,latitude,longitude
#
# Example:
#
#   id,latitude,longitude
#   CAS001,12.487631,-16.273819
#   CAS002,12.512447,-16.221734
#
#
# Output
# ------
#
# GeoJSON FeatureCollection.
#
#
# Usage
# -----
#
#   Rscript osm_toponym.R sites.csv toponyms.geojson
#
#
# Dependencies
# ------------
#
#   install.packages(c("httr2", "jsonlite"))
#
#
# IMPORTANT
# ---------
#
# The public Nominatim service:
#
#   * allows at most 1 request per second;
#   * requires a meaningful User-Agent;
#   * requires results to be cached for bulk work;
#   * should not be used for heavy recurring workloads.
#
# Optionally set OSM_CONTACT_EMAIL to a real project/contact email address.
# OSM_USER_AGENT can override the identifying application User-Agent.
#
# For substantial or recurring workflows, use your own Nominatim/
# Overpass infrastructure or another policy-compliant service.
#
# =====================================================================


suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
})


# =====================================================================
# 1. CONFIGURATION
# =====================================================================

NOMINATIM_URL <- "https://nominatim.openstreetmap.org/reverse"

OVERPASS_URL <- "https://overpass-api.de/api/interpreter"


# ---------------------------------------------------------------------
# Identify the application without sending a fictitious contact address.
# ---------------------------------------------------------------------

CONTACT_EMAIL <- trimws(Sys.getenv("OSM_CONTACT_EMAIL", ""))


USER_AGENT <- Sys.getenv(
  "OSM_USER_AGENT",
  paste0(
    "data-protocols/osm_toponym/1.1.1 (research locality lookup",
    if (nzchar(CONTACT_EMAIL)) paste0("; contact: ", CONTACT_EMAIL) else "",
    ")"
  )
)


# ---------------------------------------------------------------------
# Nominatim settlement-level reverse geocoding
#
# Nominatim approximate address detail:
#
#   zoom 13 = village / suburb
#   zoom 14 = neighbourhood
#   zoom 15 = any settlement
#
# ---------------------------------------------------------------------

NOMINATIM_ZOOM <- 15L


# ---------------------------------------------------------------------
# Respect public Nominatim maximum rate.
# ---------------------------------------------------------------------

NOMINATIM_DELAY <- 1.10


# ---------------------------------------------------------------------
# Radius around the supplied scientific coordinate within which
# place=* nodes are sought.
#
# 5 km is deliberately generous enough for rural field localities
# without making searches regional in scale.
# ---------------------------------------------------------------------

PLACE_NODE_RADIUS_M <- 5000


# ---------------------------------------------------------------------
# Place types accepted as potential toponym anchors.
#
# locality is included because it can occasionally be scientifically
# relevant, although inhabited settlement classes are normally more
# useful.
# ---------------------------------------------------------------------

PLACE_TYPES <- c(
  "city",
  "town",
  "village",
  "hamlet",
  "isolated_dwelling",
  "locality"
)


# ---------------------------------------------------------------------
# Local cache.
#
# This avoids repeatedly sending identical requests to public services.
# ---------------------------------------------------------------------

CACHE_DIR <- ".osm_toponym_cache"

NOMINATIM_CACHE_DIR <- file.path(
  CACHE_DIR,
  "nominatim"
)

OVERPASS_CACHE_DIR <- file.path(
  CACHE_DIR,
  "overpass"
)


dir.create(
  NOMINATIM_CACHE_DIR,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  OVERPASS_CACHE_DIR,
  recursive = TRUE,
  showWarnings = FALSE
)


# =====================================================================
# 2. GENERAL HELPERS
# =====================================================================


stop_bad_coordinates <- function(
    lat,
    lon,
    id = NA_character_
) {

  if (
    is.na(lat) ||
      is.na(lon) ||
      !is.finite(lat) ||
      !is.finite(lon) ||
      lat < -90 ||
      lat > 90 ||
      lon < -180 ||
      lon > 180
  ) {

    stop(
      sprintf(
        paste0(
          "Invalid coordinates for '%s': ",
          "latitude=%s longitude=%s"
        ),
        id,
        lat,
        lon
      ),
      call. = FALSE
    )
  }
}


first_nonempty <- function(...) {

  values <- list(...)

  for (x in values) {

    if (
      !is.null(x) &&
        length(x) > 0 &&
        !is.na(x[[1]]) &&
        nzchar(trimws(as.character(x[[1]])))
    ) {

      return(
        as.character(x[[1]])
      )
    }
  }

  NA_character_
}


safe_scalar <- function(x) {

  if (
    is.null(x) ||
      length(x) == 0 ||
      is.na(x[[1]])
  ) {

    return(NA_character_)
  }

  as.character(x[[1]])
}


# =====================================================================
# 3. NAME NORMALISATION
# =====================================================================
#
# This is used only for MATCHING.
#
# The original OSM spelling is always preserved in output.
#
# We remove:
#
#   * case differences
#   * accents/diacritics where transliteration is possible
#   * punctuation
#   * repeated whitespace
#
# Thus:
#
#   "Médina-Djikoye"
#
# may match
#
#   "Medina Djikoye"
#
# without changing the canonical OSM spelling.
#
# =====================================================================


normalise_name <- function(x) {

  if (
    is.null(x) ||
      length(x) == 0 ||
      is.na(x[[1]]) ||
      !nzchar(trimws(as.character(x[[1]])))
  ) {

    return(NA_character_)
  }

  x <- as.character(x[[1]])

  transliterated <- iconv(
    x,
    from = "",
    to = "ASCII//TRANSLIT"
  )

  if (!is.na(transliterated)) {
    x <- transliterated
  }

  x <- tolower(x)

  x <- gsub(
    "[^[:alnum:]]+",
    " ",
    x
  )

  x <- gsub(
    "\\s+",
    " ",
    x
  )

  trimws(x)
}


# =====================================================================
# 4. DISTANCE
# =====================================================================


haversine_m <- function(
    lat1,
    lon1,
    lat2,
    lon2
) {

  radius_earth <- 6371000

  phi1 <- lat1 * pi / 180
  phi2 <- lat2 * pi / 180

  delta_phi <- (
    lat2 - lat1
  ) * pi / 180

  delta_lambda <- (
    lon2 - lon1
  ) * pi / 180

  a <- sin(delta_phi / 2)^2 +
    cos(phi1) *
    cos(phi2) *
    sin(delta_lambda / 2)^2

  c <- 2 * atan2(
    sqrt(a),
    sqrt(1 - a)
  )

  radius_earth * c
}


# =====================================================================
# 5. CACHE HELPERS
# =====================================================================


cache_key_coordinates <- function(
    lat,
    lon,
    suffix = ""
) {

  sprintf(
    "%.7f_%.7f%s",
    lat,
    lon,
    suffix
  ) |>
    gsub(
      "[^A-Za-z0-9_.-]",
      "_",
      x = _
    )
}


read_cached_json <- function(path) {

  if (!file.exists(path)) {
    return(NULL)
  }

  tryCatch(
    fromJSON(
      path,
      simplifyVector = FALSE
    ),
    error = function(e) NULL
  )
}


write_cached_json <- function(
    object,
    path
) {

  write_json(
    object,
    path = path,
    pretty = FALSE,
    auto_unbox = TRUE,
    na = "null",
    digits = NA
  )
}


# =====================================================================
# 6. OPENSTREETMAP URL
# =====================================================================


osm_url <- function(
    osm_type,
    osm_id
) {

  if (
    is.null(osm_type) ||
      is.null(osm_id) ||
      is.na(osm_type) ||
      is.na(osm_id)
  ) {

    return(NA_character_)
  }

  sprintf(
    "https://www.openstreetmap.org/%s/%s",
    osm_type,
    osm_id
  )
}


# =====================================================================
# 7. NOMINATIM REVERSE GEOCODING
# =====================================================================


plain_diagnostic <- function(x) {
  # httr2/cli conditions may contain terminal styling even in saved JSON.
  x <- gsub("\033\\[[0-?]*[ -/]*[@-~]", "", x, perl = TRUE)
  trimws(gsub("[[:space:][:cntrl:]]+", " ", x))
}


validate_user_agent <- function() {
  if (!nzchar(trimws(USER_AGENT)) ||
      grepl("your.email@example.org", USER_AGENT, fixed = TRUE)) {
    stop("Set OSM_USER_AGENT to identify your application, or unset it to use the project default; do not use a placeholder contact.",
         call. = FALSE)
  }

  invisible(TRUE)
}


api_request <- function(url) {
  validate_user_agent()
  request(url) |>
    req_user_agent(USER_AGENT) |>
    req_timeout(30) |>
    req_retry(
      max_tries = 4,
      max_seconds = 120,
      retry_on_failure = TRUE,
      is_transient = function(resp) {
        resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
      },
      backoff = ~ 2^.x
    )
}


perform_api_request <- function(req, service) {
  tryCatch(
    req_perform(req),
    error = function(e) {
      status <- if (inherits(e, "httr2_http")) e$status else NULL
      detail <- ""
      if (!is.null(e$resp)) {
        body <- tryCatch(resp_body_string(e$resp), error = function(e) "")
        # Keep a bounded, plain-text server explanation, not response headers.
        body <- plain_diagnostic(gsub("<[^>]*>", " ", body))
        if (nzchar(body)) detail <- paste0(" Server response: ", substr(body, 1, 500))
      }

      message <- paste0(service, ": ", plain_diagnostic(conditionMessage(e)), detail)
      denied <- !is.null(status) && status %in% c(401L, 403L, 429L)
      if (denied) {
        message <- paste0(
          message,
          " Batch stopped to avoid further requests to a denied or rate-limited service.",
          " Check service access, application identification, and usage policy before rerunning.",
          " Existing output is unchanged; successful API responses remain cached."
        )
      }

      error <- simpleError(message, call = NULL)
      if (denied) class(error) <- c("osm_service_denied", class(error))
      stop(error)
    }
  )
}


reverse_osm <- function(
    lat,
    lon
) {

  cache_key <- cache_key_coordinates(
    lat,
    lon,
    suffix = sprintf(
      "_zoom%d",
      NOMINATIM_ZOOM
    )
  )

  cache_file <- file.path(
    NOMINATIM_CACHE_DIR,
    paste0(
      cache_key,
      ".json"
    )
  )


  # -------------------------------------------------------------------
  # Reuse locally cached result
  # -------------------------------------------------------------------

  cached <- read_cached_json(
    cache_file
  )

  if (!is.null(cached)) {

    return(cached)
  }


  # -------------------------------------------------------------------
  # Public Nominatim request
  # -------------------------------------------------------------------

  req <- api_request(
    NOMINATIM_URL
  ) |>
    req_url_query(
      format = "jsonv2",
      lat = lat,
      lon = lon,
      zoom = NOMINATIM_ZOOM,
      layer = "address",
      addressdetails = 1,
      namedetails = 1
    )


  # Respect Nominatim public service rate.
  Sys.sleep(
    NOMINATIM_DELAY
  )


  resp <- perform_api_request(
    req, "Nominatim"
  )


  result <- resp_body_json(
    resp,
    simplifyVector = FALSE
  )


  write_cached_json(
    result,
    cache_file
  )


  result
}


# =====================================================================
# 8. EXTRACT SETTLEMENT NAMES FROM NOMINATIM
# =====================================================================


extract_name <- function(x) {

  # Prefer explicit name attached to returned object.

  if (
    !is.null(x$name) &&
      length(x$name) > 0 &&
      !is.na(x$name[[1]]) &&
      nzchar(as.character(x$name[[1]]))
  ) {

    return(
      as.character(x$name[[1]])
    )
  }


  # Fall back through settlement-level address components.

  address <- x$address

  if (is.null(address)) {
    return(NA_character_)
  }


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


candidate_settlement_names <- function(
    reverse_result
) {

  candidates <- character()


  # -------------------------------------------------------------------
  # Main returned object name
  # -------------------------------------------------------------------

  if (
    !is.null(reverse_result$name) &&
      length(reverse_result$name) > 0
  ) {

    candidates <- c(
      candidates,
      as.character(
        reverse_result$name
      )
    )
  }


  # -------------------------------------------------------------------
  # Settlement names from address hierarchy
  # -------------------------------------------------------------------

  a <- reverse_result$address

  if (!is.null(a)) {

    address_fields <- c(
      "hamlet",
      "village",
      "town",
      "city",
      "municipality",
      "suburb",
      "neighbourhood"
    )

    for (field in address_fields) {

      value <- a[[field]]

      if (
        !is.null(value) &&
          length(value) > 0
      ) {

        candidates <- c(
          candidates,
          as.character(value)
        )
      }
    }
  }


  # -------------------------------------------------------------------
  # Include Nominatim name variants, if available.
  # -------------------------------------------------------------------

  nd <- reverse_result$namedetails

  if (!is.null(nd)) {

    for (value in unlist(
      nd,
      use.names = FALSE
    )) {

      if (
        !is.na(value) &&
          nzchar(as.character(value))
      ) {

        candidates <- c(
          candidates,
          as.character(value)
        )
      }
    }
  }


  candidates <- candidates[
    !is.na(candidates)
  ]

  candidates <- candidates[
    nzchar(
      trimws(candidates)
    )
  ]


  unique(candidates)
}


# =====================================================================
# 9. OVERPASS SEARCH FOR place=* NODES
# =====================================================================


query_place_nodes <- function(
    lat,
    lon,
    radius = PLACE_NODE_RADIUS_M
) {

  cache_key <- cache_key_coordinates(
    lat,
    lon,
    suffix = sprintf(
      "_r%d",
      radius
    )
  )

  cache_file <- file.path(
    OVERPASS_CACHE_DIR,
    paste0(
      cache_key,
      ".json"
    )
  )


  # -------------------------------------------------------------------
  # Reuse cached search
  # -------------------------------------------------------------------

  cached <- read_cached_json(
    cache_file
  )

  if (!is.null(cached)) {

    if (is.null(cached$elements)) {
      return(list())
    }

    return(
      cached$elements
    )
  }


  # -------------------------------------------------------------------
  # Build Overpass query
  # -------------------------------------------------------------------

  place_regex <- paste(
    PLACE_TYPES,
    collapse = "|"
  )


  query <- sprintf(
    paste0(
      "[out:json][timeout:25];",
      "(",
      "node(around:%d,%.7f,%.7f)",
      "[\"place\"~\"^(%s)$\"]",
      "[\"name\"];",
      ");",
      "out body;"
    ),
    radius,
    lat,
    lon,
    place_regex
  )


  req <- api_request(
    OVERPASS_URL
  ) |>
    req_body_form(
      data = query
    )


  resp <- perform_api_request(
    req, "Overpass"
  )


  result <- resp_body_json(
    resp,
    simplifyVector = FALSE
  )


  write_cached_json(
    result,
    cache_file
  )


  if (is.null(result$elements)) {
    return(list())
  }


  result$elements
}


# =====================================================================
# 10. EXTRACT ALL RELEVANT NAMES FROM AN OSM NODE
# =====================================================================
#
# A place node may contain:
#
#   name
#   alt_name
#   loc_name
#   official_name
#   old_name
#   name:fr
#   name:wo
#   name:ff
#   ...
#
# All are useful for matching.
#
# The canonical output remains tags$name.
#
# =====================================================================


node_names <- function(node) {

  tags <- node$tags

  if (is.null(tags)) {
    return(character())
  }


  tag_names <- names(tags)

  if (is.null(tag_names)) {
    return(character())
  }


  relevant <- (
    tag_names %in% c(
      "name",
      "alt_name",
      "loc_name",
      "official_name",
      "short_name",
      "old_name"
    )
  ) |
    grepl(
      "^name:",
      tag_names
    )


  values <- unlist(
    tags[relevant],
    use.names = FALSE
  )


  # alt_name etc. may contain semicolon-separated forms.

  values <- unlist(
    strsplit(
      as.character(values),
      ";",
      fixed = TRUE
    ),
    use.names = FALSE
  )


  values <- trimws(values)

  values <- values[
    !is.na(values) &
      nzchar(values)
  ]


  unique(values)
}


# =====================================================================
# 11. ASSESS PLACE-NODE CANDIDATES
# =====================================================================


assess_place_nodes <- function(
    nodes,
    reverse_result,
    query_lat,
    query_lon
) {

  if (length(nodes) == 0) {

    return(
      list(
        status = "none",
        selected = NULL,
        candidates = list()
      )
    )
  }


  target_names <- candidate_settlement_names(
    reverse_result
  )


  target_names_normalised <- unique(
    vapply(
      target_names,
      normalise_name,
      character(1)
    )
  )


  target_names_normalised <- target_names_normalised[
    !is.na(
      target_names_normalised
    )
  ]


  candidates <- list()


  for (node in nodes) {

    if (
      is.null(node$tags) ||
        is.null(node$tags$name) ||
        is.null(node$tags$place)
    ) {

      next
    }


    names_raw <- node_names(
      node
    )


    names_normalised <- unique(
      vapply(
        names_raw,
        normalise_name,
        character(1)
      )
    )


    names_normalised <- names_normalised[
      !is.na(
        names_normalised
      )
    ]


    matches <- intersect(
      names_normalised,
      target_names_normalised
    )


    name_match <- (
      length(matches) > 0
    )


    distance <- haversine_m(
      query_lat,
      query_lon,
      as.numeric(node$lat),
      as.numeric(node$lon)
    )


    candidates[[
      length(candidates) + 1L
    ]] <- list(

      osm_type = "node",

      osm_id = node$id,

      name = as.character(
        node$tags$name
      ),

      place = as.character(
        node$tags$place
      ),

      lat = as.numeric(
        node$lat
      ),

      lon = as.numeric(
        node$lon
      ),

      distance_m = distance,

      name_match = name_match,

      matched_names = matches,

      names = names_raw
    )
  }


  if (length(candidates) == 0) {

    return(
      list(
        status = "none",
        selected = NULL,
        candidates = list()
      )
    )
  }


  # -------------------------------------------------------------------
  # Restrict selection to name-compatible nodes.
  # -------------------------------------------------------------------

  matched <- Filter(
    function(x) {
      isTRUE(x$name_match)
    },
    candidates
  )


  if (length(matched) == 0) {

    return(
      list(
        status = "none",
        selected = NULL,
        candidates = candidates
      )
    )
  }


  # -------------------------------------------------------------------
  # Sort matching candidates by distance.
  # -------------------------------------------------------------------

  distances <- vapply(
    matched,
    function(x) x$distance_m,
    numeric(1)
  )


  matched <- matched[
    order(distances)
  ]


  # -------------------------------------------------------------------
  # Exactly one matching place node:
  #
  # safe automatic selection.
  # -------------------------------------------------------------------

  if (length(matched) == 1) {

    return(
      list(
        status = "node_exact",
        selected = matched[[1]],
        candidates = matched
      )
    )
  }


  # -------------------------------------------------------------------
  # Several matching nodes:
  #
  # Do NOT guess.
  #
  # Homonymy is common, especially in West Africa. The fact that one
  # matching node is slightly closer than another is insufficient
  # evidence that it is the intended place.
  # -------------------------------------------------------------------

  list(
    status = "ambiguous",
    selected = NULL,
    candidates = matched
  )
}


# =====================================================================
# 12. CHECK WHETHER NOMINATIM ALREADY RETURNED A place=* NODE
# =====================================================================


reverse_is_place_node <- function(
    reverse_result
) {

  identical(
    safe_scalar(
      reverse_result$osm_type
    ),
    "node"
  ) &&
    identical(
      safe_scalar(
        reverse_result$category
      ),
      "place"
    )
}


# =====================================================================
# 13. RESOLVE CANONICAL OSM TOPONYM
# =====================================================================


resolve_osm_toponym <- function(
    lat,
    lon
) {

  # -------------------------------------------------------------------
  # Stage 1: settlement-context reverse geocoding
  # -------------------------------------------------------------------

  reverse_result <- reverse_osm(
    lat,
    lon
  )


  # -------------------------------------------------------------------
  # If Nominatim itself returned an OSM place node, this is already
  # exactly the preferred type of reference.
  # -------------------------------------------------------------------

  if (
    reverse_is_place_node(
      reverse_result
    )
  ) {

    return(
      list(

        name = extract_name(
          reverse_result
        ),

        osm_type = safe_scalar(
          reverse_result$osm_type
        ),

        osm_id = safe_scalar(
          reverse_result$osm_id
        ),

        osm_lat = suppressWarnings(
          as.numeric(
            safe_scalar(
              reverse_result$lat
            )
          )
        ),

        osm_lon = suppressWarnings(
          as.numeric(
            safe_scalar(
              reverse_result$lon
            )
          )
        ),

        osm_category = safe_scalar(
          reverse_result$category
        ),

        osm_place_type = safe_scalar(
          reverse_result$type
        ),

        status = "node_exact",

        resolution_method =
          "nominatim_place_node",

        node_distance_m = haversine_m(
          lat,
          lon,
          as.numeric(
            safe_scalar(
              reverse_result$lat
            )
          ),
          as.numeric(
            safe_scalar(
              reverse_result$lon
            )
          )
        ),

        reverse = reverse_result,

        candidates = list()
      )
    )
  }


  # -------------------------------------------------------------------
  # Stage 2: look explicitly for place=* nodes nearby.
  # -------------------------------------------------------------------

  nodes <- query_place_nodes(
    lat,
    lon
  )


  assessment <- assess_place_nodes(
    nodes,
    reverse_result,
    lat,
    lon
  )


  # -------------------------------------------------------------------
  # Unique matching place node.
  # -------------------------------------------------------------------

  if (
    identical(
      assessment$status,
      "node_exact"
    )
  ) {

    selected <- assessment$selected


    return(
      list(

        name = selected$name,

        osm_type = "node",

        osm_id = as.character(
          selected$osm_id
        ),

        osm_lat = selected$lat,

        osm_lon = selected$lon,

        osm_category = "place",

        osm_place_type = selected$place,

        status = "node_exact",

        resolution_method =
          "nominatim_reverse_then_place_node",

        node_distance_m =
          selected$distance_m,

        reverse = reverse_result,

        candidates =
          assessment$candidates
      )
    )
  }


  # -------------------------------------------------------------------
  # Ambiguous place nodes.
  #
  # Preserve the Nominatim result rather than inventing certainty.
  # -------------------------------------------------------------------

  if (
    identical(
      assessment$status,
      "ambiguous"
    )
  ) {

    return(
      list(

        name = extract_name(
          reverse_result
        ),

        osm_type = safe_scalar(
          reverse_result$osm_type
        ),

        osm_id = safe_scalar(
          reverse_result$osm_id
        ),

        osm_lat = suppressWarnings(
          as.numeric(
            safe_scalar(
              reverse_result$lat
            )
          )
        ),

        osm_lon = suppressWarnings(
          as.numeric(
            safe_scalar(
              reverse_result$lon
            )
          )
        ),

        osm_category = safe_scalar(
          reverse_result$category
        ),

        osm_place_type = safe_scalar(
          reverse_result$type
        ),

        status = "ambiguous",

        resolution_method =
          "nominatim_reverse_ambiguous_place_nodes",

        node_distance_m =
          NA_real_,

        reverse = reverse_result,

        candidates =
          assessment$candidates
      )
    )
  }


  # -------------------------------------------------------------------
  # No suitable matching place node.
  #
  # Use original Nominatim result as defensible fallback.
  # -------------------------------------------------------------------

  list(

    name = extract_name(
      reverse_result
    ),

    osm_type = safe_scalar(
      reverse_result$osm_type
    ),

    osm_id = safe_scalar(
      reverse_result$osm_id
    ),

    osm_lat = suppressWarnings(
      as.numeric(
        safe_scalar(
          reverse_result$lat
        )
      )
    ),

    osm_lon = suppressWarnings(
      as.numeric(
        safe_scalar(
          reverse_result$lon
        )
      )
    ),

    osm_category = safe_scalar(
      reverse_result$category
    ),

    osm_place_type = safe_scalar(
      reverse_result$type
    ),

    status = "osm_fallback",

    resolution_method =
      "nominatim_reverse_fallback",

    node_distance_m =
      NA_real_,

    reverse = reverse_result,

    candidates =
      assessment$candidates
  )
}


# =====================================================================
# 14. CONVERT RESULT TO GEOJSON FEATURE
# =====================================================================


make_feature <- function(
    source_id,
    query_lat,
    query_lon,
    resolved
) {

  reverse_result <- resolved$reverse


  country_code <- NA_character_

  if (
    !is.null(reverse_result$address) &&
      !is.null(
        reverse_result$address$country_code
      )
  ) {

    country_code <- safe_scalar(
      reverse_result$address$country_code
    )
  }


  # -------------------------------------------------------------------
  # Candidate summary for ambiguous records.
  #
  # GeoJSON permits arrays/objects inside properties.
  # -------------------------------------------------------------------

  candidate_summary <- list()

  if (
    length(resolved$candidates) > 0
  ) {

    candidate_summary <- lapply(
      resolved$candidates,
      function(x) {

        list(
          osm_type = "node",
          osm_id = as.character(
            x$osm_id
          ),
          name = x$name,
          place = x$place,
          latitude = x$lat,
          longitude = x$lon,
          distance_m = round(
            x$distance_m,
            1
          ),
          osm_url = osm_url(
            "node",
            x$osm_id
          )
        )
      }
    )
  }


  # -------------------------------------------------------------------
  # Geometry represents the canonical OSM anchor.
  #
  # The original scientific sampling/query coordinate is stored
  # separately below.
  # -------------------------------------------------------------------

  geometry_lat <- resolved$osm_lat
  geometry_lon <- resolved$osm_lon


  if (
    !is.finite(geometry_lat) ||
      !is.finite(geometry_lon)
  ) {

    geometry_lat <- query_lat
    geometry_lon <- query_lon
  }


  list(

    type = "Feature",

    geometry = list(

      type = "Point",

      coordinates = list(
        geometry_lon,
        geometry_lat
      )
    ),

    properties = list(

      source_id = source_id,

      name = resolved$name,

      reference_system =
        "OpenStreetMap",

      osm_type =
        resolved$osm_type,

      osm_id =
        resolved$osm_id,

      osm_url = osm_url(
        resolved$osm_type,
        resolved$osm_id
      ),

      verified = format(
        Sys.Date(),
        "%Y-%m-%d"
      ),

      status =
        resolved$status,

      resolution_method =
        resolved$resolution_method,

      country_code =
        country_code,

      osm_category =
        resolved$osm_category,

      osm_place_type =
        resolved$osm_place_type,

      osm_latitude =
        geometry_lat,

      osm_longitude =
        geometry_lon,

      query_latitude =
        query_lat,

      query_longitude =
        query_lon,

      distance_to_osm_anchor_m =
        if (
          is.na(
            resolved$node_distance_m
          )
        ) {
          NULL
        } else {
          round(
            resolved$node_distance_m,
            1
          )
        },

      display_name =
        safe_scalar(
          reverse_result$display_name
        ),

      reverse_osm_type =
        safe_scalar(
          reverse_result$osm_type
        ),

      reverse_osm_id =
        safe_scalar(
          reverse_result$osm_id
        ),

      reverse_osm_url = osm_url(
        safe_scalar(
          reverse_result$osm_type
        ),
        safe_scalar(
          reverse_result$osm_id
        )
      ),

      candidate_place_nodes =
        candidate_summary
    )
  )
}


# =====================================================================
# 15. UNRESOLVED FEATURE
# =====================================================================


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

      source_id =
        source_id,

      name =
        NA_character_,

      reference_system =
        "OpenStreetMap",

      osm_type =
        NA_character_,

      osm_id =
        NA_character_,

      osm_url =
        NA_character_,

      verified = format(
        Sys.Date(),
        "%Y-%m-%d"
      ),

      status =
        "unresolved",

      resolution_method =
        "failed",

      message =
        message,

      query_latitude =
        query_lat,

      query_longitude =
        query_lon
    )
  )
}


# =====================================================================
# 16. BATCH PROCESSING
# =====================================================================


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
        paste(
          missing,
          collapse = ", "
        )
      ),
      call. = FALSE
    )
  }


  features <- vector(
    "list",
    nrow(data)
  )


  for (
    i in seq_len(
      nrow(data)
    )
  ) {

    source_id <- as.character(
      data$id[[i]]
    )

    lat <- suppressWarnings(
      as.numeric(
        data$latitude[[i]]
      )
    )

    lon <- suppressWarnings(
      as.numeric(
        data$longitude[[i]]
      )
    )


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

      resolve_osm_toponym(
        lat,
        lon
      ),

      error = function(e) e
    )


    if (inherits(result, "osm_service_denied")) {
      result$message <- paste0("Site ", source_id, ": ", result$message)
      stop(result)
    }

    if (
      inherits(
        result,
        "error"
      )
    ) {

      warning(
        sprintf(
          "Could not resolve %s: %s",
          source_id,
          plain_diagnostic(conditionMessage(result))
        ),
        call. = FALSE
      )


      features[[i]] <-
        make_unresolved_feature(
          source_id,
          lat,
          lon,
          plain_diagnostic(conditionMessage(result))
        )


    } else {


      message(
        sprintf(
          "    -> %s | %s/%s | %s",
          ifelse(
            is.na(result$name),
            "<unnamed>",
            result$name
          ),
          result$osm_type,
          result$osm_id,
          result$status
        )
      )


      if (
        identical(
          result$status,
          "ambiguous"
        )
      ) {

        warning(
          sprintf(
            paste0(
              "%s: several matching place nodes found; ",
              "retaining Nominatim object and marking ambiguous"
            ),
            source_id
          ),
          call. = FALSE
        )
      }


      features[[i]] <- make_feature(
        source_id,
        lat,
        lon,
        result
      )
    }
  }


  list(

    type =
      "FeatureCollection",

    attribution =
      "© OpenStreetMap contributors, ODbL 1.0",

    generator =
      "osm_toponym.R",

    generator_version =
      "1.1.1",

    generated = format(
      Sys.time(),
      "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    ),

    features =
      features
  )
}


# =====================================================================
# 17. COMMAND-LINE INTERFACE
# =====================================================================


main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (
    length(args) != 2
  ) {

    cat(
      paste0(
        "\n",
        "Usage:\n",
        "\n",
        "  Rscript osm_toponym.R input.csv output.geojson\n",
        "\n",
        "Required input CSV columns:\n",
        "\n",
        "  id,latitude,longitude\n",
        "\n",
        "Example:\n",
        "\n",
        "  id,latitude,longitude\n",
        "  CAS001,12.487631,-16.273819\n",
        "  CAS002,12.512447,-16.221734\n",
        "\n"
      )
    )


    return(1L)
  }


  input_file <- args[[1]]

  output_file <- args[[2]]


  if (
    !file.exists(
      input_file
    )
  ) {

    stop(
      sprintf(
        "Input file does not exist: %s",
        input_file
      ),
      call. = FALSE
    )
  }


  validate_user_agent()


  dat <- read.csv(
    input_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


  geojson <- resolve_toponyms(
    dat
  )


  write_json(
    geojson,
    path = output_file,
    pretty = TRUE,
    auto_unbox = TRUE,
    na = "null",
    digits = NA
  )


  # =====================================================================
  # 18. SUMMARY
  # =====================================================================


  statuses <- vapply(
    geojson$features,
    function(x) {
      x$properties$status
    },
    character(1)
  )


  message("")
  message(
    sprintf(
      "Wrote %d toponym records to %s",
      length(
        geojson$features
      ),
      output_file
    )
  )


  message("")
  message("Resolution summary:")


  summary_table <- sort(
    table(statuses),
    decreasing = TRUE
  )


  for (
    status_name in names(
      summary_table
    )
  ) {

    message(
      sprintf(
        "  %-15s %d",
        status_name,
        summary_table[[
          status_name
        ]]
      )
    )
  }


  message("")
  message(
    sprintf(
      "API cache: %s",
      normalizePath(
        CACHE_DIR,
        mustWork = FALSE
      )
    )
  )

  message("")

  # A written file may still contain failed records. Signal that to CLI callers.
  if (any(statuses == "unresolved")) 2L else 0L
}


if (sys.nframe() == 0L) {
  quit(status = main())
}
