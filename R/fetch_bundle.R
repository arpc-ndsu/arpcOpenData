# =============================================================================
# fetch_bundle.R
# -----------------------------------------------------------------------------
# Data-USER side of arpcOpenData: download, cache, extract, and verify a
# published data bundle from its GitHub Release. (The team/build side lives in
# R/export_public_data.R.)
#
# A bundle is distributed as data-arpc-<TYPE>-<YYYY><##>.zip, attached to the
# Release whose tag is the publication TYPE (report, brief, working-paper,
# white-paper). fetch_bundle() resolves that URL, caches the ZIP, extracts it,
# and checks every file against the bundle's _manifest.json checksums.
# =============================================================================

# Build the public download URL for a bundle ZIP (one release per type).
#' @noRd
.bundle_url <- function(id, repo) {
  type <- sub("^data-arpc-(.*)-\\d{6}$", "\\1", id)
  stopifnot(type %in% VALID_TYPES)
  sprintf("https://github.com/%s/releases/download/%s/%s.zip", repo, type, id)
}

# Verify extracted files against the bundle's _manifest.json checksums.
#' @noRd
.verify_bundle <- function(dir) {
  mf <- file.path(dir, "_manifest.json")
  if (!file.exists(mf)) return(invisible(TRUE))
  m <- jsonlite::read_json(mf)
  bad <- character(0)
  for (f in m$files) {
    p <- file.path(dir, f$name)
    if (!file.exists(p) || digest::digest(p, algo = "sha256", file = TRUE) != f$sha256)
      bad <- c(bad, f$name)
  }
  if (length(bad))
    warning("Checksum/verify failed for: ", paste(bad, collapse = ", "))
  invisible(length(bad) == 0)
}

#' Download and extract a published data bundle, with on-disk caching.
#'
#' Fetches `data-arpc-<TYPE>-<YYYY><##>.zip` from its publication-type GitHub
#' Release and unpacks it locally. The ZIP is cached, so repeat calls do not
#' re-download unless `force = TRUE`; likewise an already-extracted bundle is not
#' re-unzipped. By default the extracted files are verified against the bundle's
#' `_manifest.json` sha256 checksums.
#'
#' @param id        Bundle ID, e.g. `"data-arpc-report-202601"`.
#' @param dest      Directory to extract into. Defaults to the cache directory.
#' @param repo      GitHub "owner/name" hosting the releases.
#' @param cache_dir Directory for cached ZIPs (persists across sessions).
#' @param force     If TRUE, re-download and re-extract even if cached.
#' @param verify    If TRUE (default), check extracted files against the manifest.
#' @return Path to the extracted bundle directory (invisibly).
#' @examples
#' \dontrun{
#'   dir <- fetch_bundle("data-arpc-report-202601")
#'   list.files(dir)
#'   df <- read.csv(file.path(dir, "arpc-report-202601-figure001.csv"))
#' }
#' @importFrom utils download.file unzip
#' @importFrom jsonlite read_json
#' @importFrom digest digest
#' @export
fetch_bundle <- function(id, dest = NULL, repo = "arpc-ndsu/arpcOpenData",
                         cache_dir = tools::R_user_dir("arpcOpenData", "cache"),
                         force = FALSE, verify = TRUE) {
  stopifnot(grepl("^data-arpc-.+-\\d{6}$", id))
  url <- .bundle_url(id, repo)

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  zip_path <- file.path(cache_dir, paste0(id, ".zip"))
  if (force || !file.exists(zip_path) || file.size(zip_path) == 0) {
    message("Downloading ", id, " ...")
    utils::download.file(url, zip_path, mode = "wb", quiet = TRUE)
  } else {
    message("Using cached ", basename(zip_path))
  }

  root <- if (is.null(dest)) cache_dir else dest
  out  <- file.path(root, id)
  if (force || !dir.exists(out) || length(list.files(out)) == 0) {
    dir.create(root, recursive = TRUE, showWarnings = FALSE)
    utils::unzip(zip_path, exdir = root)        # ZIP contains a top-level <id>/ folder
  }
  if (verify) .verify_bundle(out)
  message("Bundle ready at ", out)
  invisible(out)
}

#' Read one exhibit's data from a bundle (downloading it first if needed).
#'
#' Convenience wrapper around `fetch_bundle()` that returns the CSV behind a
#' single figure or table as a data frame.
#'
#' @param id      Bundle ID, e.g. `"data-arpc-report-202601"`.
#' @param exhibit Exhibit file stem or kind+number, e.g. `"figure001"`,
#'                `"table002"`, or a full file name `"...-figure001.csv"`.
#' @param ...     Passed to `fetch_bundle()` (e.g. `repo`, `cache_dir`, `force`).
#' @return A data frame of the exhibit's data.
#' @examples
#' \dontrun{
#'   fig1 <- read_exhibit("data-arpc-report-202601", "figure001")
#' }
#' @importFrom utils read.csv
#' @export
read_exhibit <- function(id, exhibit, ...) {
  dir  <- fetch_bundle(id, ...)
  stem <- sub("^data-(arpc-.*)$", "\\1", id)            # data-arpc-report-202601 -> arpc-report-202601
  file <- if (grepl("\\.csv$", exhibit)) exhibit else sprintf("%s-%s.csv", stem, exhibit)
  path <- file.path(dir, file)
  if (!file.exists(path))
    stop("Exhibit not found: ", file, ". Available: ",
         paste(list.files(dir, pattern = "\\.csv$"), collapse = ", "))
  utils::read.csv(path, check.names = FALSE)
}
