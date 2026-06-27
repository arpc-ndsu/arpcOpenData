test_that("bundle IDs and file stems follow the spec", {
  expect_equal(.bundle_id("report", 2026, 1),       "data-arpc-report-202601")
  expect_equal(.bundle_id("brief", 2025, 12),       "data-arpc-brief-202512")
  expect_equal(.bundle_id("working-paper", 2024, 3),"data-arpc-working-paper-202403")
  expect_equal(.file_stem("report", 2026, 1),       "arpc-report-202601")
  expect_equal(.file_stem("white-paper", 2025, 9),  "arpc-white-paper-202509")
})

test_that("only the four publication types are valid", {
  expect_setequal(VALID_TYPES, c("white-paper", "working-paper", "report", "brief"))
  expect_error(
    build_bundle("memo", 2026, 1, "x", tempfile(), list()),
    "type"
  )
})
