# 05. Questions 2 and 4: the pecking order regression (Table 3), the equity regression, the formal
#     test of the two sensitivities, the year-by-year coefficients, and the structural-break tests
#
# Net debt issued over net assets regressed on the financing deficit over net assets, pooled OLS with
# standard errors clustered by firm (the brief asks for clustering; fixest is used for that, as in
# Assessment Task 2), for 1971 to 2025, 1971 to 1998 and 1999 to 2025. The paper's Table 3 covers
# 1971 to 1989 and its Table 4 covers 1990 to 1998, so those two windows are estimated as well, with
# the paper's plain standard errors beside the clustered ones and the printed column (4) of each
# table attached for the like-for-like comparison. Every regression is run on two populations: the
# main sample (a CRSP/Compustat link at the fiscal year end, the brief's instruction) and the
# all-Compustat population (linked and unlinked together, the paper's own), both US-incorporated.
# The equity regression uses net equity issued as the dependent variable. The debt-against-equity
# comparison and the test of c greater than b use one common sample (deficit, net debt and net equity
# all present), because the two dependent variables are trimmed separately and the separate samples
# make b + c read 0.94 instead of 1.
#
# Trimming (docs/DECISIONS.md F3): each exhibit trims its two (or three) ratios at the most extreme
# 0.5 per cent in each tail of the sample it covers; the paper's sub-windows take their cut points
# from 1971 to 1998, as the paper did (code/00_helpers.R, exhibit_sample()). Three sensitivities sit
# beside the main rows: cut points set inside the sub-window itself, cut points set over 1971 to 2025
# (the rule of an earlier version of this project), and the country screen left out.
#
# Inputs:  data/processed/panel_1971_2025.csv (script 03); output/tables/table_1_replicated.csv (script 04)
#          data/raw/paper/table3_original.csv, table4_original.csv (the printed values)
# Outputs: output/tables/table_3_replicated.csv, table_3_trimming_sensitivity.csv, table_3_no_gaps.csv,
#          table_q2_country_screen.csv, table_b_populations.csv,
#          table_q4_debt_vs_equity.csv, table_q4_test.csv, table_q4_annual_coefficients.csv,
#          table_q1_chow.csv, table_q1_break_search.csv, table_q1_balanced_1977_1982.csv
#          data/processed/regression_attrition.csv
#          output/figures/figure_q4_annual_coefficients.png, figure_q1_break_search.png

source("code/00_packages.R")   # installs any missing package first (see that file)
library(tidyverse)
library(here)
library(fixest)
source(here("code", "00_helpers.R"))

panel <- read_csv(here("data", "processed", "panel_1971_2025.csv"), col_types = cols(gvkey = "c", .default = col_guess()))
table1 <- read_csv(here("output", "tables", "table_1_replicated.csv"), show_col_types = FALSE)
table3_original <- read_csv(here("data", "raw", "paper", "table3_original.csv"))
table4_original <- read_csv(here("data", "raw", "paper", "table4_original.csv"))

# The windows: the brief's three, and the paper's two, whose cut points come from the paper's sample
periods <- tribble(
  ~period,      ~from, ~to,   ~cut_from, ~cut_to, ~role,
  "1971-2025",  1971,  2025,  1971,      2025,    "brief",
  "1971-1998",  1971,  1998,  1971,      1998,    "brief",
  "1999-2025",  1999,  2025,  1999,      2025,    "brief",
  "1971-1989",  1971,  1989,  1971,      1998,    "paper Table 3 column (4)",
  "1990-1998",  1990,  1998,  1971,      1998,    "paper Table 4 column (4)")

# The populations in one data frame: the two the report uses, and the linked sample without the
# country screen for the sensitivity rows
both <- bind_rows(panel |> filter(ccm_linked, us_inc) |> mutate(population = "main"),
                  panel |> filter(us_inc)             |> mutate(population = "compustat_all"),
                  panel |> filter(ccm_linked)         |> mutate(population = "linked_all_countries"))
both |> count(population)
debt_vars   <- c("def_na", "nd_na")
common_vars <- c("def_na", "nd_na", "ne_na")

# ---------------------------------------------------------------------------------------------
# 1. Table 3: net debt issued on the deficit, each population and window, on the firm-years that
#    have both variables after trimming (the paper's own sample rule for this table). The firm-years
#    of the window that do not reach the regression are counted by cause as they go: net assets
#    missing (no current liabilities), net assets not positive, net debt issued missing (dltis),
#    internal cash flow missing (ibc, so no deficit; the other components are recoded), the deficit
#    ratio trimmed, the net-debt ratio trimmed.
# ---------------------------------------------------------------------------------------------
table3 <- tibble(); attrition <- tibble()
for (pop in c("main", "compustat_all", "linked_all_countries")) {
  for (i in 1:nrow(periods)) {
    if (pop == "linked_all_countries" && i > 3) next
    d <- exhibit_sample(both |> filter(population == pop), periods$from[i], periods$to[i], periods$cut_from[i], periods$cut_to[i],
                        debt_vars, paste0("Table 4 debt regression: ", pop, ", ", periods$period[i]))
    attrition <- bind_rows(attrition, d |> summarise(
      population = pop, period = periods$period[i], firm_years = n(),
      net_assets_missing      = sum(is.na(na)),
      net_assets_not_positive = sum(na <= 0, na.rm = TRUE),
      net_debt_missing        = sum(na > 0 & is.na(nd), na.rm = TRUE),
      cash_flow_missing       = sum(na > 0 & !is.na(nd) & is.na(def), na.rm = TRUE),
      eligible                = sum(na > 0 & !is.na(nd) & !is.na(def), na.rm = TRUE),
      deficit_ratio_trimmed   = sum(na > 0 & !is.na(nd) & !is.na(def) & is.na(def_na), na.rm = TRUE),
      net_debt_ratio_trimmed  = sum(na > 0 & !is.na(nd) & !is.na(def) & !is.na(def_na) & is.na(nd_na), na.rm = TRUE),
      regression_n            = sum(!is.na(def_na) & !is.na(nd_na))))
    d <- d |> filter(if_all(all_of(debt_vars), ~ !is.na(.x)))
    m <- feols(nd_na ~ def_na, data = d, cluster = ~gvkey)
    table3 <- bind_rows(table3, tibble(
      population = pop, period = periods$period[i], role = periods$role[i],
      a = coef(m)["(Intercept)"], a_se_cluster = se(m)["(Intercept)"],
      b = coef(m)["def_na"], b_se_cluster = se(m)["def_na"], b_t_cluster = tstat(m)["def_na"],
      b_se_plain = se(m, vcov = "iid")["def_na"],
      n = nobs(m), firms = n_distinct(d$gvkey), r2 = r2(m, "r2")))
  }
}
stopifnot(all(attrition$eligible - attrition$deficit_ratio_trimmed - attrition$net_debt_ratio_trimmed == attrition$regression_n))
attrition |> print(n = Inf, width = Inf)
write_csv(attrition, here("data", "processed", "regression_attrition.csv"))

# The printed column (4) of Tables 3 and 4 attached to the paper's own windows
printed <- tibble(period = c("1971-1989", "1990-1998"),
                  printed_a    = c(table3_original$c4[table3_original$row == "constant"], table4_original$c4[table4_original$row == "constant"]),
                  printed_b    = c(table3_original$c4[table3_original$row == "def"],      table4_original$c4[table4_original$row == "def"]),
                  printed_b_se = c(table3_original$c4[table3_original$row == "def_se"],   table4_original$c4[table4_original$row == "def_se"]),
                  printed_n    = c(table3_original$c4[table3_original$row == "n"],        table4_original$c4[table4_original$row == "n"]),
                  printed_r2   = c(table3_original$c4[table3_original$row == "r2"],       table4_original$c4[table4_original$row == "r2"])) |>
  mutate(across(starts_with("printed"), as.numeric))
country_screen <- table3 |> filter(population == "linked_all_countries") |>
  select(period, b_no_screen = b, b_se_no_screen = b_se_cluster, n_no_screen = n, firms_no_screen = firms, r2_no_screen = r2) |>
  left_join(table3 |> filter(population == "main") |> select(period, b_main = b, b_se_main = b_se_cluster, n_main = n, firms_main = firms, r2_main = r2), by = "period")
country_screen |> print(width = Inf)
write_csv(country_screen, here("output", "tables", "table_q2_country_screen.csv"))
table3 <- table3 |> filter(population != "linked_all_countries") |> left_join(printed, by = "period")
table3 |> select(population, period, b, b_se_cluster, b_se_plain, n, r2, printed_b, printed_n, printed_r2) |> print(n = Inf, width = Inf)
write_csv(table3, here("output", "tables", "table_3_replicated.csv"))

# Sensitivity to the trimming window, for the windows compared with the paper: the rule (cut points
# over 1971 to 1998), cut points set inside the sub-window itself, and cut points set over the whole
# 1971 to 2025 panel
trim_sens <- tibble()
for (pop in c("main", "compustat_all")) {
  for (i in c(2, 4, 5)) {
    variants <- list(c(periods$cut_from[i], periods$cut_to[i], "cut points over 1971 to 1998 (the rule)"),
                     c(periods$from[i], periods$to[i], "cut points inside the window"),
                     c(1971, 2025, "cut points over 1971 to 2025"))
    for (v in variants) {
      d <- exhibit_sample(both |> filter(population == pop), periods$from[i], periods$to[i], as.numeric(v[1]), as.numeric(v[2]),
                          debt_vars, paste0("Table 4 trimming sensitivity (", v[3], "): ", pop, ", ", periods$period[i])) |>
        filter(if_all(all_of(debt_vars), ~ !is.na(.x)))
      m <- feols(nd_na ~ def_na, data = d, cluster = ~gvkey)
      trim_sens <- bind_rows(trim_sens, tibble(population = pop, period = periods$period[i], variant = v[3],
                                               b = coef(m)["def_na"], b_se = se(m)["def_na"], n = nobs(m), r2 = r2(m, "r2")))
    }
  }
}
trim_sens <- trim_sens |> left_join(printed |> select(period, printed_b, printed_r2), by = "period")
trim_sens |> print(n = Inf, width = Inf)
write_csv(trim_sens, here("output", "tables", "table_3_trimming_sensitivity.csv"))

# The paper's column (1): firms with no gaps, present with both variables in every year of the window
no_gaps <- tibble()
for (pop in c("main", "compustat_all")) {
  for (i in 4:5) {
    d <- exhibit_sample(both |> filter(population == pop), periods$from[i], periods$to[i], periods$cut_from[i], periods$cut_to[i],
                        debt_vars, paste0("Table 4 no-gaps firms: ", pop, ", ", periods$period[i])) |>
      filter(if_all(all_of(debt_vars), ~ !is.na(.x)))
    firms_all_years <- d |> count(gvkey) |> filter(n == periods$to[i] - periods$from[i] + 1) |> pull(gvkey)
    d <- d |> filter(gvkey %in% firms_all_years)
    m <- feols(nd_na ~ def_na, data = d, cluster = ~gvkey)
    orig <- if (i == 4) table3_original else table4_original
    no_gaps <- bind_rows(no_gaps, tibble(population = pop, period = periods$period[i],
                                         b = coef(m)["def_na"], b_se_cluster = se(m)["def_na"], n = nobs(m), firms = length(firms_all_years), r2 = r2(m, "r2"),
                                         printed_b = as.numeric(orig$c1[orig$row == "def"]), printed_n = as.numeric(orig$c1[orig$row == "n"]),
                                         printed_r2 = as.numeric(orig$c1[orig$row == "r2"]), printed_firms = printed_n / (periods$to[i] - periods$from[i] + 1)))
  }
}
no_gaps |> print(width = Inf)
write_csv(no_gaps, here("output", "tables", "table_3_no_gaps.csv"))

# Table B of the report: the two populations beside the paper's counts (firm-years and firms of the
# regression samples; the Table 1 firm counts of three printed years)
paper_n <- c("1971-1989" = 89883, "1990-1998" = 57687)
table_b <- bind_rows(
  table3 |> filter(role == "brief") |> select(population, period, firm_years = n, firms) |>
    pivot_longer(c(firm_years, firms), names_to = "count") |>
    pivot_wider(names_from = population, values_from = value) |>
    mutate(label = paste0(if_else(count == "firm_years", "Firm-years with a deficit and net debt issued, ", "Firms, "), str_replace(period, "-", " to ")), paper = NA_real_),
  table3 |> filter(role != "brief") |> select(population, period, firm_years = n) |>
    pivot_wider(names_from = population, values_from = firm_years) |>
    mutate(count = "firm_years", label = paste0("Firm-years, ", str_replace(period, "-", " to "), " (paper N)"), paper = paper_n[period]),
  table1 |> filter(item == "n_obs") |> select(population, y1971, y1985, y1998) |>
    pivot_longer(-population, names_to = "year", values_to = "n") |>
    pivot_wider(names_from = population, values_from = n) |>
    mutate(count = "firms_table1", label = paste0("Firms in Table 1, ", str_remove(year, "y")), paper = c(y1971 = 2833, y1985 = 5305, y1998 = 7301)[year]) |>
    select(-year)) |>
  select(label, count, compustat_all, main, paper) |>
  mutate(linked_share = main / compustat_all, share_of_paper_all = compustat_all / paper, share_of_paper_main = main / paper)
table_b |> print(n = Inf, width = Inf)
write_csv(table_b, here("output", "tables", "table_b_populations.csv"))

# ---------------------------------------------------------------------------------------------
# 2. Question 4.1: debt beside equity on the common sample (deficit, net debt and net equity all
#    present after trimming), both populations and every window
# ---------------------------------------------------------------------------------------------
common_samples <- list()
debt_vs_equity <- tibble()
for (pop in c("main", "compustat_all")) {
  for (i in 1:nrow(periods)) {
    d <- exhibit_sample(both |> filter(population == pop), periods$from[i], periods$to[i], periods$cut_from[i], periods$cut_to[i],
                        common_vars, paste0("Tables 7 and 8 common sample: ", pop, ", ", periods$period[i])) |>
      filter(if_all(all_of(common_vars), ~ !is.na(.x)))
    common_samples[[paste(pop, periods$period[i])]] <- d
    for (y in c("nd_na", "ne_na")) {
      m <- feols(as.formula(paste(y, "~ def_na")), data = d, cluster = ~gvkey)
      debt_vs_equity <- bind_rows(debt_vs_equity, tibble(
        population = pop, period = periods$period[i], role = periods$role[i], dependent = y,
        a = coef(m)["(Intercept)"], a_se_cluster = se(m)["(Intercept)"],
        b = coef(m)["def_na"], b_se_cluster = se(m)["def_na"], b_t_cluster = tstat(m)["def_na"],
        n = nobs(m), r2 = r2(m, "r2")))
    }
  }
}
debt_vs_equity <- debt_vs_equity |> mutate(sample = "common (deficit, net debt and net equity all present)")
# For the record (docs/DECISIONS.md F14): the equity regression on its own sample (deficit and net
# equity present, net debt not required), the brief's windows, both populations. With the two
# dependent variables trimmed separately the two coefficients then do not add to one.
for (pop in c("main", "compustat_all")) {
  for (i in 1:3) {
    d <- exhibit_sample(both |> filter(population == pop), periods$from[i], periods$to[i], periods$cut_from[i], periods$cut_to[i],
                        c("def_na", "ne_na"), paste0("Equity regression, own sample: ", pop, ", ", periods$period[i])) |>
      filter(!is.na(def_na), !is.na(ne_na))
    m <- feols(ne_na ~ def_na, data = d, cluster = ~gvkey)
    debt_vs_equity <- bind_rows(debt_vs_equity, tibble(
      population = pop, period = periods$period[i], role = periods$role[i], dependent = "ne_na", sample = "own (deficit and net equity present)",
      a = coef(m)["(Intercept)"], a_se_cluster = se(m)["(Intercept)"],
      b = coef(m)["def_na"], b_se_cluster = se(m)["def_na"], b_t_cluster = tstat(m)["def_na"], n = nobs(m), r2 = r2(m, "r2")))
  }
}
debt_vs_equity |> select(population, period, dependent, sample, b, b_se_cluster, n, r2) |> print(n = Inf, width = Inf)
write_csv(debt_vs_equity, here("output", "tables", "table_q4_debt_vs_equity.csv"))

# ---------------------------------------------------------------------------------------------
# 3. Question 4.2: is c (equity) larger than b (debt)? The two equations stacked in one long data
#    set, with an equity indicator and its interaction with the deficit; the interaction is c - b and
#    its firm-clustered t gives the one-sided test. If the deficit equals net debt plus net equity by
#    identity, b + c = 1 and the test is the same as b < 0.5; the sum and its test against 1 are
#    reported for that reason.
# ---------------------------------------------------------------------------------------------
horse_race_test <- tibble()
for (pop in c("main", "compustat_all")) {
  for (i in 1:3) {
    d <- common_samples[[paste(pop, periods$period[i])]] |>
      select(gvkey, fyear, def_na, nd_na, ne_na) |>
      pivot_longer(c(nd_na, ne_na), names_to = "equation", values_to = "y") |>
      mutate(equity = as.integer(equation == "ne_na"))
    m <- feols(y ~ equity + def_na + def_na:equity, data = d, cluster = ~gvkey)
    v <- vcov(m)
    inter <- names(coef(m))[str_detect(names(coef(m)), ":")]        # fixest names the interaction term itself
    b <- coef(m)["def_na"]
    diff <- coef(m)[inter]
    se_sum <- sqrt(4 * v["def_na", "def_na"] + v[inter, inter] + 4 * v["def_na", inter])
    p_raw <- pt(tstat(m)[inter], df = degrees_freedom(m, type = "t"), lower.tail = FALSE)
    horse_race_test <- bind_rows(horse_race_test, tibble(
      population = pop, period = periods$period[i], b_debt = b, c_equity = b + diff,
      c_minus_b = diff, se_diff = se(m)[inter], t_diff = tstat(m)[inter],
      p_one_sided = if_else(p_raw < 0.001, "< 0.001", format(p_raw, digits = 3)),
      b_plus_c = 2 * b + diff, se_sum = se_sum, t_sum_vs_1 = (2 * b + diff - 1) / se_sum,
      firm_years = nrow(d) / 2))
  }
}
horse_race_test |> print(n = Inf, width = Inf)
write_csv(horse_race_test, here("output", "tables", "table_q4_test.csv"))

# ---------------------------------------------------------------------------------------------
# 4. Question 4.3: year-by-year b_t and c_t, 1971 to 2025, main sample, with 95 per cent bands, on
#    the two period samples joined (each trimmed within itself). Within one fiscal year each firm has
#    one row, so the "clustered" standard error is simply the heteroskedasticity-robust one.
# ---------------------------------------------------------------------------------------------
main_common <- bind_rows(common_samples[["main 1971-1998"]], common_samples[["main 1999-2025"]])
annual <- tibble()
for (yr in sort(unique(main_common$fyear))) {
  d <- main_common |> filter(fyear == yr)
  for (y in c("nd_na", "ne_na")) {
    m <- feols(as.formula(paste(y, "~ def_na")), data = d, vcov = "hetero")
    annual <- bind_rows(annual, tibble(fyear = yr, dependent = y, b = coef(m)["def_na"],
                                       b_se_robust = se(m)["def_na"], n = nobs(m), r2 = r2(m, "r2")))
  }
}
annual <- annual |> mutate(lo = b - 1.96 * b_se_robust, hi = b + 1.96 * b_se_robust)
annual |> filter(fyear %in% c(1971, 1978, 1979, 1980, 1990, 1998, 2008, 2020, 2025)) |> print(n = Inf)
write_csv(annual, here("output", "tables", "table_q4_annual_coefficients.csv"))

ggplot(annual |> mutate(dependent = recode(dependent, nd_na = "Net debt issued (b_t)", ne_na = "Net equity issued (c_t)")),
       aes(fyear, b, colour = dependent, fill = dependent)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_hline(yintercept = c(0.5, 1), colour = "grey70", linetype = "dashed") +
  geom_vline(xintercept = 1998.5, linetype = "dotted") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.3) +
  scale_x_continuous(breaks = seq(1971, 2025, by = 6)) +
  labs(x = "Fiscal year", y = "Coefficient on the financing deficit", colour = NULL, fill = NULL,
       caption = "Annual cross-sectional regressions on the common sample; bands are 95 per cent with heteroskedasticity-robust standard errors. Dotted line: end of the paper's sample.") +
  ggtitle("Sensitivity of net debt and net equity issues to the financing deficit, year by year, 1971 to 2025") +
  theme_minimal(base_size = 12) + theme(legend.position = "bottom")
ggsave(here("output", "figures", "figure_q4_annual_coefficients.png"), width = 10, height = 5.5, dpi = 200, bg = "white")

# ---------------------------------------------------------------------------------------------
# 5. Question 1.3: structural breaks in the debt regression, main sample, on the two period samples
#    joined. (a) A Chow test at the 1998/1999 split: both coefficients interacted with a post-1998
#    indicator, firm-clustered Wald; fixest::wald() returns the F form (the quadratic form divided by
#    the two restrictions), and the chi-square form (twice it) is printed beside it. For a split fixed
#    in advance the 5 per cent critical values are 3.00 (F) and 5.99 (chi-square). (b) The same test
#    on 1980 to 2025, the years after the 1979/1980 step the search below finds, so that the 1998
#    split is tested without the step inside the pre-period. (c) A break search: the same Wald
#    statistic at every candidate year from 1979 to 2017 (the middle 70 per cent of the window); the
#    largest of a search is read against Andrews (1993), 11.79 chi-square (5.90 F) for two
#    restrictions and 15 per cent trimming at 5 per cent. (d) The 1979/1980 step on a fixed set of
#    firms: annual b_t for 1977 to 1982 on the firms present in all six years, beside the unbalanced
#    estimates, to separate a change in behaviour from a change in who is in the sample.
# ---------------------------------------------------------------------------------------------
debt_samples <- list()
for (i in 2:3) {
  debt_samples[[periods$period[i]]] <- exhibit_sample(both |> filter(population == "main"), periods$from[i], periods$to[i], periods$cut_from[i], periods$cut_to[i],
                                                      debt_vars, paste0("Break tests, main, ", periods$period[i])) |>
    filter(if_all(all_of(debt_vars), ~ !is.na(.x)))
}
chow_data <- bind_rows(debt_samples) |> mutate(post = as.integer(fyear > 1998))

#    A split in time is also a year-level event, so each test is run twice: clustered by firm (the
#    convention of every regression table) and clustered by firm and fiscal year, which allows the
#    years on either side of the split to share shocks and is the more demanding reading.
chow_row <- function(d, label) {
  m  <- feols(nd_na ~ def_na * post, data = d, cluster = ~gvkey)
  m2 <- feols(nd_na ~ def_na * post, data = d, cluster = ~ gvkey + fyear)
  w  <- wald(m,  keep = "post", print = FALSE)
  w2 <- wald(m2, keep = "post", print = FALSE)
  inter <- names(coef(m))[str_detect(names(coef(m)), ":")]
  tibble(test = label, from = min(d$fyear), to = max(d$fyear),
         b_pre = coef(m)["def_na"], b_shift_post = coef(m)[inter], shift_se = se(m)[inter], shift_t = tstat(m)[inter],
         wald_F = w$stat, wald_chi2 = w$stat * w$df1, restrictions = w$df1, wald_p = w$p,
         crit_5pct_F = qf(0.95, w$df1, w$df2), crit_5pct_chi2 = qchisq(0.95, w$df1), n = nobs(m),
         shift_se_twoway = se(m2)[inter], shift_t_twoway = tstat(m2)[inter], wald_F_twoway = w2$stat, wald_p_twoway = w2$p)
}
chow <- bind_rows(chow_row(chow_data, "Chow at 1998/1999, debt regression, firm-clustered Wald, 1971 to 2025"),
                  chow_row(chow_data |> filter(fyear >= 1980), "Chow at 1998/1999, debt regression, firm-clustered Wald, 1980 to 2025 (after the 1979/1980 step)"))
chow |> print(width = Inf)
write_csv(chow, here("output", "tables", "table_q1_chow.csv"))

break_search <- tibble()
for (yr in 1979:2017) {
  d <- chow_data |> mutate(post = as.integer(fyear > yr))
  m  <- feols(nd_na ~ def_na * post, data = d, cluster = ~gvkey)
  m2 <- feols(nd_na ~ def_na * post, data = d, cluster = ~ gvkey + fyear)
  w  <- wald(m,  keep = "post", print = FALSE)
  w2 <- wald(m2, keep = "post", print = FALSE)
  break_search <- bind_rows(break_search, tibble(break_after = yr, wald_F = w$stat, wald_chi2 = w$stat * w$df1, wald_F_twoway = w2$stat,
                                                 b_shift = coef(m)[names(coef(m))[str_detect(names(coef(m)), ":")]]))
}
break_search <- break_search |> mutate(andrews_5pct_chi2 = 11.79, andrews_5pct_F = 11.79 / 2)
break_search |> arrange(desc(wald_F)) |> head(5)
break_search |> arrange(wald_F) |> head(5)
write_csv(break_search, here("output", "tables", "table_q1_break_search.csv"))

ggplot(break_search |> pivot_longer(c(wald_F, wald_F_twoway), names_to = "clustering", values_to = "wald") |>
         mutate(clustering = recode(clustering, wald_F = "clustered by firm", wald_F_twoway = "clustered by firm and fiscal year")),
       aes(break_after + 0.5, wald, colour = clustering)) +
  geom_hline(yintercept = 11.79 / 2, linetype = "dashed", colour = "grey40") +
  geom_vline(xintercept = 1998.5, linetype = "dotted") +
  geom_line(linewidth = 0.8) + geom_point(size = 1.4) +
  scale_x_continuous(breaks = seq(1980, 2018, by = 4)) +
  scale_y_log10() +
  labs(x = "Candidate break (between the year shown and the next)", y = "Wald statistic (F form, log scale)", colour = NULL,
       caption = "Dashed: Andrews (1993) 5 per cent critical value, 5.90 (F form). Dotted: the 1998/1999 split.") +
  ggtitle("Break search: the Wald statistic at every candidate break year, 1979 to 2017") +
  theme_minimal(base_size = 12) + theme(legend.position = "bottom")
ggsave(here("output", "figures", "figure_q1_break_search.png"), width = 9, height = 5, dpi = 200, bg = "white")

balanced_firms <- debt_samples[["1971-1998"]] |>
  filter(fyear >= 1977, fyear <= 1982) |>
  count(gvkey) |> filter(n == 6) |> pull(gvkey)
#    The balanced set is chosen on presence (both ratios untrimmed in all six years), so a firm with
#    one extreme year is outside it; the complement (entrants, leavers and firms with a gap or a
#    trimmed year) is estimated beside it, so that both halves of the composition claim are on record.
balanced <- tibble()
for (yr in 1977:1982) {
  d  <- debt_samples[["1971-1998"]] |> filter(fyear == yr)
  mb <- feols(nd_na ~ def_na, data = d |> filter(gvkey %in% balanced_firms), vcov = "hetero")
  mo <- feols(nd_na ~ def_na, data = d |> filter(!gvkey %in% balanced_firms), vcov = "hetero")
  balanced <- bind_rows(balanced, tibble(fyear = yr, b_balanced = coef(mb)["def_na"], se_balanced = se(mb)["def_na"], n_balanced = nobs(mb),
                                         b_other_firms = coef(mo)["def_na"], se_other_firms = se(mo)["def_na"], n_other_firms = nobs(mo)))
}
balanced <- balanced |>
  left_join(annual |> filter(dependent == "nd_na") |> select(fyear, b_all_firms = b, se_all_firms = b_se_robust, n_all_firms = n), by = "fyear") |>
  mutate(firms_in_all_six_years = length(balanced_firms))
balanced |> print(width = Inf)
write_csv(balanced, here("output", "tables", "table_q1_balanced_1977_1982.csv"))
