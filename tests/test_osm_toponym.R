#!/usr/bin/env Rscript
# Offline regression checks: all HTTP requests are intercepted by httr2.

run_tests <- function() {
  script <- normalizePath("src/osm_toponym.R", mustWork = TRUE)
  work <- tempfile("osm-toponym-tests-")
  dir.create(work)
  original_wd <- getwd()
  on.exit({ setwd(original_wd); unlink(work, recursive = TRUE) }, add = TRUE)
  setwd(work)

  scope <- new.env(parent = globalenv())
  sys.source(script, envir = scope)
  scope$USER_AGENT <- "data-protocols/offline-regression-test"
  scope$NOMINATIM_DELAY <- 0

  old_options <- options(
    httr2_mock = function(req) stop("Unexpected mock request"),
    httr2_progress = FALSE
  )
  on.exit(options(old_options), add = TRUE)

  reply <- function(status = 200L, body = list(), type = "application/json") {
    payload <- if (is.character(body)) body else
      jsonlite::toJSON(body, auto_unbox = TRUE)
    httr2::response(
      status, headers = list("content-type" = type, "retry-after" = "0"),
      body = charToRaw(payload)
    )
  }

  reverse <- list(
    name = "Test village", osm_type = "node", osm_id = 123,
    lat = "13.5", lon = "-16.2", category = "place", type = "village",
    address = list(country_code = "sn")
  )
  input <- data.frame(id = c("SITE_01", "SITE_02"),
                      latitude = c(13.5, 13.6), longitude = c(-16.2, -16.3))
  write.csv(input, "input.csv", row.names = FALSE)
  writeLines("previous output", "output.geojson")

  # Access denial is not retried or repeated for every input row, and does
  # not replace a previous output with apparently successful failure records.
  for (status in c(401L, 403L)) {
    calls <- 0L
    options(httr2_mock = function(req) {
      calls <<- calls + 1L
      reply(status, "<html>Access denied by service</html>", "text/html")
    })
    err <- tryCatch(scope$main(c("input.csv", "output.geojson")), error = identity)
    stopifnot(inherits(err, "osm_service_denied"), calls == 1L,
              grepl("Site SITE_01: Nominatim:", conditionMessage(err), fixed = TRUE),
              grepl("Access denied by service", conditionMessage(err), fixed = TRUE),
              !grepl("\033", conditionMessage(err), fixed = TRUE),
              identical(readLines("output.geojson"), "previous output"),
              length(list.files(scope$NOMINATIM_CACHE_DIR)) == 0L)
  }

  # Overpass denials identify the correct service, preserve the successfully
  # cached reverse response, and stop before submitting the next site's query.
  calls <- 0L
  options(httr2_mock = function(req) {
    calls <<- calls + 1L
    if (grepl("nominatim", req$url, fixed = TRUE)) {
      result <- reverse
      result$osm_type <- "relation"
      result$category <- "boundary"
      reply(body = result)
    } else reply(403L, "Forbidden", "text/plain")
  })
  err <- tryCatch(scope$main(c("input.csv", "output.geojson")), error = identity)
  stopifnot(inherits(err, "osm_service_denied"), calls == 2L,
            grepl("Overpass:", conditionMessage(err), fixed = TRUE),
            length(list.files(scope$NOMINATIM_CACHE_DIR)) == 1L,
            length(list.files(scope$OVERPASS_CACHE_DIR)) == 0L,
            identical(readLines("output.geojson"), "previous output"))
  unlink(list.files(scope$NOMINATIM_CACHE_DIR, full.names = TRUE))

  # The retry policy covers gateway timeouts while keeping denials permanent.
  req <- scope$api_request("https://example.test")
  stopifnot(req$policies$retry_is_transient(reply(504L)),
            req$policies$retry_is_transient(reply(429L)),
            !req$policies$retry_is_transient(reply(403L)),
            req$policies$retry_max_tries == 4L)

  # Successful responses are reused from disk and retain the output schema.
  calls <- 0L
  options(httr2_mock = function(req) {
    calls <<- calls + 1L
    reply(body = reverse)
  })
  stopifnot(scope$main(c("input.csv", "output.geojson")) == 0L, calls == 2L)
  stopifnot(scope$main(c("input.csv", "output.geojson")) == 0L, calls == 2L)
  output <- jsonlite::read_json("output.geojson", simplifyVector = FALSE)
  stopifnot(output$generator_version == "1.1.1", length(output$features) == 2L,
            all(vapply(output$features, function(f) f$properties$status == "node_exact",
                       logical(1))))

  # Nonfatal per-site errors still produce diagnostics, but the CLI reports
  # an incomplete run with status 2 and no terminal escapes in stored JSON.
  scope$resolve_osm_toponym <- function(lat, lon) {
    stop("\033[1mHTTP request failed\033[0m", call. = FALSE)
  }
  code <- suppressWarnings(scope$main(c("input.csv", "failed.geojson")))
  failed <- jsonlite::read_json("failed.geojson", simplifyVector = FALSE)
  stopifnot(code == 2L, length(failed$features) == 2L,
            failed$features[[1]]$properties$message == "HTTP request failed",
            all(vapply(failed$features, function(f) f$properties$status == "unresolved",
                       logical(1))))

  scope$USER_AGENT <- "research; contact: your.email@example.org"
  err <- tryCatch(scope$main(c("input.csv", "failed.geojson")), error = identity)
  stopifnot(inherits(err, "error"), grepl("placeholder", conditionMessage(err)))
  cat("All offline regression checks passed.\n")
}

run_tests()
