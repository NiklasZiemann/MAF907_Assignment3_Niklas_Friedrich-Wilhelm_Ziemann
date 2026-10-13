# 04. Question 1: Table 1 (common-size balance sheet), Table 2 (corporate cash flows), Fig. 1, the
#     period descriptives, and the annual means behind the structural-break discussion
#
# Table 1 and Table 2 of the paper average each item as a fraction of total assets across the firms
# reporting in that year, for seven selected years. They are rebuilt here for those years beside the
# printed values, extended with five later years, and summarised for the two periods the brief asks
# for (1971 to 1998, 1999 to 2025). Fig. 1 plots annual means of the deficit, net debt issued and net
# equity issued, each over net assets. The main sample requires the CRSP/Compustat link (the brief);
# the all-Compustat population, which is the paper's own, is carried alongside as a second population.
#
# Trimming (docs/DECISIONS.md F3): every ratio is trimmed at the most extreme 0.5 per cent in each
# tail of the sample the exhibit covers, population by population: the paper's years and the 1971 to
# 1998 means on 1971 to 1998, the extension years and the 1999 to 2025 means on 1999 to 2025; the
# annual series (Figures 1 to 3) and the two-period descriptives (Table 3) use the same two trimmed
# windows joined, so that Figure 1 is the first part of Figure 2 exactly.
#
# Inputs:  data/processed/panel_1971_2025.csv (script 03)
#          data/raw/paper/table1_original.csv, table2_original.csv, fig1_original.csv (the printed values)
# Outputs: output/tables/table_1_replicated.csv, table_1_comparison.csv, table_1_similarity.csv,
#          table_1_negative_equity_by_link.csv
#          output/tables/table_2_replicated.csv, table_2_comparison.csv, table_2_similarity.csv
#          output/tables/figure_1_points.csv, figure_1_comparison.csv
#          output/tables/table_q1_period_descriptives.csv, table_q1_annual_means.csv
#          output/figures/figure_1_1971_1998.png, figure_1_1971_2025.png, figure_q1_annual_means.png
#          data/processed/trimming_counts.csv (started here, continued by scripts 05 and 06)

source("code/00_packages.R")   # installs any missing package first (see that file)
library(tidyverse)
library(here)
library(fixest)
source(here("code", "00_helpers.R"))

panel  <- read_csv(here("data", "processed", "panel_1971_2025.csv"), col_types = cols(gvkey = "c", .default = col_guess()))
table1_original <- read_csv(here("data", "raw", "paper", "table1_original.csv"))
table2_original <- read_csv(here("data", "raw", "paper", "table2_original.csv"))
fig1_original   <- read_csv(here("data", "raw", "paper", "fig1_original.csv"))

paper_years <- c(1971, 1975, 1980, 1985, 1990, 1995, 1998)
extra_years <- c(2005, 2010, 2015, 2020, 2025)

bs_rows   <- c("ch", "ivst", "rect", "invt", "aco", "act", "ppent", "ivaeq", "ivao", "intan", "ao", "at",
               "dlc", "ap", "txp", "lco", "lct", "dltt", "lo", "txditc", "mib", "lt", "pstk", "ceq", "seq", "total_lse")
flow_rows <- c("div", "inv", "dwc", "cf", "def", "nd", "ne", "nxt")
ratio_vars <- c(paste0(setdiff(bs_rows, c("at", "total_lse")), "_at"), paste0(flow_rows, "_at"),
                "def_na", "nd_na", "ne_na", "gd_na")

# The two populations in one data frame: the main sample (linked, US-incorporated) and the paper's own
# (all Compustat, US-incorporated, linked and unlinked together), each trimmed within its two windows
both <- bind_rows(panel |> filter(ccm_linked, us_inc) |> mutate(population = "main"),
                  panel |> filter(us_inc) |> mutate(population = "compustat_all")) |>
  mutate(period = if_else(fyear <= 1998, "p1971_1998", "p1999_2025"),
         at_at = 1, total_lse_at = 1)
both <- bind_rows(
  trim_tails(both |> filter(population == "main",          period == "p1971_1998"), ratio_vars, "Tables 1 to 3, Figures 1 to 3: main, 1971-1998"),
  trim_tails(both |> filter(population == "main",          period == "p1999_2025"), ratio_vars, "Tables 1 to 3, Figures 1 to 3: main, 1999-2025"),
  trim_tails(both |> filter(population == "compustat_all", period == "p1971_1998"), ratio_vars, "Tables 1 and 2: all Compustat, 1971-1998"),
  trim_tails(both |> filter(population == "compustat_all", period == "p1999_2025"), ratio_vars, "Tables 1 and 2: all Compustat, 1999-2025"))
both |> count(population, period)
read_csv(here("data", "processed", "trimming_counts.csv"), show_col_types = FALSE) |>
  filter(variable %in% c("ceq_at", "cf_at", "def_na")) |> select(exhibit, variable, lower, upper, before, removed, share_removed)

# ---------------------------------------------------------------------------------------------
# 1. Table 1: the 27 rows, mean of each item over total assets, by year and by period
# ---------------------------------------------------------------------------------------------
table1_years <- both |>
  filter(fyear %in% c(paper_years, extra_years)) |>
  group_by(population, column = paste0("y", fyear)) |>
  summarise(n_obs = n(), across(all_of(paste0(bs_rows, "_at")), ~ mean(.x, na.rm = TRUE)), .groups = "drop")
table1_periods <- both |>
  group_by(population, column = period) |>
  summarise(n_obs = n(), across(all_of(paste0(bs_rows, "_at")), ~ mean(.x, na.rm = TRUE)), .groups = "drop")

table1 <- bind_rows(table1_years, table1_periods) |>
  pivot_longer(-c(population, column), names_to = "item") |>
  mutate(item = str_remove(item, "_at$"),
         item = factor(item, levels = c("n_obs", bs_rows))) |>
  pivot_wider(names_from = column, values_from = value) |>
  arrange(population, item) |>
  select(population, item, all_of(paste0("y", paper_years)), all_of(paste0("y", extra_years)), p1971_1998, p1999_2025)
table1 |> filter(population == "main") |> print(n = Inf, width = Inf)
write_csv(table1, here("output", "tables", "table_1_replicated.csv"))

# Beside the printed values: the gap per cell, and how many cells sit within 0.01 and within 10 per
# cent. The two identity rows (total assets, total liabilities and equity) are 1.000 by construction
# and are left out of the shares, so that every counted cell can miss.
table1_comparison <- table1 |>
  select(population, item, all_of(paste0("y", paper_years))) |>
  pivot_longer(-c(population, item), names_to = "year", values_to = "replicated") |>
  inner_join(table1_original |> pivot_longer(-item, names_to = "year", values_to = "original"), by = c("item", "year")) |>
  mutate(gap = replicated - original,
         rel_gap = if_else(original != 0, gap / abs(original), NA_real_))
table1_similarity <- table1_comparison |>
  filter(!item %in% c("n_obs", "at", "total_lse")) |>
  group_by(population) |>
  summarise(cells = n(),
            share_within_0.01 = mean(abs(gap) <= 0.01),
            share_within_10pct = mean(abs(rel_gap) <= 0.10, na.rm = TRUE),
            mean_abs_gap = mean(abs(gap)))
table1_similarity
write_csv(table1_comparison, here("output", "tables", "table_1_comparison.csv"))
write_csv(table1_similarity, here("output", "tables", "table_1_similarity.csv"))

# For the note of the extended Table 1: the share of firm-years with negative book equity by link
# status in the extension years (a ratio averaged across firms weights a near-zero-asset firm like the
# largest, which is why the all-Compustat equity means fall away from the main sample's after 1998)
negative_equity <- panel |>
  filter(us_inc, fyear %in% c(2005, 2015, 2025), !is.na(ceq_at)) |>
  group_by(ccm_linked, fyear) |>
  summarise(firm_years = n(), share_negative_equity = mean(ceq_at < 0), .groups = "drop")
negative_equity
write_csv(negative_equity, here("output", "tables", "table_1_negative_equity_by_link.csv"))

# ---------------------------------------------------------------------------------------------
# 2. Table 2: the cash-flow items over total assets, same layout, firm-years with a deficit
# ---------------------------------------------------------------------------------------------
table2_years <- both |>
  filter(!is.na(def_at), fyear %in% c(paper_years, extra_years)) |>
  group_by(population, column = paste0("y", fyear)) |>
  summarise(n_obs = n(), across(all_of(paste0(flow_rows, "_at")), ~ mean(.x, na.rm = TRUE)), .groups = "drop")
table2_periods <- both |>
  filter(!is.na(def_at)) |>
  group_by(population, column = period) |>
  summarise(n_obs = n(), across(all_of(paste0(flow_rows, "_at")), ~ mean(.x, na.rm = TRUE)), .groups = "drop")

table2 <- bind_rows(table2_years, table2_periods) |>
  pivot_longer(-c(population, column), names_to = "item") |>
  mutate(item = str_remove(item, "_at$"),
         item = factor(item, levels = c("n_obs", flow_rows))) |>
  pivot_wider(names_from = column, values_from = value) |>
  arrange(population, item) |>
  select(population, item, all_of(paste0("y", paper_years)), all_of(paste0("y", extra_years)), p1971_1998, p1999_2025)
table2 |> filter(population == "main") |> print(n = Inf, width = Inf)
write_csv(table2, here("output", "tables", "table_2_replicated.csv"))

table2_comparison <- table2 |>
  select(population, item, all_of(paste0("y", paper_years))) |>
  pivot_longer(-c(population, item), names_to = "year", values_to = "replicated") |>
  inner_join(table2_original |> pivot_longer(-item, names_to = "year", values_to = "original"), by = c("item", "year")) |>
  mutate(gap = replicated - original,
         rel_gap = if_else(original != 0, gap / abs(original), NA_real_))
table2_similarity <- table2_comparison |>
  filter(item != "n_obs") |>
  group_by(population) |>
  summarise(cells = n(),
            share_within_0.01 = mean(abs(gap) <= 0.01),
            share_within_10pct = mean(abs(rel_gap) <= 0.10, na.rm = TRUE),
            mean_abs_gap = mean(abs(gap)))
table2_similarity
write_csv(table2_comparison, here("output", "tables", "table_2_comparison.csv"))
write_csv(table2_similarity, here("output", "tables", "table_2_similarity.csv"))

# ---------------------------------------------------------------------------------------------
# 3. Fig. 1: annual means of the three ratios to net assets, main sample, beside the published points
# ---------------------------------------------------------------------------------------------
main <- both |> filter(population == "main")

figure1_points <- main |>
  group_by(fyear) |>
  summarise(n = sum(!is.na(def_na)), def_na = mean(def_na, na.rm = TRUE), nd_na = mean(nd_na, na.rm = TRUE),
            ne_na = mean(ne_na, na.rm = TRUE))
write_csv(figure1_points, here("output", "tables", "figure_1_points.csv"))

figure1_comparison <- both |>
  group_by(population, fyear) |>
  summarise(def_na = mean(def_na, na.rm = TRUE), nd_na = mean(nd_na, na.rm = TRUE), ne_na = mean(ne_na, na.rm = TRUE), .groups = "drop") |>
  pivot_longer(c(def_na, nd_na, ne_na), names_to = "series", values_to = "replicated") |>
  inner_join(fig1_original |> select(year, def_na, nd_na, ne_na) |> pivot_longer(-year, names_to = "series", values_to = "original"),
             by = c("fyear" = "year", "series")) |>
  mutate(gap = replicated - original)
figure1_comparison |> group_by(population, series) |> summarise(mean_abs_gap = mean(abs(gap)), correlation = cor(replicated, original), .groups = "drop")
write_csv(figure1_comparison, here("output", "tables", "figure_1_comparison.csv"))

series_labels <- c(def_na = "Financing deficit / net assets", nd_na = "Net debt issued / net assets",
                   ne_na = "Net equity issued / net assets")

figure1_long <- figure1_points |>
  pivot_longer(c(def_na, nd_na, ne_na), names_to = "series") |>
  mutate(series = series_labels[series])
fig1_original_long <- fig1_original |>
  pivot_longer(c(def_na, nd_na, ne_na), names_to = "series") |>
  mutate(series = series_labels[series])

ggplot(figure1_long |> filter(fyear <= 1998), aes(fyear, value, colour = series)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_line(linewidth = 0.8) + geom_point(size = 1.4) +
  geom_line(data = fig1_original_long, aes(year, value, colour = series), linetype = "dashed", linewidth = 0.6) +
  scale_x_continuous(breaks = seq(1971, 1998, by = 3)) +
  labs(x = "Fiscal year", y = "Average ratio", colour = NULL,
       caption = "Solid: replicated. Dashed: Frank and Goyal (2003), Fig. 1, read off the published figure.") +
  ggtitle("Financing deficit, net debt and net equity issued, 1971 to 1998") +
  theme_minimal(base_size = 12) + theme(legend.position = "bottom")
ggsave(here("output", "figures", "figure_1_1971_1998.png"), width = 9, height = 5.5, dpi = 200, bg = "white")

ggplot(figure1_long, aes(fyear, value, colour = series)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_vline(xintercept = 1998.5, linetype = "dotted") +
  geom_line(linewidth = 0.8) + geom_point(size = 1.4) +
  scale_x_continuous(breaks = seq(1971, 2025, by = 6)) +
  labs(x = "Fiscal year", y = "Average ratio", colour = NULL,
       caption = "Dotted line: end of the paper's sample; each period trimmed within itself.") +
  ggtitle("Financing deficit, net debt and net equity issued, 1971 to 2025") +
  theme_minimal(base_size = 12) + theme(legend.position = "bottom")
ggsave(here("output", "figures", "figure_1_1971_2025.png"), width = 9, height = 5.5, dpi = 200, bg = "white")

# ---------------------------------------------------------------------------------------------
# 4. Period descriptives (Question 1.2): the Table 2 ratios and the regression ratios, 1971 to 1998
#    against 1999 to 2025. The difference in means is tested two ways: a Welch t that treats
#    firm-years as independent (descriptive, kept for the record) and a regression of the ratio on a
#    post-1998 indicator with standard errors clustered by firm and by fiscal year, which is the one
#    the report prints (a firm's years are not independent draws, and neither are the firms of one year)
# ---------------------------------------------------------------------------------------------
desc_vars <- c(paste0(flow_rows, "_at"), "def_na", "nd_na", "ne_na", "gd_na")

descriptives_long <- main |>
  mutate(period = if_else(fyear <= 1998, "1971-1998", "1999-2025"), post = as.integer(fyear > 1998)) |>
  select(gvkey, fyear, period, post, all_of(desc_vars)) |>
  pivot_longer(-c(gvkey, fyear, period, post), names_to = "variable") |>
  filter(!is.na(value))

descriptives <- descriptives_long |>
  group_by(variable, period) |>
  summarise(n = n(), mean = mean(value), sd = sd(value), p25 = quantile(value, 0.25),
            median = median(value), p75 = quantile(value, 0.75), .groups = "drop")

period_tests <- descriptives_long |>
  group_by(variable) |>
  group_modify(~ {
    m <- feols(value ~ post, data = .x, cluster = ~ gvkey + fyear)
    tibble(diff_in_means = coef(m)["post"],
           t_welch = unname(t.test(.x$value[.x$post == 1], .x$value[.x$post == 0])$statistic),
           se_cluster_firm_year = se(m)["post"], t_cluster_firm_year = tstat(m)["post"])
  }) |>
  ungroup()

descriptives <- descriptives |> left_join(period_tests, by = "variable")
descriptives |> filter(variable %in% c("def_na", "nd_na", "ne_na", "cf_at")) |> print(n = Inf, width = Inf)
write_csv(descriptives, here("output", "tables", "table_q1_period_descriptives.csv"))

# ---------------------------------------------------------------------------------------------
# 5. Annual means of the cash-flow items over total assets, 1971 to 2025 (Question 1.3)
# ---------------------------------------------------------------------------------------------
annual_means <- main |>
  filter(!is.na(def_at)) |>
  group_by(fyear) |>
  summarise(across(all_of(paste0(flow_rows, "_at")), ~ mean(.x, na.rm = TRUE))) |>
  pivot_longer(-fyear, names_to = "item") |>
  mutate(item = str_remove(item, "_at$"),
         item = factor(item, levels = flow_rows,
                       labels = c("Cash dividends", "Investments", "Change in working capital", "Internal cash flow",
                                  "Financing deficit", "Net debt issued", "Net equity issued", "Net external financing")))
write_csv(annual_means, here("output", "tables", "table_q1_annual_means.csv"))

ggplot(annual_means, aes(fyear, value)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_vline(xintercept = 1998.5, linetype = "dotted") +
  geom_line(linewidth = 0.7) +
  facet_wrap(~ item, ncol = 4, scales = "free_y") +
  labs(x = "Fiscal year", y = "Average ratio to total assets") +
  ggtitle("Annual means of the cash-flow items, 1971 to 2025 (dotted line: end of the paper's sample)") +
  theme_minimal(base_size = 11)
ggsave(here("output", "figures", "figure_q1_annual_means.png"), width = 12, height = 6, dpi = 200, bg = "white")
