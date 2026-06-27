# When the package is installed or loaded via devtools::load_all(), the functions
# under test already live in the namespace. When running the tests by sourcing
# (package not loaded), fall back to sourcing all R/ source files directly.
if (!exists("build_bundle", mode = "function") ||
    !exists("fetch_bundle", mode = "function")) {
  r_dir <- if (dir.exists(file.path("..", "..", "R"))) file.path("..", "..", "R") else "R"
  for (f in list.files(r_dir, pattern = "\\.R$", full.names = TRUE)) {
    sys.source(f, envir = globalenv())
  }
}
