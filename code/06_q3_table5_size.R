# 06. Question 3: the disaggregated deficit (Table 5) and the size splits
#
# Table 5 enters the four components of the financing deficit separately: cash dividends, investments,
# change in working capital and internal cash flow, each over net assets. The paper writes the equation
# with minus beta_C on cash flow but prints the estimated coefficient with its sign (column (4):
# -0.190), so the printed value compares to our estimate directly. The size splits estimate the
# Question 2 regression within market-capitalisation terciles (the brief) and total-asset quartiles
# (the paper's Table 6 sort), by period; the quartiles are also run on the paper's own two windows so
# that its printed columns have a like-for-like. The size groups are formed within fiscal year on the
# firm-years that enter the regression, separately for each population, so that the groups are
# balanced. Both populations (the linked main sample and the all-Compustat population) throughout.
# Standard errors clustered by firm (fixest, as in script 05).
#
# Trimming (docs/DECISIONS.md F3): each exhibit trims its ratios within the sample it covers, the
# paper's sub-windows with cut points from 1971 to 1998 (code/00_helpers.R, exhibit_sample()).
# Two additions beside the brief's sorts: terciles on the PRIOR fiscal year's market capitalisation
# (a fiscal-year-end value moves the year's equity issuers up the ranking), and a formal test of the
# large-minus-small gap and of its change after 1998.
#
# Inputs:  data/processed/panel_1971_2025.csv (script 03)
#          data/raw/paper/table5_original.csv, table6_original.csv (the printed values)
# Outputs: output/tables/table_5_replicated.csv, table_5_deficit_required.csv, table_q3_size_terciles.csv,
#          table_q3_size_quartiles.csv, table_q3_size_terciles_crsp_check.csv, table_q3_size_gap_test.csv

source("code/00_packages.R")   # installs any missing package first (see that file)
library(tidyverse)
library(here)
library(fixest)
source(here("code", "00_helpers.R"))

panel <- read_csv(here("data", "processed", "panel_1971_2025.csv"), col_types = cols(gvkey = "c", .default = col_guess())) |>
  arrange(gvkey, fyear) |>
  group_by(gvkey) |>
  mutate(mcap_lag = if_else(lag(fyear) == fyear - 1, lag(mcap), NA_real_)) |>   # the prior fiscal year's market value, where the firm reported it
  ungroup()
table5_original <- read_csv(here("data", "raw", "paper", "table5_original.csv"))
table6_original <- read_csv(here("data", "raw", "paper", "table6_original.csv"))

periods <- tribble(
  ~period,      ~from, ~to,   ~cut_from, ~cut_to, ~role,
  "1971-2025",  1971,  2025,  1971,      2025,    "brief",
  "1971-1998",  1971,  1998,  1971,      1998,    "brief",
  "1999-2025",  1999,  2025,  1999,      2025,    "brief",
  "1971-1989",  1971,  1989,  1971,      1998,    "paper Table 5 column (4); Table 6 columns (4) to (7)",
  "1990-1998",  1990,  1998,  1971,      1998,    "paper Table 6 columns (8) to (11)")

both <- bind_rows(panel |> filter(ccm_linked, us_inc) |> mutate(population = "main"),
                  panel |> filter(us_inc) |> mutate(population = "compustat_all"))
both |> count(population)
component_vars <- c("nd_na", "div_na", "inv_na", "dwc_na", "cf_na")
debt_vars <- c("def_na", "nd_na")

# ---------------------------------------------------------------------------------------------
# 1. Table 5: the four components, one regression per population and window. The sample is every
#    firm-year with net debt issued and the four components after trimming; the deficit itself is
#    not required, so a firm-year whose deficit was trimmed but whose components survived stays in.
#    The alternative reading (docs/DECISIONS.md F13), the deficit also required, follows.
# ---------------------------------------------------------------------------------------------
table5 <- tibble(); table5_alt <- tibble()
for (pop in c("main", "compustat_all")) {
  for (i in 1:4) {
    d <- exhibit_sample(both |> filter(population == pop), periods$from[i], periods$to[i], periods$cut_from[i], periods$cut_to[i],
                        c(component_vars, "def_na"), paste0("Table 5 components: ", pop, ", ", periods$period[i]))
    dc <- d |> filter(if_all(all_of(component_vars), ~ !is.na(.x)))
    m <- feols(nd_na ~ div_na + inv_na + dwc_na + cf_na, data = dc, cluster = ~gvkey)
    table5 <- bind_rows(table5, tibble(
      population = pop, period = periods$period[i], role = periods$role[i], n = nobs(m), r2 = r2(m, "r2"),
      a = coef(m)["(Intercept)"], a_se = se(m)["(Intercept)"],
      div = coef(m)["div_na"], div_se = se(m)["div_na"],
      inv = coef(m)["inv_na"], inv_se = se(m)["inv_na"],
      dwc = coef(m)["dwc_na"], dwc_se = se(m)["dwc_na"],
      cf  = coef(m)["cf_na"],  cf_se  = se(m)["cf_na"]))
    da <- dc |> filter(!is.na(def_na))
    m <- feols(nd_na ~ div_na + inv_na + dwc_na + cf_na, data = da, cluster = ~gvkey)
    table5_alt <- bind_rows(table5_alt, tibble(
      population = pop, period = periods$period[i], n = nobs(m), r2 = r2(m, "r2"),
      div = coef(m)["div_na"], inv = coef(m)["inv_na"], dwc = coef(m)["dwc_na"], cf = coef(m)["cf_na"]))
  }
}

# The printed column (4) of Table 5 attached to the paper's window
printed5 <- tibble(period = "1971-1989",
                   printed_div = as.numeric(table5_original$c4[table5_original$row == "div"]),
                   printed_inv = as.numeric(table5_original$c4[table5_original$row == "inv"]),
                   printed_dwc = as.numeric(table5_original$c4[table5_original$row == "dwc"]),
                   printed_cf  = as.numeric(table5_original$c4[table5_original$row == "cf"]),
                   printed_n   = as.numeric(table5_original$c4[table5_original$row == "n"]),
                   printed_r2  = as.numeric(table5_original$c4[table5_original$row == "r2"]))
table5 <- table5 |> left_join(printed5, by = "period")
table5 |> select(population, period, div, inv, dwc, cf, n, r2, printed_div, printed_inv, printed_dwc, printed_cf, printed_n, printed_r2) |> print(n = Inf, width = Inf)
write_csv(table5, here("output", "tables", "table_5_replicated.csv"))
table5_alt |> print(n = Inf, width = Inf)
write_csv(table5_alt, here("output", "tables", "table_5_deficit_required.csv"))

# ---------------------------------------------------------------------------------------------
# 2. Size splits: the Question 2 regression within size groups formed within fiscal year on the
#    firm-years of each exhibit's regression sample, by population and period
# ---------------------------------------------------------------------------------------------
size_samples <- list()
for (pop in c("main", "compustat_all")) {
  for (i in 2:5) {
    size_samples[[paste(pop, periods$period[i])]] <-
      exhibit_sample(both |> filter(population == pop), periods$from[i], periods$to[i], periods$cut_from[i], periods$cut_to[i],
                     debt_vars, paste0("Table 6 size sorts: ", pop, ", ", periods$period[i])) |>
      filter(if_all(all_of(debt_vars), ~ !is.na(.x))) |>
      group_by(fyear) |>
      mutate(mcap_tercile      = ntile(if_else(mcap > 0, mcap, NA_real_), 3),
             mcap_lag_tercile  = ntile(if_else(mcap_lag > 0, mcap_lag, NA_real_), 3),
             mcap_same_tercile = ntile(if_else(mcap > 0 & mcap_lag > 0, mcap, NA_real_), 3),   # the fiscal-year-end sort on the firm-years the lagged sort can use
             at_quartile       = ntile(at, 4)) |>
      ungroup()
  }
}
size_samples[["main 1971-1998"]] |> filter(fyear %in% c(1975, 1998)) |> count(fyear, mcap_tercile)

#    (a) market-capitalisation terciles, bottom and top, the brief's two periods, on the fiscal-year-end
#        market value (the brief), on the prior year's (the check on the timing), and on the
#        fiscal-year-end value restricted to the firm-years that have a prior year (so that the
#        lagged sort is compared on the same firm-years, not on a sample without first-year firms)
sorts <- c(mcap_tercile = "market cap at the fiscal year end", mcap_lag_tercile = "market cap at the prior fiscal year end",
           mcap_same_tercile = "market cap at the fiscal year end, firm-years with a prior year")
group_tags <- c(mcap_tercile = "market cap)", mcap_lag_tercile = "lagged market cap)", mcap_same_tercile = "market cap, firm-years with a prior year)")
terciles <- tibble()
for (pop in c("main", "compustat_all")) {
  for (i in 2:3) {
    for (sort_on in names(sorts)) {
      for (g in c(1, 3)) {
        d <- size_samples[[paste(pop, periods$period[i])]] |> filter(.data[[sort_on]] == g)
        m <- feols(nd_na ~ def_na, data = d, cluster = ~gvkey)
        terciles <- bind_rows(terciles, tibble(
          population = pop, period = periods$period[i],
          sort = sorts[[sort_on]],
          group = paste0(if_else(g == 1, "small (bottom tercile, ", "large (top tercile, "), group_tags[[sort_on]]),
          a = coef(m)["(Intercept)"], b = coef(m)["def_na"], b_se = se(m)["def_na"], b_t = tstat(m)["def_na"],
          n = nobs(m), firms = n_distinct(d$gvkey), r2 = r2(m, "r2")))
      }
    }
  }
}
terciles |> print(n = Inf, width = Inf)
write_csv(terciles, here("output", "tables", "table_q3_size_terciles.csv"))

#    (b) total-asset quartiles, all four, the brief's two periods and the paper's two windows, with
#        the printed Table 6 columns (4) to (11) attached to the paper's windows
quartile_names <- c("smallest quartile (assets)", "medium small quartile (assets)", "medium large quartile (assets)", "largest quartile (assets)")
quartiles <- tibble()
for (pop in c("main", "compustat_all")) {
  for (i in 2:5) {
    for (g in 1:4) {
      d <- size_samples[[paste(pop, periods$period[i])]] |> filter(at_quartile == g)
      m <- feols(nd_na ~ def_na, data = d, cluster = ~gvkey)
      quartiles <- bind_rows(quartiles, tibble(
        population = pop, period = periods$period[i], role = periods$role[i], group = quartile_names[g],
        a = coef(m)["(Intercept)"], b = coef(m)["def_na"], b_se = se(m)["def_na"], b_t = tstat(m)["def_na"],
        n = nobs(m), firms = n_distinct(d$gvkey), r2 = r2(m, "r2")))
    }
  }
}
printed6 <- tibble(period = rep(c("1971-1989", "1990-1998"), each = 4),
                   group = rep(quartile_names, 2),
                   printed_b  = as.numeric(unlist(table6_original[table6_original$row == "def", paste0("c", 4:11)])),
                   printed_n  = as.numeric(unlist(table6_original[table6_original$row == "n",   paste0("c", 4:11)])),
                   printed_r2 = as.numeric(unlist(table6_original[table6_original$row == "r2",  paste0("c", 4:11)])))
quartiles <- quartiles |> left_join(printed6, by = c("period", "group"))
quartiles |> select(population, period, group, b, b_se, n, r2, printed_b, printed_n, printed_r2) |> print(n = Inf, width = Inf)
write_csv(quartiles, here("output", "tables", "table_q3_size_quartiles.csv"))

#    (c) the large-minus-small gap in b and its change after 1998: the two period samples joined, the
#        regression interacted with a large indicator and a post-1998 indicator, firm-clustered. The
#        gap in each period and the change are read off the interactions.
gap_test <- tibble()
for (pop in c("main", "compustat_all")) {
  d <- bind_rows(size_samples[[paste(pop, "1971-1998")]], size_samples[[paste(pop, "1999-2025")]]) |>
    filter(mcap_tercile %in% c(1, 3)) |>
    mutate(large = as.integer(mcap_tercile == 3), post = as.integer(fyear > 1998))
  m  <- feols(nd_na ~ def_na * large * post, data = d, cluster = ~gvkey)
  m2 <- feols(nd_na ~ def_na * large * post, data = d, cluster = ~ gvkey + fyear)   # the change after 1998 is a year-level event too
  v <- vcov(m); v2 <- vcov(m2)
  gap_pre <- "def_na:large"; change <- "def_na:large:post"
  gap_test <- bind_rows(gap_test, tibble(
    population = pop, sort = "market cap terciles, bottom against top",
    b_small_pre = coef(m)["def_na"], gap_1971_1998 = coef(m)[gap_pre], gap_se_1971_1998 = se(m)[gap_pre], gap_t_1971_1998 = tstat(m)[gap_pre],
    gap_1999_2025 = coef(m)[gap_pre] + coef(m)[change],
    gap_se_1999_2025 = sqrt(v[gap_pre, gap_pre] + v[change, change] + 2 * v[gap_pre, change]),
    change_after_1998 = coef(m)[change], change_se = se(m)[change], change_t = tstat(m)[change],
    change_se_twoway = se(m2)[change], change_t_twoway = tstat(m2)[change],
    gap_se_1999_2025_twoway = sqrt(v2[gap_pre, gap_pre] + v2[change, change] + 2 * v2[gap_pre, change]), n = nobs(m)))
}
gap_test <- gap_test |> mutate(gap_t_1999_2025 = gap_1999_2025 / gap_se_1999_2025, gap_t_1999_2025_twoway = gap_1999_2025 / gap_se_1999_2025_twoway)
gap_test |> print(width = Inf)
write_csv(gap_test, here("output", "tables", "table_q3_size_gap_test.csv"))

# ---------------------------------------------------------------------------------------------
# 3. The CRSP market-capitalisation check on the tercile sort (December value per permno, where
#    linked; a firm with two share classes is understated), main sample
# ---------------------------------------------------------------------------------------------
crsp_terciles <- tibble()
for (i in 2:3) {
  crsp_sorted <- size_samples[[paste("main", periods$period[i])]] |>
    filter(!is.na(mcap_crsp), mcap_crsp > 0) |>
    group_by(fyear) |>
    mutate(crsp_tercile = ntile(mcap_crsp, 3)) |>
    ungroup()
  print(crsp_sorted |> filter(!is.na(mcap_tercile)) |> summarise(period = periods$period[i], share_same_tercile = mean(crsp_tercile == mcap_tercile)))
  for (g in c(1, 3)) {
    d <- crsp_sorted |> filter(crsp_tercile == g)
    m <- feols(nd_na ~ def_na, data = d, cluster = ~gvkey)
    crsp_terciles <- bind_rows(crsp_terciles, tibble(
      period = periods$period[i], group = if_else(g == 1, "small (bottom tercile, CRSP market cap)", "large (top tercile, CRSP market cap)"),
      b = coef(m)["def_na"], b_se = se(m)["def_na"], n = nobs(m), r2 = r2(m, "r2")))
  }
}
crsp_terciles
write_csv(crsp_terciles, here("output", "tables", "table_q3_size_terciles_crsp_check.csv"))
