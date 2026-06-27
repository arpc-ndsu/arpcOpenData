# =============================================================================
# export_public_data.R
# -----------------------------------------------------------------------------
# Build a public data bundle for an ARPC publication and (optionally) release it.
#
# A bundle is the canonical unit published by this repository. Its ID is:
#     data-arpc-<TYPE>-<YYYY><##>        e.g. data-arpc-report-202601
# and every file inside it is named:
#     arpc-<TYPE>-<YYYY><##>-<element><###>.<ext>
#
# This script turns the artifacts a publication already produces (figure data,
# figure images, the PDF, and table data) into:
#   - one CSV per figure/table  (+ a *.dictionary.csv codebook each)
#   - the figure PNGs            (same stem as their data CSV)
#   - the publication PDF
#   - _manifest.json             (inventory + sha256 checksums)
#   - README.md                  (exhibit map, generated from the manifest)
# then zips the folder and can push it to GitHub Releases via piggyback.
#
# Dependencies: data.table, jsonlite, digest  (piggyback only for releasing).
# See data-raw/scripts/build-data-arpc-report-202601.R for a complete worked call.
# =============================================================================

# All package calls are namespace-qualified (data.table::, jsonlite::, digest::),
# so no library() attach is needed; imports are declared via roxygen @importFrom.

VALID_TYPES <- c("white-paper", "working-paper", "report", "brief")

# ---- helpers ----------------------------------------------------------------

.bundle_id  <- function(type, year, issue) sprintf("data-arpc-%s-%d%02d", type, year, as.integer(issue))
.file_stem  <- function(type, year, issue) sprintf("arpc-%s-%d%02d", type, year, as.integer(issue))
.sha256     <- function(path) digest::digest(path, algo = "sha256", file = TRUE)

# Column descriptions the team can extend; unknown columns are written with a
# `TODO` description so review catches them.
.DEFAULT_DICT <- list(
  commodity_year  = c("integer", "year", "Crop (commodity) year"),
  commodity_group = c("string",  "",     "RMA commodity group"),
  commodity       = c("string",  "",     "RMA commodity group"),
  rank            = c("integer", "",     "Within-group rank by liability (1 = largest)"),
  variable        = c("string",  "",     "Measure shown on the chart"),
  value           = c("numeric", "varies","Value of the measure (units stated in the variable label)")
)

#' Write a CSV + its dictionary for one data.frame, return file metadata.
#' @noRd
.write_dataset <- function(df, base, out_dir, dict_overrides = list()) {
  df <- as.data.frame(df)
  csv_path  <- file.path(out_dir, paste0(base, ".csv"))
  dict_path <- file.path(out_dir, paste0(base, ".dictionary.csv"))
  data.table::fwrite(df, csv_path)                       # UTF-8, RFC-4180

  dict <- modifyList(.DEFAULT_DICT, dict_overrides)
  rows <- lapply(names(df), function(cn) {
    meta <- dict[[cn]] %||% c("string", "", "TODO")
    allowed <- ""
    if (is.character(df[[cn]]) || is.factor(df[[cn]])) {
      lv <- sort(unique(as.character(df[[cn]])))
      if (length(lv) <= 30) allowed <- paste(lv, collapse = "; ")
    }
    data.frame(column = cn, type = meta[1], units = meta[2],
               description = meta[3], allowed_values = allowed,
               stringsAsFactors = FALSE)
  })
  data.table::fwrite(data.table::rbindlist(rows), dict_path)
  list(csv = basename(csv_path), dict = basename(dict_path),
       rows = nrow(df), cols = ncol(df))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- table helper: parse a LaTeX tabular into a tidy data.frame -------------
# Tables in ARPC reports live in .tex. Cells of the form "12.3 (4.5)" are split
# into nominal and real columns. Adjust `periods` to match the table header.
#' Parse a LaTeX tabular into a tidy nominal/real data.frame.
#' @param tex_path Path to a .tex file containing one tabular.
#' @param periods  Character vector of column labels (one per data column).
#' @importFrom data.table rbindlist
#' @export
parse_latex_table <- function(tex_path, periods) {
  txt  <- paste(readLines(tex_path, warn = FALSE), collapse = "\n")
  body <- sub(".*\\\\midrule", "", txt)
  body <- sub("\\\\bottomrule.*", "", body)
  out  <- list()
  for (line in strsplit(body, "\\\\\\\\")[[1]]) {
    line <- trimws(gsub("\\\\addlinespace\\[[^]]*\\]", "", line))
    if (!nzchar(line) || !grepl("&", line)) next
    cells  <- trimws(strsplit(line, "&")[[1]])
    metric <- gsub("\\\\\\$", "$", cells[1])
    for (j in seq_along(periods)) {
      raw <- if (j + 1 <= length(cells)) gsub("\\\\\\$", "$", trimws(cells[j + 1])) else ""
      m   <- regmatches(raw, regexec("^(-?[0-9.]+|NA)\\s*(?:\\((-?[0-9.]+)\\))?$", raw))[[1]]
      if (length(m) == 3) {
        nom  <- if (m[2] == "NA") NA else as.numeric(m[2])
        real <- if (nzchar(m[3])) as.numeric(m[3]) else NA
      } else { nom <- raw; real <- NA }
      out[[length(out) + 1]] <- data.frame(metric = metric, period = periods[j],
        value_nominal = nom, value_real_2025 = real, stringsAsFactors = FALSE)
    }
  }
  data.table::rbindlist(out)
}

# ---- main: build one bundle -------------------------------------------------
#' Build a public data bundle for one ARPC publication.
#'
#' Assembles a publication's exhibits into a self-contained, citable bundle
#' (`data-arpc-<TYPE>-<YYYY><##>`): one CSV per figure/table with a codebook each,
#' the figure PNGs, the publication PDF, a checksummed `_manifest.json`, and an
#' exhibit-map `README.md`. Files are written under `out_root/<TYPE>/<ID>/`.
#'
#' @param type,year,issue  Publication coordinates (type in VALID_TYPES).
#' @param title            Human-readable publication title.
#' @param pdf              Path to the final publication PDF.
#' @param exhibits         Ordered list of exhibits. Each is a list with:
#'                           kind        = "figure" or "table"
#'                           data        = a data.frame (or path to .rds)
#'                           image       = path to PNG          (figures only)
#'                           description = one-line exhibit description
#'                           dict        = optional named list of column overrides
#' @param out_root         Staging directory for built bundles.
#' @param meta             Named list merged into the manifest (source_repo,
#'                           source_commit, publication_date, program_area, ...).
#' @importFrom data.table fwrite rbindlist
#' @importFrom jsonlite write_json
#' @importFrom digest digest
#' @export
build_bundle <- function(type, year, issue, title, pdf, exhibits,
                         out_root = file.path("data-raw", "published-data"), meta = list()) {
  stopifnot(type %in% VALID_TYPES)
  id   <- .bundle_id(type, year, issue)
  stem <- .file_stem(type, year, issue)
  out  <- file.path(out_root, type, id)
  dir.create(out, recursive = TRUE, showWarnings = FALSE)

  files <- list()
  exmap <- list()

  # publication PDF
  pdf_dst <- file.path(out, paste0(stem, ".pdf"))
  file.copy(pdf, pdf_dst, overwrite = TRUE)
  files[[length(files) + 1]] <- list(name = basename(pdf_dst), kind = "publication",
                                      sha256 = .sha256(pdf_dst))

  fig_n <- tab_n <- 0L
  for (ex in exhibits) {
    df <- if (is.character(ex$data)) readRDS(ex$data) else ex$data
    if (identical(ex$kind, "figure")) {
      fig_n <- fig_n + 1L
      base  <- sprintf("%s-figure%03d", stem, fig_n)
      ds <- .write_dataset(df, base, out, ex$dict %||% list())
      img <- NA_character_
      if (!is.null(ex$image)) {
        img_dst <- file.path(out, paste0(base, ".png"))
        file.copy(ex$image, img_dst, overwrite = TRUE)
        img <- basename(img_dst)
        files[[length(files) + 1]] <- list(name = img, kind = "figure-image",
          exhibit = sprintf("Figure %d", fig_n), sha256 = .sha256(img_dst))
      }
      files[[length(files) + 1]] <- list(name = ds$csv, kind = "figure-data",
        exhibit = sprintf("Figure %d", fig_n), rows = ds$rows, cols = ds$cols,
        dictionary = ds$dict, image = img, sha256 = .sha256(file.path(out, ds$csv)))
      exmap[[length(exmap) + 1]] <- c(sprintf("Figure %d", fig_n), ds$csv,
                                       if (is.na(img)) "-" else img, ex$description)
    } else {
      tab_n <- tab_n + 1L
      base  <- sprintf("%s-table%03d", stem, tab_n)
      ds <- .write_dataset(df, base, out, ex$dict %||% list())
      files[[length(files) + 1]] <- list(name = ds$csv, kind = "table-data",
        exhibit = sprintf("Table %d", tab_n), rows = ds$rows, cols = ds$cols,
        dictionary = ds$dict, sha256 = .sha256(file.path(out, ds$csv)))
      exmap[[length(exmap) + 1]] <- c(sprintf("Table %d", tab_n), ds$csv, "-", ex$description)
    }
  }

  # manifest
  manifest <- c(list(id = id, type = type, year = year, issue = sprintf("%02d", as.integer(issue)),
                     title = title, license = "CC-BY-4.0",
                     built_at = format(as.POSIXlt(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")),
                meta, list(files = files))
  jsonlite::write_json(manifest, file.path(out, "_manifest.json"),
                       pretty = TRUE, auto_unbox = TRUE, null = "null")

  # README exhibit map
  .write_readme(out, id, title, stem, exmap, meta)

  message("Built ", id, " -> ", out, "  (", length(files), " files)")
  invisible(out)
}

.write_readme <- function(out, id, title, stem, exmap, meta) {
  hdr <- c(
    sprintf("# Data for: %s", title), "",
    sprintf("**Bundle ID:** `%s`", id),
    sprintf("**Type:** %s . **Published:** %s", meta$type %||% "", meta$publication_date %||% ""),
    sprintf("**Full publication:** `%s.pdf` (included)", stem), "",
    "This archive contains the underlying data and figure images for every exhibit in the",
    "publication above. Each data CSV has a companion `*.dictionary.csv` codebook.", "",
    "## Exhibit map", "",
    "| Exhibit | Data file | Image | What it shows |",
    "|---------|-----------|-------|----------------|")
  rows <- vapply(exmap, function(r) sprintf("| %s | `%s` | %s | %s |",
                 r[1], r[2], if (is.na(r[3]) || r[3] == "-") "-" else paste0("`", r[3], "`"), r[4]), character(1))
  yr <- substr(meta$publication_date %||% "", 1, 4)
  ftr <- c("", "## Verify", "",
    "Each file's sha256 checksum is in `_manifest.json`; recompute and compare to confirm",
    "your download is intact.", "",
    "## License & citation", "",
    "Data and figures are released under **CC BY 4.0**. Please cite **both** the",
    "underlying publication and this data bundle:", "",
    sprintf("> **Publication:** ARPC (%s). *%s.* %s.", yr, title, meta$type %||% "ARPC publication"),
    ">",
    sprintf("> **Data:** ARPC (%s). *Data for %s* [data set]. Bundle `%s`.", yr, title, id))
  writeLines(c(hdr, rows, ftr), file.path(out, "README.md"))
}

# ---- release: zip + upload to GitHub Releases -------------------------------
# Distribution model: ONE GitHub Release per publication type. Each type's
# release (tag = the type, e.g. "report") lists every issue's ZIP as an asset:
#   release "report"  ->  data-arpc-report-202601.zip, data-arpc-report-202602.zip, ...
#' Zip a built bundle and (optionally) upload it to its publication-type Release.
#'
#' The ZIP is built in `tempdir()` (not next to the bundle) so it never collides
#' with a cloud-synced/locked file and is never committed. Upload targets the
#' release tagged with the publication TYPE; the asset is overwritten if it
#' already exists.
#'
#' @param bundle_dir Path to a built bundle folder (named data-arpc-<type>-<YYYY><##>).
#' @param repo       "owner/name" on GitHub. Requires `piggyback` + a token.
#' @param upload     If TRUE, create the type's release if missing and upload the ZIP.
#' @param .token     GitHub token with write access. Defaults to the
#'                   `ARPC_ADMIN_TOKEN` env var, falling back to the gh credential.
#' @export
release_bundle <- function(bundle_dir, repo = NULL, upload = FALSE,
                           .token = Sys.getenv("ARPC_ADMIN_TOKEN")) {
  if (!nzchar(.token) && requireNamespace("gh", quietly = TRUE)) .token <- gh::gh_token()
  bundle_dir <- normalizePath(bundle_dir, mustWork = TRUE)
  id   <- basename(bundle_dir)                          # data-arpc-<type>-<YYYY><##>
  type <- sub("^data-arpc-(.*)-\\d{6}$", "\\1", id)     # -> report / brief / ...
  stopifnot(type %in% VALID_TYPES)

  # Build the ZIP in tempdir() to avoid sync locks ("device busy") and stray files.
  zip_out <- file.path(tempdir(), paste0(id, ".zip"))
  if (file.exists(zip_out)) unlink(zip_out)
  old <- setwd(dirname(bundle_dir)); on.exit(setwd(old))
  utils::zip(zipfile = zip_out, files = id, flags = "-r9Xq")
  message("Zipped -> ", zip_out)

  if (upload) {
    if (!requireNamespace("piggyback", quietly = TRUE))
      stop("Install 'piggyback' to upload releases.")
    have <- tryCatch(type %in% piggyback::pb_releases(repo = repo, .token = .token)$tag_name,
                     error = function(e) FALSE)
    if (!isTRUE(have))
      piggyback::pb_release_create(repo = repo, tag = type,
        name = sprintf("ARPC %s data", type), .token = .token)
    piggyback::pb_upload(file = zip_out, repo = repo, tag = type,
                         overwrite = TRUE, .token = .token)
    message("Uploaded ", id, ".zip to ", repo, " @ release '", type, "'")
  }
  invisible(zip_out)
}

# Data-USER helpers (download / extract / read a bundle) live in R/fetch_bundle.R.