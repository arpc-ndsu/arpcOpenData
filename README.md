
<!-- README.md is generated from README.Rmd. Please edit that file -->

# ARPC Open Data

<!-- badges: start -->

<a href="https://www.repostatus.org/#active"><img src="https://www.repostatus.org/badges/latest/active.svg"></a>
<a href="https://lifecycle.r-lib.org/articles/stages.html#experimental"><img src="https://img.shields.io/badge/lifecycle-experimental-orange.svg"></a>
<a href="https://github.com/arpc-ndsu/arpcOpenData/actions/workflows/R-CMD-check.yaml"><img src="https://github.com/arpc-ndsu/arpcOpenData/actions/workflows/R-CMD-check.yaml/badge.svg"></a>
<a href="https://codecov.io/gh/arpc-ndsu/arpcOpenData"><img src="https://codecov.io/gh/arpc-ndsu/arpcOpenData/graph/badge.svg?token=ZD6UDAD2VZ"></a>
<img src="https://img.shields.io/badge/R-%3E=4.1-blue">
<img src="https://img.shields.io/badge/License-CC%20BY%204.0-blue.svg">
<!-- badges: end -->

`arpcOpenData` is ARPC’s primary channel for releasing data to the
public. Its first and main contents are the **datasets and figures
behind ARPC publications** — for every report, brief, working paper, and
white paper, the exact data and figure images used to produce the
exhibits, so you can inspect, reuse, and reproduce the numbers yourself.
Other ARPC datasets are released here over time through the same
mechanism.

> Looking for the data behind a specific figure or table? Jump to [Find
> the data for a publication](#find-the-data-for-a-publication).

## What’s here

Each publication is packaged as a single self-contained **bundle**
identified by:

    data-arpc-<TYPE>-<YYYY><##>
       │        │      │     └ issue number within the year (01, 02, …)
       │        │      └ publication year
       │        └ report · brief · working-paper · white-paper
       └ every bundle starts with data-arpc-

Example: **`data-arpc-report-202601`** = the 1st ARPC Report of 2026.

A bundle contains the publication PDF, one CSV per figure and table, the
figure images (PNG), a codebook for every dataset, and a README that
maps each exhibit to its files.

## Find the data for a publication

All data is distributed through
[**Releases**](https://github.com/arpc-ndsu/arpcOpenData/releases).
There is **one release per publication type** — `report`, `brief`,
`working-paper`, and `white-paper` — and each release lists every issue
of that type as a downloadable ZIP.

1.  Open [Releases](https://github.com/arpc-ndsu/arpcOpenData/releases)
    and pick the release for your publication type (e.g. **report**).
2.  Download the bundle for the issue you want:
    `data-arpc-<TYPE>-<YYYY><##>.zip`
    (e.g. `data-arpc-report-202601.zip`). Each release page lists and
    describes all of its bundles.
3.  Unzip it: one download gives you the publication PDF plus every
    figure/table dataset, the figure images, codebooks, and an
    exhibit-map README.

## Inside a bundle

| File | What it is |
|----|----|
| `README.md` | Exhibit map: which file backs which figure/table |
| `arpc-<TYPE>-<YYYY><##>.pdf` | The full publication |
| `arpc-…-figure001.csv` + `.png` | Data behind a figure, and the figure image |
| `arpc-…-table001.csv` | Data behind a table |
| `*.dictionary.csv` | Codebook: every column explained |
| `_manifest.json` | File inventory + sha256 checksums |

Data and image for the same exhibit share a name stem, so
`…-figure001.csv` and `…-figure001.png` always belong together. All data
are UTF-8 CSVs with a header row.

## Using the data

The CSVs open in anything — Excel, R, Python, or a text editor. The
`_manifest.json` checksums let you confirm a download is intact. Start
with the bundle’s `README.md`: it tells you, exhibit by exhibit, exactly
which file to open.

### In R

The package ships a helper that downloads, caches, extracts, and
checksum-verifies a bundle for you:

``` r
# install.packages("remotes")
remotes::install_github("arpc-ndsu/arpcOpenData")

library(arpcOpenData)

# Download + extract (cached; repeat calls don't re-download)
dir <- fetch_bundle("data-arpc-report-202601")

# ...or read one exhibit straight into a data frame
fig1 <- read_exhibit("data-arpc-report-202601", "figure001")
```

## Citing

Cite the publication, then the data bundle ID and its download link,
e.g.:

> ARPC (2026). *<Publication title>.* Data bundle
> `data-arpc-report-202601`.
> <https://github.com/arpc-ndsu/arpcOpenData/releases/download/report/data-arpc-report-202601.zip>

See [`CITATION.cff`](CITATION.cff).

## License

Data and figures: **CC BY 4.0** — reuse freely with attribution. See
[`LICENSE`](LICENSE). Original data sources (e.g. USDA RMA/NASS) retain
their own terms; see each bundle’s README for source attribution.

## Naming convention

Every bundle ID is `data-arpc-<TYPE>-<YYYY><##>` (type · year · issue).
Inside it, each file is `arpc-<TYPE>-<YYYY><##>-<element><###>.<ext>`,
where `<element>` is `figure` or `table` — so a figure’s CSV and PNG
share a stem. A figure’s data and its image always match by name; tables
are CSV-only.
