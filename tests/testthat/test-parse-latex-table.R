test_that("parse_latex_table splits nominal/real cells and handles NA", {
  tex <- tempfile(fileext = ".tex")
  writeLines(c(
    "\\begin{tabular}{lcc}",
    "\\toprule",
    "Header & 2024 & 2025 \\\\",
    "\\midrule",
    "Liability (\\$) & 12.5 (10.0) & 3.0 \\\\",
    "Endorsed Acres & NA & 4.0 (5.0) \\\\",
    "\\bottomrule",
    "\\end{tabular}"
  ), tex)

  df <- parse_latex_table(tex, periods = c("2024", "2025"))

  expect_equal(nrow(df), 4L)
  expect_equal(names(df), c("metric", "period", "value_nominal", "value_real_2025"))

  lia24 <- df[df$metric == "Liability ($)" & df$period == "2024", ]
  expect_equal(lia24$value_nominal, 12.5)
  expect_equal(lia24$value_real_2025, 10.0)

  lia25 <- df[df$metric == "Liability ($)" & df$period == "2025", ]
  expect_equal(lia25$value_nominal, 3.0)
  expect_true(is.na(lia25$value_real_2025))

  end24 <- df[df$metric == "Endorsed Acres" & df$period == "2024", ]
  expect_true(is.na(end24$value_nominal))
})
