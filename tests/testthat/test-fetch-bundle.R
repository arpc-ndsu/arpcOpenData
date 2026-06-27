test_that("bundle download URL points at the type's release", {
  expect_equal(
    .bundle_url("data-arpc-report-202601", "arpc-ndsu/arpcOpenData"),
    "https://github.com/arpc-ndsu/arpcOpenData/releases/download/report/data-arpc-report-202601.zip"
  )
  expect_equal(
    .bundle_url("data-arpc-working-paper-202403", "arpc-ndsu/arpcOpenData"),
    "https://github.com/arpc-ndsu/arpcOpenData/releases/download/working-paper/data-arpc-working-paper-202403.zip"
  )
  expect_error(.bundle_url("data-arpc-memo-202601", "arpc-ndsu/arpcOpenData"))
})

test_that("fetch_bundle validates the bundle id", {
  expect_error(fetch_bundle("not-a-bundle"), "data-arpc")
})

test_that("fetch_bundle uses the cache (no re-download, no network)", {
  # Simulate a cached bundle: pre-place a ZIP so download is skipped, and a
  # pre-extracted folder so unzip is skipped. fetch_bundle should just verify.
  cache <- file.path(tempdir(), paste0("cache-", as.integer(runif(1, 1, 1e9))))
  id    <- "data-arpc-report-202601"
  dir.create(file.path(cache, id), recursive = TRUE)
  writeBin(as.raw(c(0x50, 0x4b)), file.path(cache, paste0(id, ".zip")))  # non-empty
  writeLines("x", file.path(cache, id, "placeholder.txt"))               # non-empty dir

  out <- fetch_bundle(id, cache_dir = cache, verify = FALSE)
  expect_equal(normalizePath(out), normalizePath(file.path(cache, id)))
})

test_that("read_exhibit resolves the file name and reads the CSV", {
  cache <- file.path(tempdir(), paste0("cache-", as.integer(runif(1, 1, 1e9))))
  id    <- "data-arpc-report-202601"
  dir.create(file.path(cache, id), recursive = TRUE)
  writeBin(as.raw(c(0x50, 0x4b)), file.path(cache, paste0(id, ".zip")))
  # stage an exhibit CSV so fetch_bundle uses the cache (no download)
  write.csv(data.frame(year = 2024:2025, value = c(1, 2)),
            file.path(cache, id, "arpc-report-202601-figure001.csv"), row.names = FALSE)

  df <- read_exhibit(id, "figure001", cache_dir = cache, verify = FALSE)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 2L)
  expect_true(all(c("year", "value") %in% names(df)))

  expect_error(read_exhibit(id, "figure999", cache_dir = cache, verify = FALSE),
               "not found")
})
