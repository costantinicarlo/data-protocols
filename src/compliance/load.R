load_compliance <- function(root, envir = parent.frame()) {
  for (package in c("jsonlite", "xml2", "digest")) if (!requireNamespace(package, quietly = TRUE)) stop("Install required R package: ", package)
  assign("COMPLIANCE_ROOT", normalizePath(root, mustWork = TRUE), envir)
  for (file in c("common.R", "workbook.R", "structure.R", "identifiers.R", "coordinates.R", "values.R", "pipeline.R")) {
    # Mark literals as UTF-8 without transcoding through the host's locale.
    eval(parse(file.path(root, "src", "compliance", file), encoding = "UTF-8", keep.source = FALSE), envir = envir)
  }
  invisible(envir)
}
compliance_cli <- function(stage, root, args = commandArgs(trailingOnly = TRUE)) {
  if ("--help" %in% args || length(args) < 4L) {
    cat("Usage: Rscript src/<script>.R WORKBOOK.xlsx|WORKBOOK.ods STATE_DIR --source-id WORKBOOK_ID [--config CONFIG.json] [--enrich-toponyms]\n",
        "Workbook identity, field rules, and key declarations are read from source metadata.\n",
        "Only run_compliance.R publishes a complete validated build; individual scripts assess their named stage.\n", sep = "")
    return(if ("--help" %in% args) 0L else 1L)
  }
  tryCatch({
    input <- args[1]; state <- args[2]; config_path <- NULL; source_id <- NULL; enrich <- FALSE
    i <- 3L
    while (i <= length(args)) {
      arg <- args[i]
      if (arg == "--enrich-toponyms") { enrich <- TRUE; i <- i + 1L; next }
      if (!arg %in% c("--source-id", "--config") || i == length(args)) stop("Invalid command-line argument: ", arg)
      if (arg == "--source-id") source_id <- args[i + 1L] else config_path <- args[i + 1L]
      i <- i + 2L
    }
    if (is.null(source_id)) stop("--source-id is required")
    namespace <- new.env(parent = globalenv()); load_compliance(root, namespace)
    config <- if (is.null(config_path)) list() else namespace$read_json(config_path)
    if (enrich) config$enrich_toponyms <- TRUE
    directory <- if (is.null(config_path)) getwd() else dirname(normalizePath(config_path, mustWork = TRUE))
    namespace$run_compliance(input, state, source_id, config, directory, stage)$exit_status
  }, error = function(e) { message("Error: ", conditionMessage(e)); 1L })
}
