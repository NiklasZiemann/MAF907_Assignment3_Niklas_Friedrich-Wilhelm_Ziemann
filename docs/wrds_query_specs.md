# WRDS query specifications

What script 02 pulls, so that a reader can check the extracts or rebuild them through the WRDS web
query forms if they only have web access. All five pulls use the Postgres connection
(`wrds-pgdata.wharton.upenn.edu`, port 9737, database `wrds`); the password comes from the
`pgpass.conf` file described in the README.

## 1. Compustat North America, Fundamentals Annual (`comp.funda`)

Filters: `indfmt = 'INDL'`, `datafmt = 'STD'`, `popsrc = 'D'`, `consol = 'C'`, `fyear` between 1969
and 2025. One row per company and fiscal year in the standard industrial presentation (a fiscal-year-end
change can leave two rows; script 03 keeps the later one).

Fields, grouped by what the paper needs them for (legacy Compustat item numbers from the paper's
tables in parentheses):

- Identifiers and format: `gvkey`, `datadate`, `fyear`, `conm`, `tic`, `cusip`, `sich` (historical
  SIC), `fic`, `curcd`, `exchg`, `scf` (cash-flow format code; the paper excludes 4, 5 and 6).
- Balance sheet, Table 1: `at` (6), `ch` (162), `ivst` (193), `che` (1, the combined item), `rect` (2),
  `invt` (3), `aco` (68), `act` (4), `ppent` (8), `ivaeq` (31), `ivao` (32), `intan` (33), `ao` (69),
  `dlc` (34), `ap` (70), `txp` (71), `lco` (72), `lct` (5), `dltt` (9), `lo` (75), `txditc` (35),
  `mib` (38), `lt` (181), `pstk` (130), `ceq` (60), `seq` (216).
- Income statement, Tables 8 and 9: `sale` (12), `oibdp` (13), `ib` (18), `dp` (14), `dd1` (44).
- Cash dividends and investments, Table 2 footnotes a and b: `dv` (127), `capx` (128), `ivch` (113),
  `aqc` (129), `fuseo` (219), `sppe` (107), `siv` (109), `ivstch` (309), `ivaco` (310).
- Change in working capital, footnote c: `wcapc` (236), `chech` (274), `dlcch` (301), `recch` (302),
  `invch` (303), `apalch` (304), `txach` (305), `aoloch` (307), `fiao` (312).
- Internal cash flow, footnote d: `ibc` (123), `xidoc` (124), `dpc` (125), `txdc` (126), `esubc`
  (106), `sppiv` (213), `fopo` (217), `fsrco` (218), `exre` (314).
- Debt and equity issues: `dltis` (111), `dltr` (114), `sstk` (108), `prstkc` (115).
- Market value: `prcc_f`, `csho`.
- Not in the paper's formulas, pulled for two checks in `docs/DECISIONS.md`: `txbcof` (excess tax
  benefit of stock options, F14) and `gdwl` (goodwill, F19). The extracts of record were pulled before
  these two were added and do not hold them.

The script lists the table's fields first and prints any of these names that the subscription lacks.

## 2. Fundamentals Annual footnotes (`comp.funda_fncd`)

The footnote table of Fundamentals Annual, `comp.funda_fncd` (the schema also lists `bank_funda_fncd`
and `g_funda_fncd`, the bank and global files, which are not it; the first pull took the bank one by
mistake, see `docs/DECISIONS.md`). Keys `gvkey` and `datadate`, plus `fyear`, `indfmt`, `datafmt`,
`popsrc` and `consol` where the layout carries them (then filtered to INDL, STD, D, C as for the
fundamentals); fields `sale_fn` and `revt_fn`; rows with `datadate` from 1969-01-01 to 2026-06-30, restricted to the
gvkeys of the fundamentals pull; written sorted by `gvkey` and `datadate`. Footnote code `AB` on sales
marks a major merger or acquisition, the paper's exclusion: 769 rows carried it in the whole table on
12 October 2026 and 722 in the extract (the firms of the pull); script 03 removes 592 firm-years with
it, the other rows falling before fiscal 1971 or on firm-years the earlier screens have removed. If no
such table exists under the subscription, script 02 says so and writes no footnote file, and script 03
stops when it reads that file; the README ("If something does not work") says how to run without the
screen.

## 3. Company header (`comp.company`)

All rows, fields `gvkey`, `conm`, `sic`, `naics`, `fic`, `loc`, `state`, `ipodate`, `dldte`; cut in R
to the gvkeys of the fundamentals pull. The header SIC is used where the historical `sich` is missing.

## 4. CRSP/Compustat Merged link

`crsp.ccmxpf_linktable` (or `crsp_a_ccm.ccmxpf_linktable`, or the `lnkhist` variants, whichever exists
first), `linktype` in (`LU`, `LC`), `linkprim` in (`P`, `C`), fields `gvkey`, `lpermno`, `linktype`,
`linkprim`, `linkdt`, `linkenddt`; cut in R to the pull's gvkeys. Script 03 counts a firm-year as linked
when its fiscal year end falls inside a link's date range.

## 5. CRSP monthly stock file, December rows (`crsp.msf`)

`date` between 1970-12-01 and 2025-12-31 and calendar month 12, fields `permno`, `date`, `prc`,
`shrout`. Used only for the market-capitalisation check on the size terciles (`abs(prc) * shrout / 1000`,
millions).
