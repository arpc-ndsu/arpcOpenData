# ARPC Working Paper — Underlying Data

This release holds the **open data and figures behind every ARPC Working
Paper**. Each publication is distributed as a single ZIP archive named
`data-arpc-working-paper-YYYY##.zip` (year + issue number), containing:

-   the publication **PDF**;
-   one **CSV per figure and table** (the exact exhibit data);
-   the **figure images** (PNG), sharing a name stem with their data
    CSV;
-   a `*.dictionary.csv` **codebook** for every dataset;
-   a `README.md` **exhibit map** and a checksummed `_manifest.json`.

All data are UTF-8 CSVs with a header row. Open them in Excel, R,
Python, or any text editor.

<!-- ## Available bundles -->
<!-- ```{r bundles, results='asis'} -->
<!-- if (nrow(pubs)) { -->
<!--   pubs[, Download := sprintf("[`%s.zip`](https://github.com/%s/releases/download/%s/%s.zip)", -->
<!--                              id, repo, type, id)] -->
<!--   print(knitr::kable( -->
<!--     pubs[, .(Bundle = id, Title = title, Published = publication_date, Download)], -->
<!--     format = "markdown")) -->
<!-- } else { -->
<!--   cat("_No bundles published yet._") -->
<!-- } -->
<!-- ``` -->

## How to use

Download a bundle’s ZIP, unzip it, and start with its `README.md`: it
maps each figure and table in the PDF to the file(s) behind it. Verify
integrity against the sha256 checksums in `_manifest.json`.

## License & citation

Data and figures are released under **CC BY 4.0**. Cite the publication,
then the bundle ID, e.g. `data-arpc-report-202601`.
