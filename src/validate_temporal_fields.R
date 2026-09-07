#!/usr/bin/env Rscript
# validate_temporal_fields: shared workbook compliance pipeline, stage temporal.
if (sys.nframe() == 0L) {
  script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  root <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
  source(file.path(root, "src", "compliance", "load.R"))
  quit(status = compliance_cli("temporal", root))
}
