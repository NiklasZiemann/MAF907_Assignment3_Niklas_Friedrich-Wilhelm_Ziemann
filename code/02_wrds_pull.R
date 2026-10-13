# 02. Collect the WRDS data: Compustat fundamentals, footnotes and header, the CRSP link, CRSP December prices
#
# WRDS data is licensed: it is downloaded with your own WRDS login and is never committed to the
# repository (data/raw/wrds is in .gitignore). The password is not in this file either. It sits in
# the Postgres password file, which R reads automatically:
#   C:\Users\<your user name>\AppData\Roaming\postgresql\pgpass.conf
# containing one line:
#   wrds-pgdata.wharton.upenn.edu:9737:wrds:<wrds_username>:<wrds_password>
# (see the unit page "R - WRDS Connection")
#
# Reads:  config.csv (WRDS user name; git-ignored)
# Writes (each sorted by its key, so that identical data give identical files; script 03 checks them against
# the manifest of record, docs/data_manifest.csv, written once from the extracts of record):
#         data/raw/wrds/funda_1969_2025.csv   Compustat annual fundamentals, fiscal years 1969 to 2025
#         data/raw/wrds/funda_footnotes.csv   footnote codes on the items the paper's merger screen needs (if available)
#         data/raw/wrds/company.csv           header record of every gvkey in the pull
#         data/raw/wrds/ccm_link.csv          CRSP/Compustat link
#         data/raw/wrds/crsp_msf_december.csv CRSP monthly price and shares, December rows only
#
# The paper's sample (Section 3): Compustat firms with funds-flow data from 1971, excluding
# financials (SIC 6000 to 6999), utilities (4900 to 4999), firm-years with Compustat footnote code AB
# (major merger), missing book assets, and cash-flow format codes 4, 5 and 6. Script 03 applies the
# screens; this script only collects. Two extra fiscal years at the front are pulled for lags.

source("code/00_packages.R")   # installs any missing package first (see that file)
library(tidyverse)
library(DBI)
library(dbplyr)
library(RPostgres)
library(here)

# 1. Connect. The user name is read from config.csv (git-ignored); the password comes from pgpass.conf.
config <- read_csv(here("config.csv"), show_col_types = FALSE)
wrds_username <- config |> filter(setting == "wrds_username") |> pull(value)

wrds <- dbConnect(Postgres(),
                  host = "wrds-pgdata.wharton.upenn.edu",
                  port = 9737,
                  dbname = "wrds",
                  sslmode = "require",
                  user = wrds_username)

# 2. The fields the paper's formulas need (Table 2 footnotes, Table 1, Table 8, Table 9 notes), by
#    their modern Compustat mnemonics. Any name missing from comp.funda is printed before the pull.
funda_fields <- c(
  # identifiers and format
  "gvkey", "datadate", "fyear", "conm", "tic", "cusip", "sich", "fic", "curcd", "exchg", "scf",
  # balance sheet (Table 1)
  "at", "ch", "ivst", "che", "rect", "invt", "aco", "act", "ppent", "ivaeq", "ivao", "intan", "ao",
  "dlc", "ap", "txp", "lco", "lct", "dltt", "lo", "txditc", "mib", "lt", "pstk", "ceq", "seq",
  # income statement (Table 8, Table 9)
  "sale", "oibdp", "ib", "dp", "dd1",
  # cash dividends, investments (Table 2 footnotes a, b)
  "dv", "capx", "ivch", "aqc", "fuseo", "sppe", "siv", "ivstch", "ivaco",
  # change in working capital (footnote c)
  "wcapc", "chech", "dlcch", "recch", "invch", "apalch", "txach", "aoloch", "fiao",
  # internal cash flow (footnote d)
  "ibc", "xidoc", "dpc", "txdc", "esubc", "sppiv", "fopo", "fsrco", "exre",
  # debt and equity issues (Table 2, Table 9)
  "dltis", "dltr", "sstk", "prstkc",
  # market value (Table 7 note; size sorts)
  "prcc_f", "csho",
  # not in the paper's formulas; pulled for two checks recorded in docs/DECISIONS.md: the excess tax
  # benefit of stock options, a financing inflow under FAS 123R from 2006 to 2017 and the item by which
  # the deficit misses net debt plus net equity in those years (F14), and goodwill inside intangibles
  # (F19). The extracts of record were pulled before these two were added and do not hold them.
  "gdwl", "txbcof")

funda_available <- dbListFields(wrds, Id(schema = "comp", table = "funda"))
missing_fields  <- setdiff(funda_fields, funda_available)
missing_fields                          # must print character(0); otherwise correct the item names above
funda_fields <- intersect(funda_fields, funda_available)

# 3. Fundamentals annual: the standard screens for one row per firm-year (industrial format, standard
#    data format, domestic population source, consolidated), fiscal years 1969 to 2025. About 560,000
#    rows are expected before any screen (563,355 in the pull of 12 October 2026).
#    The pull takes several minutes, so a file already on disk is read back instead of pulled again;
#    delete it to force a fresh pull.
funda_file <- here("data", "raw", "wrds", "funda_1969_2025.csv")
if (file.exists(funda_file)) {
  funda <- read_csv(funda_file, show_col_types = FALSE, col_types = cols(gvkey = col_character(), .default = col_guess()))
} else {
  funda <- tbl(wrds, in_schema("comp", "funda")) |>
    filter(indfmt == "INDL", datafmt == "STD", popsrc == "D", consol == "C",
           fyear >= 1969, fyear <= 2025) |>
    select(all_of(funda_fields)) |>
    collect() |>
    arrange(gvkey, datadate, .locale = "C")       # sorted by key, so the same data always give the same file (docs/data_manifest.md)
  write_csv(funda, here("data", "raw", "wrds", "funda_1969_2025.csv"))
}
nrow(funda)
n_distinct(funda$gvkey)
funda |> count(fyear) |> filter(fyear %in% c(1971, 1988, 1998, 2024, 2025))
funda |> count(scf) |> arrange(desc(n))

# 4. Footnotes. Compustat footnote code AB on sales marks a major merger or acquisition (the paper's
#    screen). The footnote table of funda is pulled if the subscription has one; its footnote
#    columns end in _fn. If none exists, no footnote file is written and script 03 stops when it
#    reads it; the README ("If something does not work") says how to run without the screen.
fncd_tables <- dbGetQuery(wrds, "
  select table_schema, table_name
  from information_schema.tables
  where table_schema in ('comp', 'comp_na_daily_all', 'compa') and table_name like '%funda%fncd%'
  order by table_schema, table_name")
fncd_tables
#    The table wanted is comp.funda_fncd itself (the listing also shows bank_funda_fncd and
#    g_funda_fncd, which are the bank and global files; the first run took the bank one by mistake).
fncd_tables <- fncd_tables |> filter(table_name == "funda_fncd") |> arrange(table_schema != "comp")
if (nrow(fncd_tables) > 0) {
  fn_schema <- fncd_tables$table_schema[1]
  fn_table  <- fncd_tables$table_name[1]
  fn_fields <- dbListFields(wrds, Id(schema = fn_schema, table = fn_table))
  # (inside an if block nothing is echoed on its own, hence print() for every count in this block and the two below)
  print(length(fn_fields))                # 888 columns: one _fn (footnote) and one _dc (data code) column per item
  fn_keep   <- intersect(c("sale_fn", "revt_fn"), fn_fields)
  print(fn_keep)
  # The footnote table is keyed by gvkey and datadate; the current layout also carries fyear and the
  # four format columns, and only the keys that exist are used, in case a layout lacks some of them.
  fn_keys   <- intersect(c("gvkey", "datadate", "fyear", "indfmt", "datafmt", "popsrc", "consol"), fn_fields)
  footnotes <- tbl(wrds, in_schema(fn_schema, fn_table)) |>
    filter(datadate >= as.Date("1969-01-01"), datadate <= as.Date("2026-06-30")) |>
    select(all_of(c(fn_keys, fn_keep))) |>
    collect()
  if (all(c("indfmt", "datafmt", "popsrc", "consol") %in% names(footnotes))) {
    footnotes <- footnotes |> filter(indfmt == "INDL", datafmt == "STD", popsrc == "D", consol == "C")
  }
  footnotes <- footnotes |> filter(gvkey %in% unique(funda$gvkey)) |> arrange(gvkey, datadate, .locale = "C")
  print(nrow(footnotes))
  print(footnotes |> count(sale_fn, sort = TRUE) |> head(10))
  print(footnotes |> summarise(across(all_of(fn_keep), ~ sum(.x == "AB", na.rm = TRUE))))   # 722 on sales for the firms of this pull (769 rows carry AB in the whole table)
  write_csv(footnotes, here("data", "raw", "wrds", "funda_footnotes.csv"))
} else {
  message("No funda footnote table under this subscription: the footnote AB screen cannot be applied.")
}

# 5. Company header: header SIC for rows where sich is missing, country, IPO and deletion dates.
gvkeys <- unique(funda$gvkey)
company <- tbl(wrds, in_schema("comp", "company")) |>
  select(gvkey, conm, sic, naics, fic, loc, state, ipodate, dldte) |>
  collect() |>
  filter(gvkey %in% gvkeys) |>
  arrange(gvkey, .locale = "C")
nrow(company)
write_csv(company, here("data", "raw", "wrds", "company.csv"))

# 6. CRSP/Compustat link (the brief asks for the merged database) and CRSP December prices and shares
#    for the market-capitalisation check. Table names differ across WRDS layouts, so the first one
#    that exists is used, as in the Assessment Task 2 pull.
pick_table <- function(candidates) {
  for (cand in candidates) if (dbExistsTable(wrds, Id(schema = cand[1], table = cand[2]))) return(cand)
  NULL
}
link_table <- pick_table(list(c("crsp", "ccmxpf_linktable"), c("crsp_a_ccm", "ccmxpf_linktable"),
                              c("crsp", "ccmxpf_lnkhist"),   c("crsp_a_ccm", "ccmxpf_lnkhist")))
msf_table  <- pick_table(list(c("crsp", "msf"), c("crsp_a_stock", "msf")))
link_table
msf_table

if (!is.null(link_table)) {
  ccm_link <- tbl(wrds, in_schema(link_table[1], link_table[2])) |>
    filter(linktype %in% c("LU", "LC"), linkprim %in% c("P", "C")) |>
    select(gvkey, lpermno, linktype, linkprim, linkdt, linkenddt) |>
    collect() |>
    filter(gvkey %in% gvkeys) |>
    arrange(gvkey, linkdt, lpermno, .locale = "C")
  print(nrow(ccm_link))
  print(n_distinct(ccm_link$gvkey))
  write_csv(ccm_link, here("data", "raw", "wrds", "ccm_link.csv"))
} else {
  message("No CRSP/Compustat link table found under this subscription: script 03 cannot apply the link screen.")
}

if (!is.null(msf_table)) {
  # December rows only: about one twelfth of the monthly file, roughly 400,000 rows
  crsp_dec <- tbl(wrds, in_schema(msf_table[1], msf_table[2])) |>
    filter(date >= as.Date("1970-12-01"), date <= as.Date("2025-12-31")) |>
    filter(sql("extract(month from date) = 12")) |>
    select(permno, date, prc, shrout) |>
    collect() |>
    arrange(permno, date)
  print(nrow(crsp_dec))
  write_csv(crsp_dec, here("data", "raw", "wrds", "crsp_msf_december.csv"))
}

# 7. Disconnect and list what was written
dbDisconnect(wrds)
list.files(here("data", "raw", "wrds"))
