# =============================================================================
# Worked example: build data-arpc-report-202601 (FCIP Portfolio Size and Growth)
# -----------------------------------------------------------------------------
# Run from the repo root after editing `src` to point at the report's artifacts.
#   source("data-raw/scripts/build-data-arpc-report-202601.R")
# It reproduces the bundle in data-raw/published-data/report/data-arpc-report-202601/.
# =============================================================================

devtools::document()

if (requireNamespace("gh", quietly = TRUE)) try(gh::gh_whoami(), silent = TRUE)

# Where the publication's artifacts live (figure *_data.rds, *.png, the PDF, table .tex).
src <- file.path("..", "..", "fastscratch", "arpc-report-fcip-portfolio-size-and-growth")
raw <- file.path(src, "visuals", "raw_visuals")
vis <- file.path(src, "visuals")

# ---- figures: (raw slug, one-line description) in publication order ----------
fig <- list(
  c("figure01_fcip_by_commodity_group", "Liability and net acres insured by commodity type"),
  c("figure02_fcip_by_Field_Crops",     "Liability and net acres insured for field crops"),
  c("figure03_fcip_by_Fruit_trees",     "Liability for fruit trees"),
  c("figure04_fcip_by_Fruits",          "Liability and net acres insured for fruit production"),
  c("figure05_fcip_by_Nut_trees",       "Liability for nut trees"),
  c("figure06_fcip_by_Nuts",            "Liability and net acres insured for nuts production"),
  c("figure07_fcip_by_Vegetables",      "Liability and net acres insured for vegetable production"),
  c("figure08_fcip_by_Nurseries",       "Liability (US$) for nurseries"),
  c("figure09_fcip_by_Forage_Crops",    "Liability and net acres insured for forage, range, and pasture")
)
fig_exhibits <- lapply(fig, function(x) list(
  kind = "figure",
  data = file.path(raw, paste0(x[1], "_data.rds")),
  image = file.path(raw, paste0(x[1], ".png")),
  description = x[2]
))

# ---- tables: parsed from the report's LaTeX tabulars -------------------------
periods <- c("2008-2013", "2014-2017", "2018-2025", "2024", "2025")
tab_dict <- list(
  metric          = c("string",  "",                 "Book-of-business measure"),
  period          = c("string",  "",                 "Crop-year average window or single year"),
  value_nominal   = c("numeric", "millions/billions/%","Nominal value (or growth %)"),
  value_real_2025 = c("numeric", "millions/billions/%","Value/growth in real 2025 US$ (blank if N/A)")
)
table_exhibits <- list(
  list(kind = "table", data = parse_latex_table(file.path(vis, "fcip_book_table01.tex"), periods),
       description = "Book of business: net acres, policies, units, and dollar values", dict = tab_dict),
  list(kind = "table", data = parse_latex_table(file.path(vis, "fcip_book_table02.tex"), periods),
       description = "Book of business growth (percent)", dict = tab_dict)
)

# ---- build (tables first, then figures, matching the report order) ----------
build_bundle(
  type = "report", year = 2026L, issue = 1L,
  title = "FCIP Portfolio Size and Growth",
  pdf   = file.path(src, "arpc-report-fcip-portfolio-size-and-growth-2025.pdf"),
  exhibits = c(table_exhibits, fig_exhibits),
  out_root = file.path("data-raw", "published-data"),
  meta = list(
    publication_date = "2026-06-02",
    program_area     = "fcip",
    type             = "ARPC Report",
    source_repo      = "arpcFCIPHarness",
    source_commit    = "<git-sha>",
    source_publication_file = "arpc-report-fcip-portfolio-size-and-growth-2025.pdf"
  )
)

# ---- release (uncomment to zip; set upload = TRUE to push to GitHub) ---------
# Uploads to the single "report" release, alongside every other report ZIP.
release_bundle("data-raw/published-data/report/data-arpc-report-202601",
               repo = "arpc-ndsu/arpcOpenData", upload = TRUE)

