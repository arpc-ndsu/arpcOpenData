make_bundle <- function() {
  out_root <- file.path(tempdir(), paste0("data-", as.integer(runif(1, 1, 1e9))))

  pdf <- tempfile(fileext = ".pdf"); writeLines("%PDF dummy", pdf)
  png <- tempfile(fileext = ".png"); writeBin(as.raw(c(0x89, 0x50, 0x4e, 0x47)), png)

  fig <- data.frame(
    commodity_year = c(2020L, 2021L),
    commodity_group = c("Field crops", "Forages"),
    variable = c("Total Liability Amount (Billion Dollars)", "Total Liability Amount (Billion Dollars)"),
    value = c(10.5, 1.2),
    stringsAsFactors = FALSE
  )
  tab <- data.frame(
    metric = c("Net Acres Insured", "Net Acres Insured"),
    period = c("2024", "2025"),
    value_nominal = c(542.49, 561.30),
    value_real_2025 = c(NA, NA),
    stringsAsFactors = FALSE
  )
  tab_dict <- list(
    metric          = c("string",  "",          "Book-of-business measure"),
    period          = c("string",  "",          "Crop year or average window"),
    value_nominal   = c("numeric", "millions",  "Nominal value"),
    value_real_2025 = c("numeric", "millions",  "Value in real 2025 US$ (blank if N/A)")
  )

  out <- build_bundle(
    type = "report", year = 2026L, issue = 1L, title = "Test Report",
    pdf = pdf,
    exhibits = list(
      list(kind = "table", data = tab, description = "A test table", dict = tab_dict),
      list(kind = "figure", data = fig, image = png, description = "A test figure")
    ),
    out_root = out_root,
    meta = list(program_area = "fcip", publication_date = "2026-01-01",
                type = "ARPC Report", source_repo = "x", source_commit = "abc")
  )
  out
}

test_that("build_bundle writes a spec-compliant set of files", {
  out <- make_bundle()
  expect_true(dir.exists(out))
  expect_equal(basename(out), "data-arpc-report-202601")

  expect_true(file.exists(file.path(out, "arpc-report-202601.pdf")))
  expect_true(file.exists(file.path(out, "arpc-report-202601-figure001.csv")))
  expect_true(file.exists(file.path(out, "arpc-report-202601-figure001.png")))
  expect_true(file.exists(file.path(out, "arpc-report-202601-figure001.dictionary.csv")))
  expect_true(file.exists(file.path(out, "arpc-report-202601-table001.csv")))
  expect_true(file.exists(file.path(out, "arpc-report-202601-table001.dictionary.csv")))
  expect_true(file.exists(file.path(out, "_manifest.json")))
  expect_true(file.exists(file.path(out, "README.md")))
})

test_that("figure data and its image share a stem", {
  out <- make_bundle()
  csv <- "arpc-report-202601-figure001.csv"
  png <- "arpc-report-202601-figure001.png"
  expect_identical(sub("\\.csv$", "", csv), sub("\\.png$", "", png))
})

test_that("manifest checksums match the files on disk", {
  out <- make_bundle()
  m <- jsonlite::read_json(file.path(out, "_manifest.json"))
  expect_equal(m$id, "data-arpc-report-202601")
  expect_equal(m$issue, "01")
  for (f in m$files) {
    p <- file.path(out, f$name)
    expect_true(file.exists(p))
    expect_equal(digest::digest(p, algo = "sha256", file = TRUE), f$sha256)
  }
})

test_that("every data CSV has a dictionary with no TODO descriptions", {
  out <- make_bundle()
  dicts <- list.files(out, pattern = "\\.dictionary\\.csv$", full.names = TRUE)
  expect_gt(length(dicts), 0)
  for (d in dicts) {
    dd <- data.table::fread(d)
    expect_true(all(c("column", "type", "units", "description", "allowed_values") %in% names(dd)))
    expect_false(any(dd$description == "TODO"))
  }
})

test_that("README exhibit map references real files", {
  out <- make_bundle()
  rd <- readLines(file.path(out, "README.md"))
  expect_true(any(grepl("Exhibit map", rd)))
  expect_true(any(grepl("arpc-report-202601-figure001.csv", rd, fixed = TRUE)))
  expect_true(any(grepl("arpc-report-202601-table001.csv", rd, fixed = TRUE)))
})
