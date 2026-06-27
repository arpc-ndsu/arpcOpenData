# Conventions & schema

This file is the authoritative reference for how everything in `arpcData` is named and
structured. If a rule here conflicts with a file in the repo, the file is wrong.

## Publication identifier

```
data-arpc-<TYPE>-<YYYY><##>
```

| Part      | Meaning                          | Allowed values                                   |
|-----------|----------------------------------|--------------------------------------------------|
| `<TYPE>`  | Publication type (lower, hyphen) | `white-paper`, `working-paper`, `report`, `brief`|
| `<YYYY>`  | Publication year                 | 4 digits                                         |
| `<##>`    | Issue number within type+year    | zero-padded, `01`, `02`, …                       |

The identifier is used **identically** as: the bundle folder, the ZIP archive, and the
GitHub Release tag.

## File names inside a bundle

```
arpc-<TYPE>-<YYYY><##>-<element><###>.<ext>
```

| Part         | Meaning                              |
|--------------|--------------------------------------|
| `<element>`  | `figure` or `table`                  |
| `<###>`      | element number as printed in the pub |
| `<ext>`      | `csv` (data), `png` (figure image)   |

- A figure's data CSV and its image share one stem: `…-figure001.csv` + `…-figure001.png`.
- Tables are CSV-only.
- Each data CSV has a matching codebook: `…-figure001.dictionary.csv` / `…-table001.dictionary.csv`.
- The publication PDF is `arpc-<TYPE>-<YYYY><##>.pdf`.

> Note the prefix difference: **files** start with `arpc-…`, the **bundle/ID/ZIP/tag**
> starts with `data-arpc-…`.

## Reserved files in every bundle

| File             | Purpose                                                        |
|------------------|----------------------------------------------------------------|
| `README.md`      | Exhibit map for the reader (generated from the manifest)        |
| `_manifest.json` | File list, row/col counts, sha256 checksums, source, build date |

## Dictionary (codebook) columns

`column, type, units, description, allowed_values`

## CSV format

UTF-8, comma-separated, header row, RFC-4180 quoting (written with `data.table::fwrite`).
