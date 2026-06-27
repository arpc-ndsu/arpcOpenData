# =============================================================================
# initialize_release_pages.R
# -----------------------------------------------------------------------------
# (Re)create ONE GitHub Release PAGE per ARPC publication type. Each type's
# release body is authored in:
#     data-raw/scripts/release-body/release-body-<type>.Rmd
# and rendered to markdown here. Bundle ZIPs are attached later, per publication,
# via release_bundle(..., upload = TRUE) -- this script uploads NO assets.
#
# Run from the repo root:
#     source("data-raw/scripts/initialize_release_pages.R")
#
# Requires: piggyback + rmarkdown (+ a GitHub token with write access to the repo).
#
# WARNING: this DELETES and recreates each release, which drops any assets already
# attached to it. Use it to initialize / refresh the release PAGES (bodies) only,
# before bundle ZIPs are uploaded -- not as a routine body-only update afterwards.
# =============================================================================

devtools::document()

# Verify auth first (nice sanity check)
if (requireNamespace("gh", quietly = TRUE)) try(gh::gh_whoami(), silent = TRUE)

stopifnot(requireNamespace("rmarkdown", quietly = TRUE),
          requireNamespace("piggyback", quietly = TRUE))

# Org-admin token with Contents: write on arpc-ndsu/arpcOpenData. Passing it explicitly
# avoids piggyback/gh falling back to a weaker token and 403-ing on the org repo.
# Falls back to the default gh credential if ARPC_ADMIN_TOKEN isn't set.
gh_token <- Sys.getenv("ARPC_ADMIN_TOKEN")
if (!nzchar(gh_token)) gh_token <- gh::gh_token()
stopifnot(nzchar(gh_token))

repo        <- "arpc-ndsu/arpcOpenData"
types       <- c("report", "brief", "working-paper", "white-paper")
scripts_dir <- file.path("data-raw", "scripts")
catalog     <- file.path("data-raw", "metadata", "publications.csv")

# Render a type's release body (.Rmd) to a markdown string.
render_body <- function(type) {
  rmd <- file.path(scripts_dir, "release-body", paste0("release-body-", type, ".Rmd"))
  if (!file.exists(rmd)) stop("Missing release body: ", rmd)
  out <- tempfile(fileext = ".md")
  rmarkdown::render(
    rmd, output_file = out, quiet = TRUE,
    knit_root_dir = getwd(),               # resolve catalog path from the repo root
    params = list(type = type, repo = repo, catalog = catalog)
  )
  paste(readLines(out, warn = FALSE), collapse = "\n")
}

# Release-page bodies, keyed by tag (= publication type).
body_list <- setNames(lapply(types, render_body), types)

# (Re)create one release page per type. No assets are uploaded here.
for (i in types) {
  # tryCatch(
  #   piggyback::pb_release_delete(repo = repo, tag = i, .token = gh_token),
  #   error = function(e) NULL
  # )
  piggyback::pb_release_create(
    repo = repo,
    tag  = i,
    name = sprintf("ARPC %s - Underlying Data", tools::toTitleCase(gsub("-", " ", i))),
    body = body_list[[i]],
    .token = gh_token
  )
  message("Release page ready: ", i)
}





