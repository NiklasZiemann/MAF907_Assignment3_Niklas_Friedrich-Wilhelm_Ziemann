# Replication of Frank and Goyal (2003), "Testing the pecking order theory of capital structure"

MAF907 Empirical Corporate Finance, Assessment Task 3. Niklas Friedrich-Wilhelm Ziemann, Deakin University.
The report is submitted separately on CloudDeakin. This repository, public at
https://github.com/NiklasZiemann/MAF907_Assignment3_Niklas_Friedrich-Wilhelm_Ziemann, holds the code and
documentation that produce every table and figure in it.

The paper (Frank and Goyal, *Journal of Financial Economics* 67, 2003, 217-248) tests the Shyam-Sunder and
Myers (1999) prediction that a firm's financing deficit is matched dollar for dollar by net debt issues.
This repository rebuilds the paper's sample from Compustat for fiscal years 1971 to 2025, replicates Table 1
(common-size balance sheets), Table 2 (corporate cash flows) and Fig. 1 for the original window 1971 to
1998, and estimates the pecking order regressions (Table 3), the disaggregated deficit (Table 5), the size
splits, the debt-versus-equity comparison and the year-by-year coefficients that the assessment's five
questions ask for, over 1971 to 1998, 1999 to 2025 and the full window.

If you only want to run the pipeline, the [how to reproduce](#how-to-reproduce) section below has all of
the steps, including how to create the WRDS password file.

## Where the data are, and how to check them

The assessment asks for the raw data sample to accompany the report. The sample is built from Compustat
and CRSP, which are licensed through WRDS and may not be redistributed, and this repository is public. So
the extracts are not here: they accompany the report on CloudDeakin as a private attachment (the five
extracts of script 02, zipped, with `docs/data_manifest.md` inside), for the marker's use only. There
are three ways to check them, from cheapest to most thorough:

1. **Download the attachment and compare checksums.** The attachment is one zip file; its MD5 is
   8e467c41be5efb4bffb498628daf36c5, so check the download first. Script 02 writes each extract sorted
   by its key, so identical data give identical files; `docs/data_manifest.md` lists the row count, size and MD5 of
   each extract of record, and `docs/data_manifest.csv` the rows and column sums by fiscal year. To run
   the pipeline on them, copy the five extracts from the attachment's folder `wrds_extracts_2026-10-12`
   (`funda_1969_2025.csv`, `funda_footnotes.csv`, `company.csv`, `ccm_link.csv`, `crsp_msf_december.csv`)
   into `data/raw/wrds/` and run `code/run_all.R` (step 6 below): script 02 is then skipped, so no WRDS
   login is needed, and `docs/data_manifest_check.md` reads PASS on every line.
2. **Pull afresh with your own WRDS login (script 02) and run script 03.** Script 03 recomputes every
   line of the manifest for the files on disk and writes `docs/data_manifest_check.md`: PASS where they
   agree, and otherwise the fiscal years and items where the counts moved. Compustat is revised over
   time (restatements, backfilled years, new filers), so a pull made months later is expected to
   differ at the margin; the check says where, instead of failing on a bare checksum. Two lines always
   differ: script 02 also pulls two items the extracts of record lack (see the next section), so the
   size and MD5 of the fundamentals file cannot match. A pull on 13 October 2026 reproduced the other
   four extracts byte for byte and the fundamentals file byte for byte once those two columns are
   removed, and scripts 03 to 06 then wrote every table and figure byte for byte as in the run of record.
3. **Follow the counts.** Every script prints the count it produces at each step, "What to expect"
   below lists them, and `data/processed/regression_attrition.csv` counts, for every window and
   population of the pecking order regression (the report's Table 4), the firm-years lost by cause.

The only data committed are the FRED deflator series (public) and the printed cells of the paper's
tables, transcribed for the comparisons.

## Data sources and access

| Source | What it gives us | Access | Script |
|---|---|---|---|
| Compustat North America, Fundamentals Annual (WRDS) | Balance sheet, income statement and funds-flow items, the cash-flow format code, fiscal-year-end price and shares (the pull list also names goodwill and the excess tax benefit of stock options, for the two checks in `docs/DECISIONS.md` F14 and F19; the extracts of record were pulled before they were added and do not hold them) | Licensed: a WRDS login with Compustat North America, database access | 02 |
| Compustat Fundamentals Annual footnotes (WRDS) | Footnote code AB on sales, the paper's major-merger screen | Licensed, same subscription; the script says if the table is absent | 02 |
| Compustat company header (WRDS) | Header SIC code where the historical one is missing | Licensed, same subscription | 02 |
| CRSP/Compustat Merged link (WRDS) | Whether a firm-year has a CRSP security, the brief's sample instruction | Licensed: a WRDS login with CRSP | 02 |
| CRSP monthly stock file, December rows (WRDS) | Market capitalisation check for the size sorts | Licensed, same subscription | 02 |
| FRED CPIAUCNS and GDPDEF | Two candidate deflators to 1992 dollars (the paper names none) | Public, no key; the annual series are committed in `data/raw/public/` | 01 |
| The paper's printed tables | Target cells for every side-by-side comparison | Transcribed from the published article; `data/raw/paper/` | 04 to 06 |

`docs/data_dictionary.md` describes the extracts, the panel and the processed files, with the columns
the scripts add, and maps each exhibit of the report to the file and script behind it. `docs/wrds_query_specs.md` describes the WRDS tables, filters and fields. `docs/sample_construction.md`
walks the paper's screens with the count after each one. `docs/DECISIONS.md` records every judgement
call with the alternative and its measured effect.

## Project structure

```
MAF907_Assignment3_Niklas_Friedrich-Wilhelm_Ziemann.Rproj   open this in RStudio; here() then finds every path
renv.lock, .Rprofile, renv/      package versions (renv); renv::restore() installs them
README.md                        this file
config_example.csv               template for config.csv (WRDS user name; config.csv itself is git-ignored)
code/                            the numbered scripts plus run_all.R, run in this order
  00_packages.R                  installs the packages the scripts need when any is missing (sourced first by every script)
  00_helpers.R                   two helpers the scripts source: the trimming rule applied per exhibit, and the manifest rows
  01_public_deflators.R          FRED CPI-U and GDP deflator, rebased to 1992
  02_wrds_pull.R                 Compustat fundamentals, footnotes and header, the CRSP link, CRSP December prices (each written sorted by key)
  03_sample.R                    the paper's screens in order; variables by format code; missing values; the link; the manifest check
  04_q1_tables_1_2_fig1.R        Question 1: Table 1, Table 2, Fig. 1, period descriptives, annual means
  05_q2_q4_table3_horse_race.R   Questions 2 and 4: Table 3, its sensitivities, the equity regressions, the formal test, the annual coefficients, the break tests
  06_q3_table5_size.R            Question 3: Table 5 and the size splits
  run_all.R                      runs 01, 02 (skipped when the five extracts are already in data/raw/wrds) and 03 to 06 in order, and writes docs/session_info.txt
data/
  raw/paper                      committed: the printed cells of the paper's tables, for the comparisons
  raw/public                     committed: the FRED deflator series
  raw/wrds                       licensed extracts, git-ignored (a .gitkeep marker keeps the folder in the clone)
  processed/                     rebuilt by scripts 03 to 06, git-ignored (same marker)
docs/
  data_dictionary.md             the extracts, the panel and the processed files, and the exhibit map
  DECISIONS.md                   the judgement calls, with the alternative and its measured effect
  data_manifest.md, .csv         row counts, sizes, checksums and counts by fiscal year of the extracts behind the results of record (fixed reference)
  data_manifest_check.md         the extracts on disk against that manifest, line by line (03)
  wrds_query_specs.md            WRDS tables, fields and filters
  sample_construction.md         the paper's screens with counts
  session_info.txt               R and package versions of the run of record
output/
  tables/, figures/              regenerated by the scripts, git-ignored
```

## What renv, renv.lock and .Rprofile are for

R packages change, and a script that ran last year can give different numbers, or refuse to run, on
this year's versions. renv pins them. `renv.lock` records the R version and the exact version of every
package this project loaded; `renv::restore()` installs those versions into a library that belongs to
this project alone; `.Rprofile` switches renv on when the project opens. The installed library itself
is not committed because it is large and fully rebuilt from the lockfile.

## How to reproduce

Steps 1 to 3 need no WRDS account. Steps 4 and 5 set one up; only script 02, the fresh pull, needs it.
With the raw data sample that accompanies the report in `data/raw/wrds/`, scripts 03 to 06 run without one.

**1. R and RStudio.** R 4.6.0 on Windows is what the run of record used (`docs/session_info.txt`),
and the project was opened and tested in RStudio 2026.04.0+526 ("Globemaster Allium") for Windows.

**2. Restore the packages.** Copy the folder to a short path without special characters (Windows cuts
file names once a full path passes 260 characters, and the figure names are long). Then either:

- **In RStudio (simplest).** Open the project (step 3). On the first opening the Console shows renv
  installing itself, then "Restarting R session..." once; that is expected. Nothing else is needed:
  `run_all.R` and each script start with `code/00_packages.R`, which runs
  `renv::restore(prompt = FALSE)` when a package is missing (first run only, a few minutes) and falls
  back to CRAN if that fails.
- **From a terminal**, before opening RStudio (on Windows `Rscript` is not on the PATH after a standard
  install, so give the full path; on macOS or Linux `Rscript -e "renv::restore(prompt = FALSE)"` works
  as is):

```
"C:\Program Files\R\R-4.6.0\bin\Rscript.exe" -e "renv::restore(prompt = FALSE)"
```

Why the restart: on a fresh copy renv downloads itself when the project first opens, and RStudio 2026.04
on Windows kills the R session if a download runs while the session is starting ("Error Starting R").
`.Rprofile` therefore sets renv up once the session is running and restarts R once to load it.

**3. Open the project.** File > Open Project > the `.Rproj` file. Opening the `.Rproj` is what makes
`here()` resolve every path, so please do not `setwd()` anywhere.

**If `renv::restore()` fails, stalls, or starts compiling things, skip it.** Run, in the RStudio Console:

```
renv::deactivate()
install.packages(c("tidyverse", "here", "DBI", "dbplyr", "RPostgres", "fixest"))
```

That is every package the scripts load.

**4. The WRDS password file** (the unit's supporting page "R - WRDS Connection"). You need a WRDS
account whose subscription includes Compustat North America and CRSP, **with database access**, not
web-query access alone. Create the folder

```
C:\Users\<you>\AppData\Roaming\postgresql
```

if it does not exist, and inside it a plain-text file named exactly `pgpass.conf` holding **one line,
with no spaces and no quotation marks**:

```
wrds-pgdata.wharton.upenn.edu:9737:wrds:<your_wrds_username>:<your_wrds_password>
```

The five fields are host, port, database, user name, password, separated by colons. Save it with
Notepad, not Word, and make sure Windows has not appended `.txt` to the name. On macOS or Linux the
file is `~/.pgpass` with the same single line, and it must be `chmod 600`. Nothing else in the project
needs the password, and no script contains one.

**5. `config.csv`.** Copy `config_example.csv` to `config.csv` and put your WRDS user name in the
`wrds_username` row. `config.csv` is git-ignored.

**6. Run the pipeline.** Choose the data first. Route 1, the raw data sample from CloudDeakin: copy its
five extracts (named under "Where the data are") into `data/raw/wrds/`; script 01 still downloads its two FRED series, so an internet connection is needed once. Route 2, a fresh pull: leave `data/raw/wrds/` holding only
`.gitkeep` (steps 4 and 5 needed). Then open `code/run_all.R` and click Source: it runs 01, then 02
unless the five extracts are already in `data/raw/wrds/`, then 03 to 06. To run the scripts one at a
time instead, use **Source with Echo** (`Ctrl+Shift+Enter`) in the same order, leaving out 02 on
route 1. Either way the results are the same. The plain "Source" button runs a script silently, so nothing appears in the Console even though the
files are written; that is why `run_all.R` uses `echo = TRUE`.

**7. Check the counts** against "What to expect" below, and read `docs/data_manifest_check.md`, which
script 03 writes: PASS on every line means your extracts are the extracts of record; otherwise it names
the fiscal years and items where your pull differs. On route 2 the bytes and MD5 of
`funda_1969_2025.csv` always read DIFF, because script 02 adds two columns the extracts of record lack;
the rows and sums by fiscal year are the comparison that matters. Every script prints the counts it
produces as it goes, so a mismatch shows up at the script that caused it.

### If something does not work

- **Nothing appears in the Console.** Use **Source with Echo** (`Ctrl+Shift+Enter`).
- **`could not connect` in script 02.** The password file is missing, misnamed, or Windows has added
  `.txt` to it. Check the path and the internet connection.
- **Script 01 cannot reach FRED.** It downloads the CPI-U and GDP deflator series the first time it runs and
  rebuilds `fred_deflators.csv` from them; the annual file of record is already in `data/raw/public/`, so
  without a connection leave 01 out and source 03 to 06 one at a time.
- **`there is no package called ...`.** `renv::restore()` was skipped; install the packages as under step 3.
- **Script 02 prints names under `missing_fields`.** Your Compustat layout lacks a mnemonic the paper's
  formulas need; the script pulls what exists and script 03 stops at the variable that needs it.
- **Script 02 says no footnote table.** It then writes no `funda_footnotes.csv`, and script 03, which
  reads that file, stops. To run without the merger screen, create `data/raw/wrds/funda_footnotes.csv`
  holding the single line `gvkey,datadate,fyear,sale_fn`: script 03 then records in the attrition table
  that the screen was not applied (the paper's footnote 2 reports that the screen had no material
  effect), the counts from step 4 on sit a little above "What to expect", and the manifest check
  reports the footnote file as different.

## What to expect (run of record, 13 October 2026; extracts pulled 12 October 2026)

| Script | Output | Count |
|---|---|---|
| 01 | `fred_deflators.csv` | 61 years, 1965 to 2025; 1992 CPI-U annual average 140.3; FRED carries no October 2025 CPI value, so 2025 averages eleven months |
| 02 | five WRDS extracts | 563,355 fundamentals rows on 46,768 gvkeys (1969 to 2025); 564,713 footnote rows with 722 AB codes on sales; 46,768 header rows; 32,248 link rows on 28,137 gvkeys; 385,670 CRSP December rows (1970 to 2024). Rows, bytes, MD5 and counts by fiscal year in `docs/data_manifest.md` and `data_manifest.csv` |
| 03 | `panel_1971_2025.csv` | 554,977 -> 554,964 (one row per firm-year) -> 378,900 (industry) -> 378,308 (footnote AB) -> 358,059 (assets) -> 354,633 (format codes) -> 279,958 (US incorporation, carried as a flag) -> 276,168 (format code present) -> 201,890 linked firm-years on 18,253 firms (the all-Compustat population is the 276,168; the panel file also keeps the 71,466 foreign-incorporated firm-years with a format code, flagged, for the sensitivity rows). Per year against the paper's Table 1: 1971 2,779 (printed 2,833), 1998 7,295 (7,301). Identity DEF = net debt + net equity within USD 1,000 in 99.2 per cent of format 1 to 3 firm-years and 92.9 per cent of format 7. `docs/data_manifest_check.md`: every line PASS |
| 04 | Tables 1 and 2, Fig. 1, the period descriptives | Each exhibit trimmed within its own population and period (`docs/DECISIONS.md` F3). Table 1: 86 per cent of the 168 informative printed cells within 0.01 on all Compustat (mean absolute gap 0.0045), 67 per cent on the main sample (0.013); Table 2: 89 and 73 per cent of 56 cells; Fig. 1 series correlate 0.998 with the published points on all Compustat and 0.96 to 0.98 on the main sample. Period tests, main sample, t with firm-and-year clustering: internal cash flow and investment over assets fall (t -6.8 and -7.9) and gross debt issued over net assets rises (t 5.1); over net assets the deficit, net debt and net equity differences read t 1.6, -0.1 and 1.7 (over assets 1.9, -0.2 and 2.0) |
| 05 | Table 3, its sensitivities, the equity regressions, the test, the annual coefficients, the break tests | Deficit coefficient, all Compustat: 0.142 (1971 to 2025), 0.212 (1971 to 1998), 0.105 (1999 to 2025), 0.290 (1971 to 1989, printed 0.283; N 85,295 against 89,883; R2 0.271 against 0.265), 0.152 (1990 to 1998, printed 0.148). Main sample 0.145 / 0.196 / 0.104 / 0.269 / 0.139. Sensitivities on the paper's window, all Compustat: 0.318 with cut points inside 1971 to 1989, 0.262 with cut points over 1971 to 2025; without the country screen the main-sample coefficients move by at most 0.004. No-gaps firms, 1971 to 1989: 0.711 on 807 firms (printed 0.748 on 768). Equity coefficient on the common sample 0.847 (main, 1971 to 2025), b + c = 1.000. Chow at 1998/1999: shift -0.092 (t -18.8), Wald F 182; on 1980 to 2025 shift -0.068 (t -14.4), F 138; the break search peaks at its first split (1979/1980, F 512) and is lowest at 2000 (F 116). Balanced 1977 to 1982 panel: 2,180 firms, coefficient 0.60 to 0.81 throughout while all firms fall from 0.75 to 0.18 |
| 06 | Table 5, the size splits | All Compustat, 1971 to 1989: components 0.377, 0.398, 0.247, -0.188 (printed 0.372, 0.393, 0.246, -0.190), N 84,366, R2 0.292 (printed 88,892, 0.289); with the deficit also required 0.444, 0.417, 0.270, -0.227 (`table_5_deficit_required.csv`); asset quartiles 0.170, 0.449, 0.625, 0.781 (printed 0.164, 0.428, 0.623, 0.753); 1990 to 1998 quartiles 0.094, 0.168, 0.358, 0.686 (printed 0.087, 0.162, 0.355, 0.675). Main sample, market-cap terciles: bottom 0.182 and top 0.298 for 1971 to 1998, 0.071 and 0.242 for 1999 to 2025; the large-minus-small gap widens from 0.116 to 0.171 (t of the change 4.0); sorted on the prior year's market cap the top tercile reads 0.533 and 0.411 |

On 13 October 2026 `run_all.R` took about a minute on the extracts (route 1) and about two minutes with a fresh pull (route 2), of which script 02 took about one; when 02 runs, it reads a fundamentals file already on disk instead of pulling it again. `docs/session_info.txt` records the package versions.
