# =============================================================================
# initialize_release_pages.R
# -----------------------------------------------------------------------------
# Create (or refresh) ONE GitHub Release per ARPC publication type. Each type's
# release uses the rendered body authored in:
#     data-raw/scripts/<type>/release-body.Rmd
# and accumulates that type's bundle ZIPs as assets:
#     release "report" -> data-arpc-report-202601.zip, data-arpc-report-202602.zip, ...
#
# Run from the repo root:
#     source("data-raw/scripts/initialize_release_pages.R")
#
# Requires: piggyback (+ a GITHUB_PAT with repo scope), rmarkdown, knitr.
# Updating an existing release body uses the `gh` CLI if available.
# =============================================================================

repo        <- "arpc-ndsu/arpcOpenData"
types       <- c("report", "brief", "working-paper", "white-paper")
scripts_dir <- file.path("data-raw", "scripts")
catalog     <- file.path("data-raw", "metadata", "publications.csv")

stopifnot(requireNamespace("rmarkdown", quietly = TRUE),
          requireNamespace("piggyback", quietly = TRUE))

# Render a type's release-body.Rmd to a markdown string.
render_body <- function(type) {
  rmd <- file.path(scripts_dir, type, "release-body.Rmd")
  if (!file.exists(rmd)) stop("Missing release body: ", rmd)
  out <- tempfile(fileext = ".md")
  rmarkdown::render(
    rmd, output_file = out, quiet = TRUE,
    params = list(type = type, repo = repo, catalog = catalog)
  )
  paste(readLines(out, warn = FALSE), collapse = "\n")
}

# Update an existing release's body via the GitHub REST API (gh CLI).
update_release_body <- function(repo, release_id, body_md) {
  if (Sys.which("gh") == "") {
    warning("`gh` CLI not found; cannot update body for release id ", release_id,
            ". Edit it on GitHub or install gh.")
    return(invisible(FALSE))
  }
  tmp <- tempfile(); writeLines(body_md, tmp)
  system2("gh", c("api", "-X", "PATCH",
                  sprintf("repos/%s/releases/%s", repo, release_id),
                  "-F", paste0("body=@", tmp)), stdout = FALSE)
  invisible(TRUE)
}

# Create the release if missing (with body), else refresh its body.
ensure_release <- function(type) {
  body_md <- render_body(type)
  rels    <- tryCatch(piggyback::pb_releases(repo = repo), error = function(e) NULL)
  if (is.null(rels) || !(type %in% rels$tag_name)) {
    piggyback::pb_release_create(
      repo = repo, tag = type,
      name = sprintf("ARPC %s — Underlying Data",
                     tools::toTitleCase(gsub("-", " ", type))),
      body = body_md)
    message("Created release '", type, "'")
  } else {
    rid <- rels$id[rels$tag_name == type][1]
    update_release_body(repo, rid, body_md)
    message("Refreshed body for release '", type, "'")
  }
}

invisible(lapply(types, ensure_release))
message("Done. Upload bundle ZIPs with release_bundle(..., upload = TRUE).")
