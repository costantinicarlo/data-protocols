#!/usr/bin/env Rscript
# All checks use synthetic workbooks, mocked HTTP, and fake monotonic time.
run_hardening_tests <- function() {
  stopifnot(requireNamespace('httr2', quietly=TRUE))
  root <- normalizePath('.')
  source('src/compliance/load.R', local = environment())
  load_compliance(root, environment())
  work <- tempfile('hardening-'); dir.create(work)
  oldwd <- getwd(); oldopts <- options(httr2_mock = function(req) stop('Unexpected unmocked HTTP request'))
  on.exit({setwd(oldwd); options(oldopts); unlink(work, recursive=TRUE)}, add=TRUE)
  fixtures <- file.path(work,'fixtures')
  stopifnot(system2('python3',c(shQuote(file.path(root,'tests/make_hardening_fixtures.py')),shQuote(fixtures))) == 0)
  failures <- character()
  test <- function(name, body) {
    tryCatch({body(); cat('PASS',name,'\n')}, error=function(e) {
      failures <<- c(failures,name); cat('FAIL',name,':',conditionMessage(e),'\n')
    })
  }
  run <- function(name, ext='xlsx', config=list(), stage='all') suppressMessages(run_compliance(file.path(fixtures,paste0(name,'.',ext)),file.path(work,'state',ext),'demo_collection',config,stage=stage))
  pointer <- function(ext) file.path(work,'state',ext,'demo_collection','current.json')
  failed <- function(name,ext='xlsx',config=list(),stage='all') {
    p <- pointer(ext); before <- if(file.exists(p)) readBin(p,'raw',n=file.info(p)$size) else NULL
    out <- run(name,ext,config,stage)
    stopifnot(out$exit_status==2L, file.exists(out$manifest$snapshot$path), file.exists(file.path(out$manifest$run_dir,'findings.json')))
    after <- if(file.exists(p)) readBin(p,'raw',n=file.info(p)$size) else NULL
    stopifnot(identical(before,after)); out
  }
  for(ext in c('xlsx','ods')) {
    test(paste('F01 valid limits',ext),function() stopifnot(run('bounds_valid_rows',ext)$exit_status==0L))
    for(name in c('bounds_no_type','bounds_text','bounds_inf','bounds_reverse','bounds_vector','bad_type','bad_required','vocab_object','vocab_nested','vocab_null','vocab_mixed','missing_object')) for(shape in c('rows','empty','missing')) {
      local({n<-paste(name,shape,sep='_'); e<-ext; test(paste('F01',n,e),function() failed(n,e))})
    }
    test(paste('F01 empty vocabulary',ext),function() {
      failed('vocab_empty_rows',ext)
      stopifnot(run('vocab_empty_missing',ext)$exit_status==0L,run('vocab_empty_empty',ext)$exit_status==0L,run('vocab_valid_rows',ext)$exit_status==0L)
    })
    for(typ in c('date','datetime','time','duration','partial_date')) local({t<-typ;e<-ext
      test(paste('F04',t,e),function() {
        out<-run(paste0('temporal_',t,'_declared'),e); stopifnot(out$exit_status==0L)
        csv<-read.csv(file.path(out$manifest$run_dir,'original/data__samples.csv'),colClasses='character',na.strings='\\N')
        stopifnot(identical(csv$historical,c('NA','NA')))
        infos<-Filter(function(f) f$rule_id=='value.legacy_missing_code',out$context$findings)
        stopifnot(length(infos)==2L,all(vapply(infos,function(f) f$original_value=='NA',logical(1))))
        failed(paste0('temporal_',t,'_undeclared'),e); failed(paste0('temporal_',t,'_required'),e)
        stopifnot(run(paste0('temporal_',t,'_blank'),e)$exit_status==0L,run(paste0('temporal_',t,'_iso'),e)$exit_status==0L)
      })
    })
    test(paste('F04 key exceptions',ext),function() {failed('missing_key_code',ext);failed('missing_key',ext)})
    test(paste('F07 long full-year range',ext),function() stopifnot(run('year_four',ext)$exit_status==0L,run('year_century',ext)$exit_status==0L))
    for(n in c('year_outside','year_ambiguous','year_bad_range','year_object','year_huge','year_bad_width','year_bad_digits','year_empty_digits','year_null_width')) local({name<-n;e<-ext;test(paste('F07',name,e),function() failed(name,e))})
  }
  for(n in c('ods_two_cells','ods_groups','ods_formula','ods_excluded','ods_overflow','ods_fraction','ods_zero')) local({name<-n
    test(paste('F06',name),function() stopifnot(inherits(tryCatch(inspect_dataset(file.path(fixtures,paste0(name,'.ods')),100),error=identity),'error')))
  })
  test('F06 exact and blank',function() {
    stopifnot(nrow(inspect_dataset(file.path(fixtures,'ods_exact.ods'),100)$sheets[[1]]$cells)==100L,nrow(inspect_dataset(file.path(fixtures,'ods_blank.ods'),100)$sheets[[1]]$cells)==0L)
  })
  test('F01 scalar representations and single metadata diagnostics',function() {
    ctx<-new_context(list(),'test',work)
    stopifnot(is.null(json_values(ctx,NULL,'s','f')),identical(json_values(ctx,'[]','s','f'),character()),
              identical(json_values(ctx,'[true,false]','s','f'),c('TRUE','FALSE')),
              identical(json_values(ctx,'["NA","  exact  "]','s','f'),c('NA','  exact  ')))
    out<-failed('bounds_inf_rows'); errors<-Filter(function(f)f$rule_id=='metadata.numeric_bound',out$context$findings)
    stopifnot(length(errors)==1L,run('missing_empty')$exit_status==0L)
    failed('vocab_disallowed');failed('vocab_empty_reference')
  })
  test('F04 invalid real temporal values still block publication',function() {
    for(n in c('temporal_bad_date','temporal_no_zone','temporal_ambiguous')) failed(n)
    failed('temporal_time_required',stage='temporal')
  })
  test('F06 expansion is rejected before occupied cells materialise',function() {
    e<-new.env(parent=environment());e$cell_ref<-function(...)stop('MATERIALISED')
    reader<-read_ods;environment(reader)<-e
    p<-file.path(fixtures,'ods_two_cells.ods')
    err<-tryCatch(reader(p,utils::unzip(p,list=TRUE),100),error=identity)
    stopifnot(inherits(err,'error'),grepl('limit exceeded',conditionMessage(err)))
    stopifnot(inherits(tryCatch(inspect_dataset(file.path(fixtures,'ods_index_overflow.ods'),100),error=identity),'error'))
    stopifnot(nrow(inspect_dataset(file.path(fixtures,'xlsx_exact.xlsx'),100)$sheets[[1]]$cells)==100L,
      inherits(tryCatch(inspect_dataset(file.path(fixtures,'xlsx_over.xlsx'),100),error=identity),'error'))
  })
  # A separate resolver environment prevents test mocks leaking across groups.
  engine <- function() {
    d<-tempfile('engine-',tmpdir=work);dir.create(d);setwd(d)
    e<-new.env(parent=globalenv());sys.source(file.path(root,'src/osm_toponym.R'),envir=e)
    e$Sys.sleep<-function(seconds) invisible(NULL) # Baseline outer sleep only; new limiter uses fake clock below.
    e$NOMINATIM_DELAY<-15; clock<-new.env();clock$now<-0
    e$REQUEST_CLOCK<-function() clock$now
    e$REQUEST_SLEEP<-function(seconds) {clock$now<-clock$now+seconds}
    e$REQUEST_WALL_CLOCK<-function() as.POSIXct('2026-09-08',tz='UTC')
    e
  }
  reply <- function(status=200L,body=list(),hint='0') httr2::response(status,headers=list('content-type'='application/json','retry-after'=hint),body=charToRaw(if(is.character(body))body else jsonlite::toJSON(body,auto_unbox=TRUE)))
  reverse <- list(name='Synthetic village',osm_type='relation',osm_id=123,lat='13.5',lon='-16.2',category='boundary',type='administrative',address=list(country_code='sn'))
  node <- list(type='node',id=123,lat=13.5,lon=-16.2,tags=list(name='Synthetic village',place='village'))
  for(body in list('{"remark":"runtime error: timeout","elements":[]}',jsonlite::toJSON(list(remark='runtime error: memory',elements=list(node)),auto_unbox=TRUE),'{}','{"elements":{}}','{"elements":null}','{"elements":[{}]}','{"elements":[],"remark":"unknown notice"}','{"elements":[],"remark":" "}')) local({b<-body
    test(paste('F02 rejected envelope',b),function() {
      e<-engine();options(httr2_mock=function(req) if(grepl('nominatim',req$url))reply(body=reverse) else reply(body=b))
      out<-suppressWarnings(e$resolve_toponyms(data.frame(id='A',latitude=13.5,longitude=-16.2)))
      stopifnot(out$features[[1]]$properties$status=='unresolved',length(list.files(e$OVERPASS_CACHE_DIR,pattern='\\.json$'))==0L)
    })
  })
  test('F02 old error cache and valid empty',function() {
    e<-engine();p<-file.path(e$OVERPASS_CACHE_DIR,'13.5000000_-16.2000000_r5000.json')
    bytes<-'{"elements":[],"remark":"runtime error: timeout"}';writeLines(bytes,p)
    calls<-0L;options(httr2_mock=function(req) {calls<<-calls+1L;reply(body='{"elements":[]}')})
    stopifnot(length(e$query_place_nodes(13.5,-16.2))==0L,calls==1L)
    quarantined<-list.files(file.path(e$CACHE_DIR,'failures'),recursive=TRUE,full.names=TRUE)
    stopifnot(any(vapply(quarantined,function(f) identical(readLines(f,warn=FALSE),bytes),logical(1))))
    stopifnot(length(e$query_place_nodes(13.5,-16.2))==0L,calls==1L)
  })
  test('F02 valid candidates and fallback',function() {
    for(nodes in list(list(),list(node))) {
      e<-engine();options(httr2_mock=function(req) if(grepl('nominatim',req$url))reply(body=reverse) else reply(body=list(elements=nodes)))
      out<-e$resolve_toponyms(data.frame(id='A',latitude=13.5,longitude=-16.2))
      stopifnot(out$features[[1]]$properties$status==if(length(nodes))'node_exact' else 'osm_fallback')
    }
  })
  test('F03 actual CSV path preserves identifiers',function() {
    e<-engine();r<-reverse;r$osm_type<-'node';r$category<-'place';options(httr2_mock=function(req)reply(body=r))
    ids<-c('00017','123456789012345678901234567890','NA','N/A','NULL','Médina','Text_1','  A  ','Text_1')
    for(batch in list(ids,c('00017','00018'),c('123456789012345678901234567890','123456789012345678901234567891'),c('NA','N/A','NULL'))) {
      write.csv(data.frame(id=batch,latitude=13.5,longitude=-16.2),'input.csv',row.names=FALSE,fileEncoding='UTF-8')
      stopifnot(e$main(c('input.csv','output.geojson'))==0L)
      out<-jsonlite::read_json('output.geojson');stopifnot(identical(vapply(out$features,function(f)f$properties$source_id,character(1)),batch))
    }
  })
  test('F03 prevalidation preserves output and makes zero requests',function() {
    e<-engine();calls<-0L;options(httr2_mock=function(req){calls<<-calls+1L;stop('Unexpected request')})
    for(rows in list(c('id,latitude,longitude','A,13,-16',',13,-16'),c('id,latitude,longitude','A,13,-16','  ,13,-16'),c('id,id,latitude,longitude','A,B,13,-16'),c('id,latitude,longitude','A,13,-16','B,91,-16'),c('id,latitude,longitude','A,13,-16,extra'),c('id,latitude,longitude','A,13'),c(' id,latitude,longitude','A,13,-16'))) {
      writeLines(rows,'input.csv');writeLines('previous','output.geojson')
      err<-tryCatch(e$main(c('input.csv','output.geojson')),error=identity)
      stopifnot(inherits(err,'error'),calls==0L,identical(readLines('output.geojson'),'previous'))
    }
  })
  test('F08 global JSON helper collision',function() {
    before<-if(exists('write_json',globalenv(),inherits=FALSE))get('write_json',globalenv()) else NULL
    on.exit(if(is.null(before))rm('write_json',envir=globalenv()) else assign('write_json',before,globalenv()))
    assign('write_json',function(x,path)stop('wrong helper'),globalenv())
    e<-engine();r<-reverse;r$osm_type<-'node';r$category<-'place';calls<-0L
    options(httr2_mock=function(req){calls<<-calls+1L;reply(body=r)})
    writeLines(c('id,latitude,longitude','00017,13.5,-16.2'),'input.csv')
    stopifnot(e$main(c('input.csv','output.geojson'))==0L,e$main(c('input.csv','output.geojson'))==0L,calls==1L,length(list.files(e$NOMINATIM_CACHE_DIR))==1L,jsonlite::read_json('output.geojson')$features[[1]]$properties$source_id=='00017')
  })
  test('F09 every actual retry respects service interval',function() {
    for(status in c(0L,500L,502L,503L,504L,429L)) for(hint in c('0','1','30','bad','')) {
      e<-engine();times<-numeric();options(httr2_mock=function(req) {
        times<<-c(times,e$REQUEST_CLOCK());if(length(times)>1L)return(reply(body=reverse))
        if(status==0L) {err<-simpleError('transport failure');class(err)<-c('httr2_failure',class(err));stop(err)}
        reply(status,hint=hint)
      })
      e$perform_api_request(e$api_request('https://example.test'),'Nominatim')
      stopifnot(length(times)==2L,diff(times)>=if(hint=='30' && status!=0L)30 else 15)
    }
  })
  test('F09 bounded attempts, budget, denial and cache',function() {
    for(status in c(401L,403L,429L,503L)) {
      e<-engine();times<-numeric();options(httr2_mock=function(req){times<<-c(times,e$REQUEST_CLOCK());reply(status)})
      err<-tryCatch(e$perform_api_request(e$api_request('https://example.test'),'Nominatim'),error=identity)
      stopifnot(inherits(err,'error'),length(times)==if(status %in% c(401L,403L))1L else 4L,all(diff(times)>=15))
      if(status %in% c(401L,403L,429L))stopifnot(inherits(err,'osm_service_denied'))
    }
    e<-engine();calls<-0L;options(httr2_mock=function(req){calls<<-calls+1L;reply(429L,hint='121')})
    stopifnot(inherits(tryCatch(e$perform_api_request(e$api_request('https://example.test'),'Nominatim'),error=identity),'osm_service_denied'),calls==1L)
    e<-engine();times<-numeric();options(httr2_mock=function(req){times<<-c(times,e$REQUEST_CLOCK());reply(body=reverse)})
    e$reverse_osm(13.5,-16.2);e$reverse_osm(13.6,-16.2);e$reverse_osm(13.5,-16.2)
    stopifnot(length(times)==2L,diff(times)>=15)
  })
  test('F09 HTTP dates, remaining budget and cross-record cooldown',function() {
    e<-engine()
    stopifnot(e$retry_after_seconds(reply(503L,hint='Tue, 08 Sep 2026 00:00:30 GMT'))==30,
      e$retry_after_seconds(reply(503L,hint='not a date'))==0,
      e$retry_after_seconds(httr2::response(503L))==0)
    times<-numeric();e$REQUEST_BUDGET<-20
    options(httr2_mock=function(req){times<<-c(times,e$REQUEST_CLOCK());reply(503L)})
    err<-tryCatch(e$perform_api_request(e$api_request('https://example.test'),'Nominatim'),error=identity)
    stopifnot(inherits(err,'error'),identical(times,c(0,15)))
    e<-engine();calls<-0L;options(httr2_mock=function(req){calls<<-calls+1L;reply(503L,hint='200')})
    for(i in 1:2) stopifnot(inherits(tryCatch(e$perform_api_request(e$api_request('https://example.test'),'Nominatim'),error=identity),'error'))
    stopifnot(calls==1L)
  })
  test('F02 CLI and enriched publication reject incomplete Overpass',function() {
    e<-engine();options(httr2_mock=function(req) if(grepl('nominatim',req$url))reply(body=reverse) else reply(body=list(remark='runtime error: timeout',elements=list(node))))
    writeLines(c('id,latitude,longitude','A,13.5,-16.2'),'input.csv')
    stopifnot(suppressWarnings(e$main(c('input.csv','out.geojson')))==2L,jsonlite::read_json('out.geojson')$features[[1]]$properties$status=='unresolved')
    setwd(root)
    state<-file.path(work,'overpass_failure')
    base<-suppressMessages(run_compliance(file.path(fixtures,'bounds_valid_rows.xlsx'),state,'demo_collection'))
    p<-file.path(state,'demo_collection/current.json');before<-read_json(p)
    now<-0;opts<-options(osm_toponym.clock=function()now,osm_toponym.sleep=function(s){now<<-now+s})
    on.exit(options(opts),add=TRUE)
    out<-suppressWarnings(suppressMessages(run_compliance(file.path(fixtures,'bounds_valid_rows.xlsx'),state,'demo_collection',list(enrich_toponyms=TRUE))))
    stopifnot(out$exit_status==2L,identical(read_json(p),before),file.exists(out$manifest$snapshot$path),identical(getwd(),root))
  })
  setwd(root)
  # Cache replay coverage is independent of request timing; misses tested above and in subprocess checks.
  test('F05 required eligible enrichment',function() {
    d<-file.path(work,'state/xlsx/demo_collection/geocoding/.osm_toponym_cache/nominatim');dir.create(d,recursive=TRUE,showWarnings=FALSE)
    r<-reverse;r$osm_type<-'node';r$category<-'place'
    for(xy in list(c(13.63332,-16.3874),c(13.5,-16.2))) jsonlite::write_json(r,file.path(d,sprintf('%.7f_%.7f_zoom15.json',xy[1],xy[2])),auto_unbox=TRUE)
    out<-run('two_tables',config=list(enrich_toponyms=TRUE,required_assessments=list('live_toponym_enrichment')))
    stopifnot(out$exit_status==0L)
    for(n in c('data__samples','data__other')) {
      geo<-read_json(file.path(out$manifest$run_dir,'derived',paste0(n,'__toponyms.geojson')))
      stopifnot(length(geo$features)==2L,all(vapply(geo$features,function(f)f$properties$source_id=='SN26_00001',logical(1))))
    }
  })
  test('F05 disabled, empty, unknown, core error and stages',function() {
    calls<-0L;options(httr2_mock=function(req){calls<<-calls+1L;stop('Unexpected request')})
    failed('bounds_valid_rows',config=list(required_assessments=list('live_toponym_enrichment')))
    failed('no_coordinates',config=list(enrich_toponyms=TRUE,required_assessments=list('live_toponym_enrichment')))
    failed('bounds_valid_rows',config=list(required_assessments=list('unknown')))
    failed('bounds_reverse_rows',config=list(enrich_toponyms=TRUE));stopifnot(calls==0L)
    p<-read_json(pointer('xlsx'));out<-run('bounds_valid_rows',stage='extract',config=list(enrich_toponyms=TRUE))
    stopifnot(identical(read_json(pointer('xlsx')),p),calls==0L)
    for(config in list(list(a='identifier_profile'),list(list('identifier_profile')),list(''),list(1))) {
      err<-tryCatch(run('bounds_valid_rows',config=list(required_assessments=config)),error=identity)
      stopifnot(inherits(err,'error'),identical(read_json(pointer('xlsx')),p))
    }
  })
  if(length(failures))stop(length(failures),' hardening groups failed: ',paste(failures,collapse='; '),call.=FALSE)
  cat('All release-hardening checks passed.\n')
}
run_hardening_tests()
