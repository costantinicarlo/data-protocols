#!/usr/bin/env Rscript
# Each suite runs in a fresh process. The profile blocks unexpected HTTP before
# any tested source is loaded; tests explicitly replace it with local mocks.
run_all <- function() {
  for (p in c('jsonlite','xml2','digest','httr2')) if (!requireNamespace(p, quietly=TRUE)) stop('Missing mandatory test dependency: ',p)
  profile <- tempfile('offline-profile-')
  writeLines('options(httr2_mock = function(req) stop("Unexpected unmocked HTTP request in offline suite"))',profile)
  on.exit(unlink(profile))
  for (test in c('test_compliance.R','test_osm_toponym.R','test_hardening.R','test_entrypoints.R')) {
    status <- system2(file.path(R.home('bin'),'Rscript'),shQuote(file.path('tests',test)),env=paste0('R_PROFILE_USER=',shQuote(profile)))
    if (status != 0L) stop('Failed suite: ',test)
  }
  cat('All mandatory offline suites passed. Optional sf/exporter acceptance is separate.\n')
}
run_all()
