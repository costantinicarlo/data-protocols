#!/usr/bin/env Rscript
# Fresh R processes exercise actual CLI and global programmatic entry points.
run_entrypoint_tests <- function() {
  old_options<-options(httr2_mock=function(req)stop('Unexpected unmocked HTTP request'))
  on.exit(options(old_options),add=TRUE)
  root<-normalizePath('.');work<-tempfile('entrypoints-');dir.create(work)
  on.exit(unlink(work,recursive=TRUE),add=TRUE)
  fixtures<-file.path(work,'fixtures')
  stopifnot(system2('python3',c(shQuote(file.path(root,'tests/make_hardening_fixtures.py')),shQuote(fixtures)))==0L)
  profile<-file.path(work,'profile.R');log<-file.path(work,'attempts.csv')
  # Profile is intentionally selected only for these child processes.
  code<-c(
    'clock <- new.env(); clock$now <- 0',
    'options(osm_toponym.clock=function()clock$now, osm_toponym.sleep=function(s){clock$now<-clock$now+s})',
    'options(httr2_mock=function(req) {',
    '  stopifnot(grepl("nominatim.openstreetmap.org/reverse", req$url, fixed=TRUE))',
    '  cat(clock$now, "\\n", file=Sys.getenv("TEST_ATTEMPTS"), append=TRUE)',
    '  if(Sys.getenv("TEST_FAILURE")=="yes") return(httr2::response(200L,headers=list("content-type"="application/json"),body=charToRaw("not JSON")))',
    '  body<-list(name="Synthetic locality",osm_type="node",osm_id=123,lat="13.5",lon="-16.2",category="place",type="village")',
    '  httr2::response(200L,headers=list("content-type"="application/json"),body=charToRaw(jsonlite::toJSON(body,auto_unbox=TRUE)))',
    '})')
  writeLines(code,profile)
  child<-function(args, fail=FALSE, expected=0L) {
    status<-suppressWarnings(system2(file.path(R.home('bin'),'Rscript'),shQuote(args),
      env=c(paste0('R_PROFILE_USER=',shQuote(profile)),paste0('TEST_ATTEMPTS=',shQuote(log)),paste0('TEST_FAILURE=',if(fail)'yes' else 'no')),
      stdout=file.path(work,'child.log'),stderr=file.path(work,'child.log')))
    if(status!=expected)stop(paste(readLines(file.path(work,'child.log')),collapse='\n'))
  }
  oldwd<-getwd();on.exit(setwd(oldwd),add=TRUE);setwd(work)
  writeLines(c('id,latitude,longitude','00017,13.5,-16.2','NA,13.6,-16.3'),'input.csv')
  child(c(file.path(root,'src/osm_toponym.R'),'input.csv','output.geojson'))
  out<-jsonlite::read_json('output.geojson');stopifnot(identical(vapply(out$features,function(f)f$properties$source_id,character(1)),c('00017','NA')))
  stopifnot(length(list.files('.osm_toponym_cache/nominatim'))==2L)
  calls<-length(readLines(log));child(c(file.path(root,'src/osm_toponym.R'),'input.csv','output.geojson'));stopifnot(length(readLines(log))==calls)
  # Programmatic loading into the global environment exposes the original
  # compliance write_json helper, exactly as in the supported public example.
  script<-file.path(work,'programmatic.R');state<-file.path(work,'state')
  writeLines(c(sprintf('source(%s)',deparse(file.path(root,'src/compliance/load.R'))),
    sprintf('load_compliance(%s)',deparse(root)),
    'before_wd<-getwd();before_options<-options()',
    sprintf('out<-run_compliance(%s,%s,"demo_collection",list(enrich_toponyms=TRUE,required_assessments=list("live_toponym_enrichment")))',deparse(file.path(fixtures,'two_tables_fresh.xlsx')),deparse(state)),
    'stopifnot(out$exit_status==0L,identical(getwd(),before_wd),identical(options(),before_options))',
    'for(name in c("data__samples","data__other")) {',
    ' geo<-read_json(file.path(out$manifest$run_dir,"derived",paste0(name,"__toponyms.geojson")))',
    ' stopifnot(length(geo$features)==2L,all(vapply(geo$features,function(f) f$properties$source_id=="SN26_00001",logical(1))))',
    '}',
    'for(artifact in out$manifest$artifacts) stopifnot(artifact$sha256==sha_file(file.path(out$manifest$run_dir,artifact$path)))'),script)
  writeLines(character(),log);child(script)
  timestamps<-scan(log,quiet=TRUE);stopifnot(length(timestamps)==4L,all(diff(timestamps)>=15))
  cache<-file.path(state,'demo_collection/geocoding/.osm_toponym_cache/nominatim');stopifnot(length(list.files(cache))==4L)
  child(script);stopifnot(length(scan(log,quiet=TRUE))==4L)
  # Compliance CLI must also create fresh caches, then replay without requests.
  cli_state<-file.path(work,'cli-state')
  args<-c(file.path(root,'src/run_compliance.R'),file.path(fixtures,'two_tables_fresh.ods'),cli_state,'--source-id','demo_collection','--enrich-toponyms')
  writeLines(character(),log);child(args);stopifnot(length(scan(log,quiet=TRUE))==4L)
  child(args);stopifnot(length(scan(log,quiet=TRUE))==4L)
  pointer<-file.path(cli_state,'demo_collection/current.json');before<-readBin(pointer,'raw',file.info(pointer)$size)
  # All stage entry points remain nonpublishing, even when enrichment requested.
  source(file.path(root,'src/compliance/load.R'),local=environment());load_compliance(root,environment())
  for(ext in c('xlsx','ods')) {
    example<-file.path(root,'examples/compliance',paste0('collection.',ext))
    sample<-suppressMessages(run_compliance(example,file.path(work,paste0('included-',ext)),'demo_collection'))
    stopifnot(sample$exit_status==0L,sample$manifest$snapshot$sha256==sha_file(example))
  }
  for(stage in c('snapshot','inspect','workbook','extract','identifiers','values','temporal','coordinates','lineage','toponymy','report')) {
    out<-suppressMessages(run_compliance(file.path(fixtures,'bounds_valid_rows.xlsx'),cli_state,'demo_collection',list(enrich_toponyms=TRUE),stage=stage))
    stopifnot(out$manifest$status=='assessed_stage_only',identical(readBin(pointer,'raw',file.info(pointer)$size),before))
  }
  # Force failed enrichment on a new state with a previously validated pointer.
  failed_state<-file.path(work,'failed-state')
  base<-suppressMessages(run_compliance(file.path(fixtures,'bounds_valid_rows.xlsx'),failed_state,'demo_collection'))
  p<-file.path(failed_state,'demo_collection/current.json');saved<-readBin(p,'raw',file.info(p)$size)
  child(c(file.path(root,'src/run_compliance.R'),file.path(fixtures,'bounds_valid_rows.xlsx'),failed_state,'--source-id','demo_collection','--enrich-toponyms'),fail=TRUE,expected=2L)
  stopifnot(identical(readBin(p,'raw',file.info(p)$size),saved))
  latest<-read_json(file.path(failed_state,'demo_collection/latest_attempt.json'));manifest<-read_json(file.path(latest$run_dir,'manifest.json'))
  stopifnot(manifest$status=='failed',file.exists(manifest$snapshot$path))
  failure_script<-file.path(work,'programmatic-failure.R')
  lines<-gsub(deparse(state),deparse(failed_state),readLines(script),fixed=TRUE)
  lines<-gsub('out$exit_status==0L','out$exit_status==2L',lines,fixed=TRUE)
  writeLines(lines,failure_script)
  child(failure_script,fail=TRUE)
  stopifnot(identical(readBin(p,'raw',file.info(p)$size),saved))

  cat('Fresh-process CLI/programmatic cache, coverage, rate, and publication checks passed.\n')
}
run_entrypoint_tests()
