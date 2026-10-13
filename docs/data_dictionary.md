# Data dictionary and exhibit map

## Raw extracts (`data/raw/wrds/`, git-ignored; `docs/wrds_query_specs.md` lists the fields of each)

Each extract is written sorted by its key (script 02), so that identical data give identical files;
`docs/data_manifest.csv` and `data_manifest.md` record what the extracts of record contained (fixed
reference files), and `docs/data_manifest_check.md` reports how the files on disk compare (script 03).

| File | One row per | Sort key | Script |
|---|---|---|---|
| `funda_1969_2025.csv` | company (`gvkey`) and fiscal year (`fyear`, `datadate`) | `gvkey`, `datadate` | 02 |
| `funda_footnotes.csv` | company and fiscal year end (`gvkey`, `datadate`, with `fyear` and the four format keys), footnote columns `sale_fn`, `revt_fn` | `gvkey`, `datadate` | 02 |
| `company.csv` | company: `sic`, `naics`, `fic`, `loc`, `state`, `ipodate`, `dldte` | `gvkey` | 02 |
| `ccm_link.csv` | link: `gvkey`, `lpermno`, `linktype`, `linkprim`, `linkdt`, `linkenddt` | `gvkey`, `linkdt`, `lpermno` | 02 |
| `crsp_msf_december.csv` | security (`permno`) and December month end: `prc`, `shrout` | `permno`, `date` | 02 |

## Public data (`data/raw/public/`, committed)

| File | Columns | Script |
|---|---|---|
| `fred_deflators.csv` | `year`, `cpi_annual`, `n_months`, `gdpdef_annual`, `n_quarters`, `cpi_1992`, `gdpdef_1992` (1992 = 1) | 01 |

## The paper's printed cells (`data/raw/paper/`, committed)

`table1_original.csv`, `table2_original.csv`, `fig1_original.csv`, `table3_original.csv`,
`table4_original.csv`, `table5_original.csv`, `table6_original.csv` (with `_stars` and `_columns`
companions), `table9_original.csv`.

## The panel (`data/processed/panel_1971_2025.csv`, one row per firm-year, git-ignored)

Raw Compustat columns keep their mnemonics (after the recoding of F2). The panel holds every
firm-year that survives the paper's screens up to the format-code screen, in every country of
incorporation; the two populations of the report are selected by the flags below. Added columns:

| Column | Definition |
|---|---|
| `sic_header`, `loc`, `ipodate`, `dldte` | from the company header: its SIC code (`sic`, renamed), the country of the headquarters, the IPO date and the deletion date |
| `sic_used` | `sich`, or the header `sic` where `sich` is missing |
| `cash_combined` | TRUE where only the combined cash and short-term investments item was reported |
| `us_inc` | TRUE where `fic` is USA (the country screen of F1, carried as a flag; both populations require it) |
| `fmt` | "old" for format codes 1 to 3, "new" for 7, NA otherwise |
| `div` | cash dividends (`dv`) |
| `inv` | investments, Table 2 footnote b by format |
| `dwc` | change in working capital, footnote c by format |
| `cf` | internal cash flow, footnote d by format |
| `def` | financing deficit = `div` + `inv` + `dwc` - `cf` |
| `nd`, `gd`, `ne`, `nxt` | net debt issued (`dltis` - `dltr`), gross debt issued (`dltis`), net equity issued (`sstk` - `prstkc`), net external financing (`nd` + `ne`) |
| `cmltd` | current maturity of long-term debt (`dd1`) |
| `na` | net assets = `at` - `lct` |
| `bdebt` | book debt = `dlc` + `dltt` |
| `mcap` | market value of equity = `prcc_f` x `csho` (script 06 adds `mcap_lag`, the prior fiscal year's value, for the sort of F18) |
| `<item>_at` | the item over total assets, untrimmed, NA where `at` is zero; for the 24 Table 1 items and the ten flow items |
| `<item>_na` | the flow item over net assets, untrimmed, NA where `na` is not positive |
| `permno`, `ccm_linked` | the linked CRSP security at the fiscal year end, and whether one exists (the main sample is `ccm_linked & us_inc`; the all-Compustat population is `us_inc`) |
| `dec_year`, `mcap_crsp` | the December used for the CRSP market capitalisation, and that value in millions |

The ratios are trimmed by each exhibit on the sample it covers (F3; `code/00_helpers.R`), not in the panel.

## Other processed files

| File | Content | Script |
|---|---|---|
| `sample_attrition.csv` | one row per screen: step, rule, firm-years, firms | 03 |
| `recoding_counts.csv` | cells recoded to zero, per item | 03 |
| `identity_check.csv` | how often `def` equals `nxt`, by format | 03 |
| `deflator_check.csv` | the Table 9 dollar means under both deflators | 03 |
| `link_decomposition.csv` | what the CRSP link removes from the paper's population, by reason (never linked, pre-listing years, post-delisting years, link gaps), with firms and median assets | 03 |
| `trimming_counts.csv` | one row per exhibit and ratio: the cut points, observations before and after trimming, the share removed | 04, 05, 06 |
| `regression_attrition.csv` | for each regression window and population, the firm-years lost by cause before the regression N (F17) | 05 |

## Exhibit map (report exhibit to file and script)

| Report exhibit | File(s) in `output/` | Script |
|---|---|---|
| Table A (the screens with counts; panel B the attrition by cause) | `data/processed/sample_attrition.csv`, `regression_attrition.csv`, `recoding_counts.csv`, `trimming_counts.csv` | 03 to 06 |
| Table B (the two populations beside the paper's counts) | `tables/table_b_populations.csv` | 05 |
| Table 1a replicated beside the original, both populations; similarity on the 168 informative cells | `tables/table_1_replicated.csv`, `table_1_comparison.csv`, `table_1_similarity.csv` (a `population` column: `main`, `compustat_all`) | 04 |
| Table 1b (the extension years and the two period means); its note on negative book equity by link status | `tables/table_1_replicated.csv`, `table_1_negative_equity_by_link.csv` | 04 |
| Tables 2a and 2b, the same pattern | `tables/table_2_*.csv` | 04 |
| Figure 1 (1971 to 1998 beside the original) and Figure 2 (1971 to 2025) | `figures/figure_1_1971_1998.png`, `figure_1_1971_2025.png`; `tables/figure_1_points.csv`, `figure_1_comparison.csv` | 04 |
| Table 3 (the two periods compared; Welch t and the firm-and-year clustered t) | `tables/table_q1_period_descriptives.csv` | 04 |
| Figure 3 (annual means of the cash-flow items) | `figures/figure_q1_annual_means.png`; `tables/table_q1_annual_means.csv` | 04 |
| Question 1.3: the Chow tests, the break search and Figure 4 (the break search), the balanced 1977 to 1982 panel | `tables/table_q1_chow.csv`, `table_q1_break_search.csv`, `table_q1_balanced_1977_1982.csv`; `figures/figure_q1_break_search.png` | 05 |
| Table 4 (the paper's Table 3 replicated: three brief columns, two paper windows, printed column (4), the no-gaps rows); its sensitivity panel (trimming window, country screen) | `tables/table_3_replicated.csv`, `table_3_no_gaps.csv`, `table_3_trimming_sensitivity.csv`, `table_q2_country_screen.csv` | 05 |
| Table 5 (the components), both readings | `tables/table_5_replicated.csv`, `table_5_deficit_required.csv` | 06 |
| Table 6 (size splits: the brief's terciles, the lagged and same-sample sorts, the asset quartiles with the printed values, the gap test) | `tables/table_q3_size_terciles.csv`, `table_q3_size_quartiles.csv`, `table_q3_size_gap_test.csv`, `table_q3_size_terciles_crsp_check.csv` | 06 |
| Table 7 (debt against equity on the common sample; the equity regression on its own sample for the record) | `tables/table_q4_debt_vs_equity.csv` | 05 |
| Table 8 (the stacked test) | `tables/table_q4_test.csv`; `data/processed/identity_check.csv` | 05, 03 |
| Figure 5 (annual coefficients) | `figures/figure_q4_annual_coefficients.png`; `tables/table_q4_annual_coefficients.csv` | 05 |
| Sample construction and the manifest | `docs/sample_construction.md`, `docs/data_manifest.md`, `data_manifest.csv`, `data_manifest_check.md` | 03 |

The report's tables are assembled from these files by `04_report/build_tables.py` in the project folder
above the repository; every number in them is read from the files named here, none is typed.
