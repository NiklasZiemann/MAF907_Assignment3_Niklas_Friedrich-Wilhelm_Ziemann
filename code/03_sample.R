# 03. The sample: the paper's screens in order, the variables by format code, missing values, the
#     CRSP/Compustat link, the CRSP market capitalisation, and the checks against the paper's own counts
#
# Frank and Goyal (2003), Section 3 (journal page 225): funds-flow data from 1971; financial firms
# (SIC 6000 to 6999), regulated utilities (4900 to 4999) and firms involved in major mergers
# (Compustat footnote code AB) excluded; firms with missing book assets and format codes 4, 5 and 6
# excluded; several items recoded as zero when missing or combined (footnote 3, the Table 1 note and
# the "n" markers of Table 8); balance sheet and cash flow variables as a share of assets trimmed at
# the most extreme 0.5 per cent in each tail. Variables follow the Table 2 footnotes a to d and the
# Table 9 note, by format code. Regressions scale by net assets (total assets minus current
# liabilities, Section 2).
#
# Inputs:  data/raw/wrds/funda_1969_2025.csv, funda_footnotes.csv, company.csv, ccm_link.csv,
#          crsp_msf_december.csv (script 02); data/raw/public/fred_deflators.csv (script 01)
# Outputs: data/processed/panel_1971_2025.csv      one row per firm-year with every variable and flag
#          data/processed/sample_attrition.csv     one row per screen, firm-years and firms after it
#          data/processed/recoding_counts.csv      cells recoded to zero, per item
#          (data/processed/trimming_counts.csv is built by scripts 04 to 06: one row per exhibit and ratio)
#          data/processed/identity_check.csv       how often DEF equals net debt plus net equity
#          data/processed/deflator_check.csv       Table 9 dollar means under both deflators
#          data/processed/link_decomposition.csv   what the CRSP link removes from the paper's population, by reason
#          docs/data_manifest_check.md (the extracts on disk against docs/data_manifest.csv), docs/sample_construction.md

source("code/00_packages.R")   # installs any missing package first (see that file)
library(tidyverse)
library(here)
source(here("code", "00_helpers.R"))

funda     <- read_csv(here("data", "raw", "wrds", "funda_1969_2025.csv"),
                      col_types = cols(gvkey = "c", cusip = "c", tic = "c", .default = col_guess()))
company   <- read_csv(here("data", "raw", "wrds", "company.csv"), col_types = cols(gvkey = "c", sic = "d", naics = "c"))
footnotes <- read_csv(here("data", "raw", "wrds", "funda_footnotes.csv"), col_types = cols(.default = "c"))
ccm       <- read_csv(here("data", "raw", "wrds", "ccm_link.csv"), col_types = cols(gvkey = "c"))
crsp_dec  <- read_csv(here("data", "raw", "wrds", "crsp_msf_december.csv"))
deflators <- read_csv(here("data", "raw", "public", "fred_deflators.csv"))
nrow(funda)

# ---------------------------------------------------------------------------------------------
# 1. The window, and one row per firm and fiscal year (a change of fiscal year end can leave two
#    rows for one fyear; the later one is kept)
# ---------------------------------------------------------------------------------------------
panel <- funda |>
  filter(fyear >= 1971, fyear <= 2025)
panel |> summarise(firm_years = n(), firms = n_distinct(gvkey))
attrition <- panel |> summarise(step = 1, rule = "Compustat industrial, standard, domestic, consolidated; fiscal years 1971 to 2025",
                                firm_years = n(), firms = n_distinct(gvkey))

panel <- panel |>
  arrange(gvkey, fyear, datadate) |>
  group_by(gvkey, fyear) |>
  slice_tail(n = 1) |>
  ungroup()
panel |> summarise(firm_years = n(), firms = n_distinct(gvkey))
attrition <- bind_rows(attrition, panel |> summarise(step = 2, rule = "one row per firm and fiscal year (later fiscal year end kept)",
                                                     firm_years = n(), firms = n_distinct(gvkey)))

# ---------------------------------------------------------------------------------------------
# 2. Industry screen on the historical SIC code, with the header code where it is missing.
#    Firm-years with no code at all are kept: there is nothing to screen them on.
# ---------------------------------------------------------------------------------------------
panel <- panel |>
  left_join(company |> select(gvkey, sic_header = sic, loc, ipodate, dldte), by = "gvkey") |>
  mutate(sic_used = coalesce(sich, sic_header)) |>
  filter(is.na(sic_used) | !(between(sic_used, 6000, 6999) | between(sic_used, 4900, 4999)))
panel |> summarise(firm_years = n(), firms = n_distinct(gvkey), no_sic = sum(is.na(sic_used)))
attrition <- bind_rows(attrition, panel |> summarise(step = 3, rule = "financial firms (SIC 6000 to 6999) and regulated utilities (4900 to 4999) excluded",
                                                     firm_years = n(), firms = n_distinct(gvkey)))

# ---------------------------------------------------------------------------------------------
# 3. Major mergers: Compustat footnote code AB. Applied only where the footnote extract holds rows
#    with the code; otherwise recorded as not applied (the paper's footnote 2 reports no material effect).
# ---------------------------------------------------------------------------------------------
ab_rows <- footnotes |>
  filter(sale_fn == "AB") |>                     # the exact code on the sales item, as the paper says
  mutate(datadate = ymd(datadate)) |>
  distinct(gvkey, datadate) |>
  mutate(merger_ab = TRUE)
nrow(ab_rows)

if (nrow(ab_rows) > 0) {
  panel <- panel |>
    left_join(ab_rows, by = c("gvkey", "datadate")) |>
    filter(is.na(merger_ab)) |>
    select(-merger_ab)
  attrition <- bind_rows(attrition, panel |> summarise(step = 4, rule = "firm-years with Compustat footnote code AB (major merger) excluded",
                                                       firm_years = n(), firms = n_distinct(gvkey)))
} else {
  attrition <- bind_rows(attrition, panel |> summarise(step = 4, rule = "footnote AB screen NOT applied: the footnote extract carries no AB code (paper footnote 2: no material effect)",
                                                       firm_years = n(), firms = n_distinct(gvkey)))
}
panel |> summarise(firm_years = n(), firms = n_distinct(gvkey))

# ---------------------------------------------------------------------------------------------
# 4. Missing book assets, and the cash-flow format codes 4, 5 and 6. Format codes 1 to 3 are the
#    pre-1988 funds statements, 7 is the statement of cash flows; a missing code gets no flow
#    variables below.
# ---------------------------------------------------------------------------------------------
panel <- panel |> filter(!is.na(at))                 # the paper's wording; a zero-asset row has no ratio and leaves every table on its own
attrition <- bind_rows(attrition, panel |> summarise(step = 5, rule = "missing book value of total assets excluded",
                                                     firm_years = n(), firms = n_distinct(gvkey)))
panel <- panel |> filter(is.na(scf) | !(scf %in% c(4, 5, 6)))
attrition <- bind_rows(attrition, panel |> summarise(step = 6, rule = "cash-flow format codes 4, 5 and 6 excluded",
                                                     firm_years = n(), firms = n_distinct(gvkey)))
panel |> count(scf)
panel |> filter(is.na(scf)) |> count(fyear) |> filter(fyear %in% c(1971, 1980, 1990, 2000, 2010, 2020, 2025))

#    The paper's format code 5 was "the Canadian file": in 2001 Compustat kept Canadian firms apart
#    and did not carry other foreign filers in the US file. Today's file holds them all, so the
#    equivalent screen is incorporation in the United States. With that screen and a format code,
#    the firm-years per year match the paper's Table 1 counts within 5.5 per cent in every printed
#    year (docs/DECISIONS.md F1); without it the count is a fifth too high. The screen is carried as
#    a flag (us_inc): both populations require it, and the foreign-incorporated linked firm-years stay
#    in the file for the sensitivity rows of Table 4 (script 05), which show what the screen does.
panel |> count(fic, sort = TRUE) |> head(6)
panel <- panel |> mutate(us_inc = fic == "USA")
attrition <- bind_rows(attrition, panel |> filter(us_inc) |> summarise(step = 7, rule = "incorporated outside the United States excluded (the paper's Canadian file, format code 5, and the other foreign filers the 2001 file did not hold)",
                                                     firm_years = n(), firms = n_distinct(gvkey)))
panel <- panel |> filter(!is.na(scf))
attrition <- bind_rows(attrition, panel |> filter(us_inc) |> summarise(step = 8, rule = "no cash-flow format code (no funds-flow statement, so no flow variable can be built) excluded",
                                                     firm_years = n(), firms = n_distinct(gvkey)))
panel |> count(us_inc)
panel |> filter(us_inc) |> summarise(firm_years = n(), firms = n_distinct(gvkey))

# ---------------------------------------------------------------------------------------------
# 5. Missing values. The paper (footnote 3, the Table 1 note, the "n" markers of Table 8) recodes
#    these items to zero when missing or combined with other items. Items not on the list stay
#    missing. Where only the combined cash and short-term investments item (che) is reported, it
#    goes to cash and short-term investments is set to zero.
# ---------------------------------------------------------------------------------------------
#    One addition to the paper's lists: the change in cash (chech, #274) carries no marker in Table 8,
#    but it is missing for a large block of pre-1988 firm-years whose funds statements reported no
#    cash line, and without it those firm-years have no deficit at all; the paper's firm counts imply
#    they were kept, so it is recoded and the count by format is printed (docs/DECISIONS.md F2).
recode_items <- c("ivaeq", "ivao", "intan", "ao", "dlc", "txp", "lco", "lo", "txditc", "mib",      # Table 1 note
                  "xidoc", "txdc", "esubc", "sppiv", "fopo", "fsrco", "exre",                       # Table 8 "n" markers
                  "recch", "invch", "apalch", "txach", "aoloch", "ivch", "siv", "capx", "sppe",
                  "aqc", "ivstch", "ivaco", "prstkc", "dv", "dltr", "dlcch", "fiao", "fuseo",
                  "wcapc", "dpc",
                  "chech")                                                                           # the addition
recoding <- panel |>
  summarise(across(all_of(recode_items), ~ sum(is.na(.x)))) |>
  pivot_longer(everything(), names_to = "item", values_to = "cells_recoded_to_zero")
recoding |> print(n = Inf)
panel |> group_by(scf) |> summarise(chech_missing = sum(is.na(chech)), firm_years = n())

panel <- panel |>
  mutate(cash_combined = is.na(ch) & !is.na(che),
         ch   = if_else(cash_combined, che, ch),
         ivst = if_else(cash_combined, 0, ivst)) |>
  mutate(across(all_of(recode_items), ~ replace_na(.x, 0)))
panel |> count(cash_combined)

# ---------------------------------------------------------------------------------------------
# 6. The variables, exactly the Table 2 footnotes a to d and the Table 9 note, by format code
#    (legacy item numbers in the comments)
# ---------------------------------------------------------------------------------------------
panel <- panel |>
  mutate(fmt = case_when(scf %in% 1:3 ~ "old", scf == 7 ~ "new"),
         div = dv,                                                                       # 127
         inv = case_when(fmt == "old" ~ capx + ivch + aqc + fuseo - sppe - siv,          # 128+113+129+219-107-109
                         fmt == "new" ~ capx + ivch + aqc - sppe - siv - ivstch - ivaco), # 128+113+129-107-109-309-310
         dwc = case_when(scf == 1     ~  wcapc + chech + dlcch,                          # 236+274+301
                         scf %in% 2:3 ~ -wcapc + chech - dlcch,                          # -236+274-301
                         fmt == "new" ~ -recch - invch - apalch - txach - aoloch + chech - fiao - dlcch),  # -302-303-304-305-307+274-312-301
         cf  = case_when(fmt == "old" ~ ibc + xidoc + dpc + txdc + esubc + sppiv + fopo + fsrco,  # 123+124+125+126+106+213+217+218
                         fmt == "new" ~ ibc + xidoc + dpc + txdc + esubc + sppiv + fopo + exre),  # ... +314
         def   = div + inv + dwc - cf,                                                   # equation (1)
         nd    = dltis - dltr,                                                           # 111 - 114
         gd    = dltis,                                                                  # 111
         ne    = sstk - prstkc,                                                          # 108 - 115
         nxt   = nd + ne,                                                                # net external financing
         cmltd = dd1,                                                                    # 44
         na    = at - lct,                                                               # net assets (Section 2)
         bdebt = dlc + dltt,                                                             # book debt (Table 9 note)
         mcap  = prcc_f * csho)                                                          # market value of equity
panel |> summarise(firm_years = n(), with_format = sum(!is.na(fmt)), with_def = sum(!is.na(def)),
                   net_assets_not_positive = sum(na <= 0, na.rm = TRUE))

# ---------------------------------------------------------------------------------------------
# 7. Ratios. Table 1 and Table 2 scale by total assets (their notes); the regressions by net assets.
# ---------------------------------------------------------------------------------------------
bs_items   <- c("ch", "ivst", "rect", "invt", "aco", "act", "ppent", "ivaeq", "ivao", "intan", "ao",
                "dlc", "ap", "txp", "lco", "lct", "dltt", "lo", "txditc", "mib", "lt", "pstk", "ceq", "seq")
flow_items <- c("div", "inv", "dwc", "cf", "def", "nd", "gd", "ne", "nxt", "cmltd")
#    A firm-year with zero total assets stays in the sample (the paper screens only missing assets)
#    but gets no ratio to total assets: dividing by zero would give an infinite value that drags the
#    trimming cut points out (1,115 such firm-years in the panel, 1,055 of them US-incorporated; found
#    in the internal review, 12 October 2026).
panel <- panel |>
  mutate(across(all_of(bs_items),   ~ if_else(at > 0, .x / at, NA_real_), .names = "{.col}_at"),
         across(all_of(flow_items), ~ if_else(at > 0, .x / at, NA_real_), .names = "{.col}_at"),
         across(all_of(flow_items), ~ if_else(na > 0, .x / na, NA_real_), .names = "{.col}_na"))
sum(panel$at == 0)

# ---------------------------------------------------------------------------------------------
# 8. Trimming happens per exhibit, not here. The paper trimmed each ratio at the most extreme 0.5 per
#    cent in each tail of its own sample; each table and figure therefore trims the sample it covers,
#    population and window (code/00_helpers.R, trim_tails(); docs/DECISIONS.md F3). The panel keeps
#    the raw ratios. Scripts 04 to 06 log what each exhibit removed to
#    data/processed/trimming_counts.csv, which starts afresh with every run.
# ---------------------------------------------------------------------------------------------
ratio_cols <- c(paste0(bs_items, "_at"), paste0(flow_items, "_at"), paste0(flow_items, "_na"))
if (file.exists(here("data", "processed", "trimming_counts.csv"))) file.remove(here("data", "processed", "trimming_counts.csv"))
panel |> summarise(across(all_of(c("def_na", "nd_na", "ne_na", "def_at")), ~ sum(!is.na(.x))))

# ---------------------------------------------------------------------------------------------
# 9. The CRSP/Compustat link (the brief's instruction): a primary link of type LC or LU covering the
#    fiscal year end. Both populations stay in the file; the flag selects the main sample.
# ---------------------------------------------------------------------------------------------
linked <- panel |>
  select(gvkey, datadate) |>
  inner_join(ccm |> mutate(linkenddt = coalesce(linkenddt, ymd("2099-12-31"))), by = "gvkey", relationship = "many-to-many") |>
  filter(datadate >= linkdt, datadate <= linkenddt) |>
  arrange(gvkey, datadate, desc(linkprim == "P"), linkdt) |>
  group_by(gvkey, datadate) |>
  slice_head(n = 1) |>
  ungroup() |>
  select(gvkey, datadate, permno = lpermno)
n_before <- nrow(panel)
panel <- panel |>
  left_join(linked, by = c("gvkey", "datadate")) |>
  mutate(ccm_linked = !is.na(permno))
stopifnot(nrow(panel) == n_before)              # one link per firm-year, so the join must not add rows
panel |> count(us_inc, ccm_linked)
attrition <- bind_rows(attrition, panel |> filter(ccm_linked, us_inc) |>
                         summarise(step = 9, rule = "main sample: a valid CRSP/Compustat link at the fiscal year end (the Compustat-only population stays in the file)",
                                   firm_years = n(), firms = n_distinct(gvkey)))
attrition

#    What the link removes from the paper's population (US-incorporated, unlinked firm-years): firms
#    CRSP never covered, fiscal years before the firm's first link (Compustat's backfilled pre-listing
#    years), fiscal years after its last link ended (post-delisting filers), and years inside a gap
#    between two links. Written for the report's Question 2 (docs/DECISIONS.md F6).
link_span <- ccm |>
  mutate(linkenddt = coalesce(linkenddt, ymd("2099-12-31"))) |>
  group_by(gvkey) |>
  summarise(first_link = min(linkdt), last_link = max(linkenddt), .groups = "drop")
link_decomposition <- panel |>
  filter(us_inc, !ccm_linked) |>
  left_join(link_span, by = "gvkey") |>
  mutate(reason = case_when(is.na(first_link) ~ "1 never linked to CRSP",
                            datadate < first_link ~ "2 fiscal year ends before the first link (pre-listing years)",
                            datadate > last_link ~ "3 fiscal year ends after the last link (post-delisting years)",
                            TRUE ~ "4 inside a gap between two links")) |>
  group_by(reason) |>
  summarise(firm_years = n(), firms = n_distinct(gvkey),
            median_assets = median(at, na.rm = TRUE),
            with_deficit_and_net_debt = sum(!is.na(def) & !is.na(nd)), .groups = "drop")
link_decomposition
write_csv(link_decomposition, here("data", "processed", "link_decomposition.csv"))

# ---------------------------------------------------------------------------------------------
# 10. CRSP market capitalisation at the last December on or before the fiscal year end, where
#     linked, as the check on the Compustat measure (the size sorts themselves are formed in
#     script 06 within the sample each regression uses)
# ---------------------------------------------------------------------------------------------
n_before <- nrow(panel)
panel <- panel |>
  mutate(dec_year = if_else(month(datadate) == 12, year(datadate), year(datadate) - 1L)) |>
  left_join(crsp_dec |> mutate(dec_year = year(date), mcap_crsp = abs(prc) * shrout / 1000) |>
              select(permno, dec_year, mcap_crsp),
            by = c("permno", "dec_year"))
stopifnot(nrow(panel) == n_before)              # one December row per permno and year
panel |> summarise(with_crsp_mcap = sum(!is.na(mcap_crsp)), linked = sum(ccm_linked))

# ---------------------------------------------------------------------------------------------
# 11. Checks against the paper's own counts. Tables 1 and 2 print N for seven years; the regression
#     samples of Table 3 column (4) (1971 to 1989, N 89,883) and Table 4 column (4) (1990 to 1998,
#     N 57,687) add to 147,570 firm-years with a deficit and net debt issued for 1971 to 1998.
#     (Table 9's N of about 115,000 is not the population: it is below the Table 1 counts summed
#     over the years, and the paper does not say what it excludes.)
# ---------------------------------------------------------------------------------------------
n_orig <- panel |> filter(us_inc, fyear <= 1998, !is.na(def_na), !is.na(nd_na)) |> nrow()   # untrimmed, so a little above the regression N
n_orig
stopifnot("more than 25 per cent away from the paper's 1971 to 1998 regression count" = abs(n_orig / 147570 - 1) < 0.25)

paper_years <- tibble(fyear = c(1971, 1975, 1980, 1985, 1990, 1995, 1998),
                      table1_n = c(2833, 4889, 4639, 5305, 5243, 7368, 7301),
                      table2_n = c(2823, 4838, 4561, 5129, 5069, 7052, 6931))
panel |>
  filter(us_inc) |>
  group_by(fyear) |>
  summarise(n_all = n(), n_linked = sum(ccm_linked), n_def = sum(!is.na(def_at))) |>
  inner_join(paper_years, by = "fyear")

# The identity: with the paper's recoding, DEF = net debt issued + net equity issued in its Table 2
identity <- panel |>
  filter(us_inc, !is.na(def), !is.na(nxt)) |>
  group_by(fmt) |>
  summarise(firm_years = n(),
            exact_share  = mean(abs(def - nxt) < 0.001),
            within_1pct  = mean(abs(def - nxt) <= 0.01 * pmax(abs(def), abs(nxt), 1)),
            corr_def_nxt = cor(def, nxt))
identity
write_csv(identity, here("data", "processed", "identity_check.csv"))

# The deflator: the Table 9 means of book assets, sales and book debt are in 1992 dollars (657.18,
# 714.20, 180.93 for 1971 to 1998, trimmed). Both deflators are measured; docs/DECISIONS.md records
# the choice. Nothing printed in the report depends on it.
deflator_check <- panel |>
  filter(us_inc, fyear <= 1998) |>
  left_join(deflators |> select(year, cpi_1992, gdpdef_1992), by = c("fyear" = "year")) |>
  mutate(at_cpi = at / cpi_1992, at_gdp = at / gdpdef_1992,
         sale_cpi = sale / cpi_1992, sale_gdp = sale / gdpdef_1992,
         bdebt_cpi = bdebt / cpi_1992, bdebt_gdp = bdebt / gdpdef_1992) |>
  select(at_cpi, at_gdp, sale_cpi, sale_gdp, bdebt_cpi, bdebt_gdp) |>
  mutate(across(everything(), ~ if_else(.x < quantile(.x, 0.005, na.rm = TRUE) | .x > quantile(.x, 0.995, na.rm = TRUE), NA_real_, .x))) |>
  summarise(across(everything(), ~ mean(.x, na.rm = TRUE))) |>
  pivot_longer(everything(), names_to = c("variable", "deflator"), names_sep = "_", values_to = "mean_1992_dollars") |>
  mutate(paper = case_when(variable == "at" ~ 657.18, variable == "sale" ~ 714.20, variable == "bdebt" ~ 180.93))
deflator_check
write_csv(deflator_check, here("data", "processed", "deflator_check.csv"))

# ---------------------------------------------------------------------------------------------
# 12. Save the panel, the attrition table and the counts
# ---------------------------------------------------------------------------------------------
write_csv(panel,     here("data", "processed", "panel_1971_2025.csv"))
write_csv(attrition, here("data", "processed", "sample_attrition.csv"))
write_csv(recoding,  here("data", "processed", "recoding_counts.csv"))

# ---------------------------------------------------------------------------------------------
# 13. The extracts on disk against the manifest of record (docs/data_manifest.csv, written once by
#     manifest_rows() from the extracts the results rest on). The same row counts, checksums, rows per
#     fiscal year and column sums are recomputed here and compared line by line, so that a later pull
#     shows WHERE it differs rather than failing on a checksum: Compustat is revised, and a fresh pull
#     is expected to differ at the margin. The manifest itself is never overwritten here.
# ---------------------------------------------------------------------------------------------
reference <- read_csv(here("docs", "data_manifest.csv"), col_types = cols(.default = "c"))
check <- manifest_rows(funda, footnotes, company, ccm, crsp_dec) |>
  rename(on_disk = value) |>
  full_join(reference |> rename(reference = value), by = c("file", "key")) |>
  mutate(status = case_when(is.na(reference) ~ "NEW", is.na(on_disk) ~ "MISSING",
                            on_disk == reference ~ "PASS", TRUE ~ "DIFF"))
check |> count(file, status) |> print(n = Inf)
check |> filter(status != "PASS") |> print(n = 40)
writeLines(c("# Data manifest check: the extracts on disk against docs/data_manifest.csv",
             "",
             paste0("Run of script 03 on ", format(Sys.Date(), "%d %B %Y"), ". Every line of the manifest of record is recomputed for the files"),
             "on disk; PASS means identical. A DIFF on a checksum with PASS on every count means the bytes differ but the",
             "content does not (for instance an unsorted file); a DIFF on a fiscal year's rows or sums says where a later",
             "pull differs from the extracts the results of record rest on.",
             "",
             "| File | PASS | DIFF | NEW | MISSING |", "|---|---|---|---|---|",
             check |> count(file, status) |> pivot_wider(names_from = status, values_from = n, values_fill = 0) |>
               (\(x) { for (s in c("PASS", "DIFF", "NEW", "MISSING")) if (!s %in% names(x)) x[[s]] <- 0; x })() |>
               (\(x) paste0("| ", x$file, " | ", x$PASS, " | ", x$DIFF, " | ", x$NEW, " | ", x$MISSING, " |"))(),
             "",
             if (all(check$status == "PASS")) "Every line PASSES: the extracts on disk are the extracts of record." else
               c("Lines that differ (on disk against the reference):", "",
                 "| File | Key | On disk | Reference | Status |", "|---|---|---|---|---|",
                 check |> filter(status != "PASS") |>
                   (\(x) paste0("| ", x$file, " | ", x$key, " | ", x$on_disk, " | ", x$reference, " | ", x$status, " |"))())),
           here("docs", "data_manifest_check.md"))
writeLines(c("# Sample construction: the paper's screens in order, with the count after each",
             "",
             "Frank and Goyal (2003), Section 3, applied to Compustat fundamentals for fiscal years 1971 to 2025.",
             "The CRSP/Compustat link (step 9) is the brief's instruction, not the paper's; the unlinked firm-years",
             "stay in the panel with `ccm_linked = FALSE`, so the all-Compustat population (linked and unlinked) is reported beside the main sample.",
             "",
             "| Step | Screen | Firm-years | Firms |", "|---|---|---|---|",
             paste0("| ", attrition$step, " | ", attrition$rule, " | ", format(attrition$firm_years, big.mark = ","),
                    " | ", format(attrition$firms, big.mark = ","), " |"),
             "",
             paste0("Cells recoded to zero (the paper's rule): ", nrow(recoding), " items, ",
                    format(sum(recoding$cells_recoded_to_zero), big.mark = ","), " cells in all; `data/processed/recoding_counts.csv`."),
             "Trimming at 0.5 per cent in each tail is applied by each table and figure to the sample it covers (population and window); what each removed is in `data/processed/trimming_counts.csv` (scripts 04 to 06)."),
           here("docs", "sample_construction.md"))
