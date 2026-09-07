attr_local <- function(node, name, default = NA_character_) {
  value <- xml2::xml_text(xml2::xml_find_first(node, paste0("./@*[local-name()='", name, "']")))
  if (is.na(value)) default else value
}
node_text <- function(node, xpath) xml2::xml_text(xml2::xml_find_first(node, xpath))
zip_xml <- function(path, member, entries) {
  entry <- entries[entries$Name == member, , drop = FALSE]
  if (nrow(entry) != 1L || entry$Length > 100 * 1024^2) stop("Missing, duplicate, or oversized XML member: ", member)
  con <- unz(path, member, open = "rb"); on.exit(close(con))
  bytes <- readBin(con, "raw", n = entry$Length)
  text <- rawToChar(bytes)
  if (grepl("<!DOCTYPE|<!ENTITY", text, ignore.case = TRUE)) stop("XML document type/entity declarations are not supported")
  xml2::read_xml(bytes, options = "NONET")
}
rich_text <- function(node, xpath = ".//*[local-name()='t' and not(ancestor::*[local-name()='rPh'])]") {
  paste0(xml2::xml_text(xml2::xml_find_all(node, xpath)), collapse = "")
}
format_kind <- function(id, format = "") {
  if (id %in% 14:17) return("date")
  if (id == 22L) return("datetime")
  if (id %in% c(18:21, 45L, 47L)) return("time")
  if (id == 46L) return("duration")
  fmt <- tolower(gsub('"[^\"]*"|\\\\.', "", format, perl = TRUE))
  if (grepl("\\[[hms]+\\]", fmt)) return("duration")
  fmt <- gsub("\\[[^]]*\\]", "", fmt)
  date <- grepl("[yd]", fmt); time <- grepl("[hs]", fmt)
  if (date && time) "datetime" else if (date) "date" else if (time) "time" else "number"
}
excel_temporal <- function(value, kind, date1904) {
  n <- suppressWarnings(as.numeric(value))
  if (!is.finite(n) || n < 0) return(list(type = "temporal_error", value = value))
  if (kind %in% c("date", "datetime")) {
    day <- floor(n); fraction <- n - day
    if (!date1904 && day == 60) return(list(type = "temporal_error", value = value))
    origin <- if (date1904) "1904-01-01" else if (day < 60) "1899-12-31" else "1899-12-30"
    date <- format(as.Date(day, origin = origin), "%Y-%m-%d")
    if (kind == "date" && fraction != 0) return(list(type = "temporal_error", value = value))
    if (kind == "date") return(list(type = kind, value = date))
    time <- excel_temporal(fraction, "time", date1904)
    return(list(type = "datetime", value = paste0(date, "T", time$value)))
  }
  seconds <- n * 86400
  if (kind == "duration") return(list(type = "duration", value = sprintf("PT%.9fS", seconds)))
  if (n >= 1) return(list(type = "temporal_error", value = value))
  # Preserve fractional seconds, accounting only for floating-point conversion noise.
  seconds <- round(seconds, 6)
  if (seconds >= 86400) return(list(type = "temporal_error", value = value))
  hour <- floor(seconds / 3600); minute <- floor(seconds %% 3600 / 60); sec <- seconds %% 60
  clock <- sprintf("%02d:%02d:%09.6f", hour, minute, sec)
  clock <- sub("0+$", "", clock); clock <- sub("\\.$", "", clock)
  list(type = "time", value = clock)
}
read_xlsx <- function(path, entries, max_cells) {
  book <- zip_xml(path, "xl/workbook.xml", entries)
  rels <- zip_xml(path, "xl/_rels/workbook.xml.rels", entries)
  relationships <- xml2::xml_find_all(rels, "//*[local-name()='Relationship']")
  date1904 <- attr_local(xml2::xml_find_first(book, "//*[local-name()='workbookPr']"), "date1904", "0") %in% c("1", "true")
  strings <- character()
  if ("xl/sharedStrings.xml" %in% entries$Name) {
    ss <- zip_xml(path, "xl/sharedStrings.xml", entries)
    strings <- vapply(xml2::xml_find_all(ss, "//*[local-name()='si']"), rich_text, character(1))
  }
  styles <- list(list(kind = "number"))
  if ("xl/styles.xml" %in% entries$Name) {
    st <- zip_xml(path, "xl/styles.xml", entries)
    fmts <- xml2::xml_find_all(st, "//*[local-name()='numFmts']/*[local-name()='numFmt']")
    custom <- setNames(vapply(fmts, attr_local, character(1), name = "formatCode"), vapply(fmts, attr_local, character(1), name = "numFmtId"))
    xfs <- xml2::xml_find_all(st, "//*[local-name()='cellXfs']/*[local-name()='xf']")
    styles <- lapply(xfs, function(xf) {
      id <- as.integer(attr_local(xf, "numFmtId", "0"))
      list(kind = format_kind(id, scalar(custom[as.character(id)])))
    })
  }
  sheets <- lapply(xml2::xml_find_all(book, "//*[local-name()='sheets']/*[local-name()='sheet']"), function(sh) {
    name <- attr_local(sh, "name")
    rid <- attr_local(sh, "id")
    rel <- relationships[vapply(relationships, attr_local, character(1), name = "Id") == rid]
    if (length(rel) != 1L || attr_local(rel[[1]], "TargetMode", "") == "External") stop("Invalid worksheet relationship: ", name)
    target <- attr_local(rel[[1]], "Target")
    if (grepl("(^|/)\\.\\.(/|$)|\\\\", target)) stop("Unsupported worksheet relationship target")
    target <- if (startsWith(target, "/")) substring(target, 2) else paste0("xl/", sub("^\\./", "", target))
    doc <- zip_xml(path, target, entries)
    if (xml2::xml_name(xml2::xml_root(doc)) != "worksheet") stop("Unsupported non-worksheet sheet: ", name)
    nodes <- xml2::xml_find_all(doc, "//*[local-name()='sheetData']/*[local-name()='row']/*[local-name()='c']")
    if (length(nodes) > max_cells) stop("Workbook cell limit exceeded")
    cells <- lapply(nodes, function(c) {
      ref <- attr_local(c, "r")
      if (!grepl("^[A-Z]+[1-9][0-9]*$", ref)) stop("Invalid/missing XLSX cell address")
      row <- as.integer(sub("^[A-Z]+", "", ref)); col <- col_number(sub("[0-9]+$", "", ref))
      typ <- attr_local(c, "t", "n"); value <- node_text(c, "./*[local-name()='v']")
      fn <- xml2::xml_find_first(c, "./*[local-name()='f']")
      formula <- if (inherits(fn, "xml_missing")) NA_character_ else xml2::xml_text(fn)
      if (typ == "s") {
        index <- suppressWarnings(as.integer(value)) + 1L
        if (is.na(index) || index < 1L || index > length(strings)) stop("Invalid shared-string index at ", name, "!", ref)
        value <- strings[index]; typ <- "text"
      } else if (typ == "inlineStr") { value <- rich_text(c); typ <- "text"
      } else if (typ == "str") typ <- "text"
      else if (typ == "e") typ <- "error"
      else if (typ == "b") { typ <- "boolean"; if (!is.na(value)) value <- if (value == "1") "TRUE" else if (value == "0") "FALSE" else value
      } else if (typ == "d") typ <- if (!is.na(value) && grepl("T", value)) "datetime" else "date"
      else if (typ == "n") {
        typ <- if (is.na(value)) "blank" else "number"
        style <- as.integer(attr_local(c, "s", "0")) + 1L
        if (style > length(styles) || style < 1L) stop("Invalid style index")
        kind <- styles[[style]]$kind
        if (!is.na(value) && kind != "number") {
          converted <- excel_temporal(value, kind, date1904); value <- converted$value; typ <- converted$type
        }
      } else stop("Unsupported XLSX cell type: ", typ)
      data.frame(row = row, col = col, ref = ref, type = typ, value = value, formula = formula, stringsAsFactors = FALSE)
    })
    cells <- if (length(cells)) do.call(rbind, cells) else empty_cells()
    if (anyDuplicated(cells$ref)) stop("Duplicate XLSX cell addresses")
    list(name = name, state = attr_local(sh, "state", "visible"), cells = cells,
         merges = vapply(xml2::xml_find_all(doc, "//*[local-name()='mergeCell']"), attr_local, character(1), name = "ref"),
         style_evidence = list(conditional_formatting = length(xml2::xml_find_all(doc, "//*[local-name()='conditionalFormatting']")),
                               data_validation = length(xml2::xml_find_all(doc, "//*[local-name()='dataValidation']"))))
  })
  list(format = "xlsx", date_system = if (date1904) "1904" else "1900", sheets = sheets)
}
ods_text <- function(node) {
  walk <- function(n) {
    if (xml2::xml_type(n) == "text") return(xml2::xml_text(n))
    kind <- xml2::xml_name(n)
    if (kind == "s") {
      count <- as.integer(attr_local(n, "c", "1")); if (is.na(count) || count > 1000000L) stop("Oversized ODS space sequence")
      return(strrep(" ", count))
    }
    if (kind == "tab") return("\t")
    if (kind == "line-break") return("\n")
    paste0(vapply(xml2::xml_contents(n), walk, character(1)), collapse = "")
  }
  ps <- xml2::xml_find_all(node, "./*[local-name()='p']")
  if (!length(ps)) return(NA_character_)
  paste(vapply(ps, walk, character(1)), collapse = "\n")
}
read_ods <- function(path, entries, max_cells) {
  doc <- zip_xml(path, "content.xml", entries)
  tabs <- xml2::xml_find_all(doc, "//*[local-name()='spreadsheet']/*[local-name()='table']")
  sheets <- lapply(tabs, function(tab) {
    name <- attr_local(tab, "name"); cells <- list(); merges <- character(); ri <- 1L; count <- 0L
    if (length(xml2::xml_find_all(tab, ".//*[local-name()='table']"))) stop("Nested ODS tables are unsupported")
    for (row in xml2::xml_find_all(tab, ".//*[local-name()='table-row']")) {
      nr <- suppressWarnings(as.integer(attr_local(row, "number-rows-repeated", "1")))
      if (is.na(nr) || nr < 1L) stop("Invalid ODS row repetition")
      ci <- 1L; rowcells <- list()
      for (cell in xml2::xml_find_all(row, "./*[local-name()='table-cell' or local-name()='covered-table-cell']")) {
        nc <- suppressWarnings(as.integer(attr_local(cell, "number-columns-repeated", "1")))
        if (is.na(nc) || nc < 1L) stop("Invalid ODS column repetition")
        formula <- attr_local(cell, "formula")
        type <- attr_local(cell, "value-type", "blank")
        text <- ods_text(cell)
        value <- switch(type,
          string = { type <- "text"; attr_local(cell, "string-value", text) },
          float =, percentage =, currency = { type <- "number"; attr_local(cell, "value") },
          boolean = { toupper(attr_local(cell, "boolean-value")) },
          date = { attr_local(cell, "date-value") },
          time = { type <- "duration"; attr_local(cell, "time-value") },
          error = { text },
          blank = { if (!is.na(text)) type <- "text"; text },
          { stop("Unsupported ODS value type: ", type) })
        if (type == "date" && !is.na(value) && grepl("T", value)) type <- "datetime"
        if (!is.na(text) && grepl("^#(DIV/0!|N/A|VALUE!|REF!|NAME\\?|NUM!|NULL!)$", text) && type != "text") type <- "error"
        if (length(xml2::xml_find_all(cell, "./@*[local-name()='value-type' and .='error']"))) type <- "error"
        span <- as.integer(attr_local(cell, "number-columns-spanned", "1"))
        rspan <- as.integer(attr_local(cell, "number-rows-spanned", "1"))
        if (span > 1L || rspan > 1L) merges <- c(merges, cell_ref(ri, ci))
        occupied <- !is.na(value) || !is.na(formula)
        if (occupied) {
          if (as.double(nc) * nr + count > max_cells) stop("Workbook occupied-cell limit exceeded")
          for (j in seq_len(nc)) rowcells[[length(rowcells) + 1L]] <- list(col = ci + j - 1L, type = type, value = value, formula = formula)
        }
        ci <- ci + nc
        if (!is.finite(ci)) stop("Invalid ODS column index")
      }
      if (length(rowcells)) for (k in seq_len(nr)) for (cell in rowcells) {
        count <- count + 1L
        cells[[count]] <- data.frame(row = ri + k - 1L, col = cell$col, ref = cell_ref(ri + k - 1L, cell$col),
                                    type = cell$type, value = cell$value, formula = cell$formula, stringsAsFactors = FALSE)
      }
      ri <- ri + nr
      if (!is.finite(ri)) stop("Invalid ODS row index")
    }
    list(name = name, state = "recorded_in_snapshot", cells = if (length(cells)) do.call(rbind, cells) else empty_cells(),
         merges = merges, style_evidence = list())
  })
  list(format = "ods", date_system = "ISO typed values", sheets = sheets)
}
inspect_dataset <- function(path, max_cells = 1000000L) {
  entries <- utils::unzip(path, list = TRUE)
  if (!nrow(entries) || anyDuplicated(entries$Name) || sum(entries$Length) > 500 * 1024^2) stop("Invalid, duplicate, or oversized ZIP members")
  format <- tolower(tools::file_ext(path))
  result <- switch(format, xlsx = read_xlsx(path, entries, max_cells), ods = read_ods(path, entries, max_cells), stop("Only .xlsx and .ods are supported"))
  names <- vapply(result$sheets, `[[`, character(1), "name")
  if (!length(names) || anyNA(names) || anyDuplicated(names)) stop("Missing or duplicate worksheet names")
  result
}
