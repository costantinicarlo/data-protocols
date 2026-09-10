# Forensic reproduction against the audited source, not the corrected generator.
# Usage: Rscript docs/release-evidence/reproduce-baseline-retry.R BASELINE_ROOT
# The httr2 1.3.0 high-level mock bypasses its internal retries. Copy its request
# performer into a child environment that shadows ONLY transport and time, so
# the actual baseline retry policy/body executes without network or real sleep.
reproduce <- function(root) {
  script <- normalizePath(file.path(root,'src/osm_toponym.R'))
  work<-tempfile('baseline-retry-');dir.create(work);oldwd<-getwd()
  oldopts<-options(httr2_mock=NULL,httr2_progress=FALSE)
  on.exit({options(oldopts);setwd(oldwd);unlink(work,recursive=TRUE)})
  setwd(work)
  e<-new.env(parent=globalenv());sys.source(script,envir=e)
  stopifnot(grepl('1.1.1',paste(readLines(script),collapse='\n'),fixed=TRUE))
  now<-0;attempts<-numeric();e$NOMINATIM_DELAY<-15
  e$Sys.sleep<-function(seconds){now<<-now+seconds}
  transport<-new.env(parent=asNamespace('httr2'))
  transport$Sys.time<-function()as.POSIXct('2026-09-08',tz='UTC')+now
  transport$sys_sleep<-function(seconds,...) {if(is.finite(seconds)&&seconds>0)now<<-now+seconds}
  transport$req_perform1<-function(...) {
    attempts<<-c(attempts,now)
    if(length(attempts)==1L)httr2::response(503L,headers=list('retry-after'='0'))
    else httr2::response(200L,headers=list('content-type'='application/json'),body=charToRaw('{"name":"Synthetic","osm_type":"node","osm_id":123,"lat":"13.5","lon":"-16.2","category":"place","type":"village"}'))
  }
  performer<-httr2::req_perform;environment(performer)<-transport
  e$req_perform<-performer
  e$reverse_osm(13.5,-16.2)
  stopifnot(length(attempts)==2L,diff(attempts)<15)
  cat('Audited generator 1.1.1; configured interval: 15 seconds\n')
  cat('Actual transport attempt timestamps (fake monotonic seconds):',paste(attempts,collapse=', '),'\n')
  cat('Observed gap:',diff(attempts),'seconds; defect reproduced with Retry-After: 0.\n')
}
reproduce(commandArgs(trailingOnly=TRUE)[1])
