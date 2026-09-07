#!/usr/bin/env Rscript
# inspect_dataset: shared workbook compliance pipeline, stage inspect.
if (sys.nframe() == 0L) {
  script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  root <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
  source(file.path(root, "src", "compliance", "load.R"))
  quit(status = compliance_cli("inspect", root))
}
