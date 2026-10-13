# 01. Public deflators: CPI-U and the GDP implicit price deflator, rebased to 1992 = 1
#
# Frank and Goyal (2003, Section 3) state that variables are deflated to constant 1992 dollars and
# do not name the deflator. Both candidates are built here; script 03 measures which one brings
# the 1992-dollar means of the paper's Table 9 closer and records the choice (docs/DECISIONS.md).
# Every ratio in the report is scale-free, so the deflator enters only that check.
#
# Downloads (no key needed), each only when its file is not already in data/raw/public:
#         FRED CPIAUCNS (CPI-U, all items, not seasonally adjusted, monthly), saved as fred_CPIAUCNS.csv
#         FRED GDPDEF   (GDP implicit price deflator, quarterly, seasonally adjusted), saved as fred_GDPDEF.csv
# Writes: data/raw/public/fred_deflators.csv   year, cpi_annual, n_months, gdpdef_annual, n_quarters, cpi_1992, gdpdef_1992

source("code/00_packages.R")   # installs any missing package first (see that file)
library(tidyverse)
library(here)

fred_csv <- function(id) {
  url  <- paste0("https://fred.stlouisfed.org/graph/fredgraph.csv?id=", id)
  dest <- here("data", "raw", "public", paste0("fred_", id, ".csv"))
  if (!file.exists(dest)) download.file(url, dest, mode = "wb", quiet = TRUE)
  read_csv(dest, show_col_types = FALSE, na = c("", ".")) |>
    rename(date = 1, value = 2) |>
    mutate(year = as.integer(format(date, "%Y")))
}

# 1. Annual averages of the monthly CPI and the quarterly deflator
cpi    <- fred_csv("CPIAUCNS") |> summarise(cpi_annual    = mean(value, na.rm = TRUE), n_months = sum(!is.na(value)), .by = year)
gdpdef <- fred_csv("GDPDEF")   |> summarise(gdpdef_annual = mean(value, na.rm = TRUE), n_quarters = sum(!is.na(value)), .by = year)

# 2. Rebase so that 1992 = 1; a nominal amount in year t divided by the factor is in 1992 dollars
deflators <- cpi |>
  inner_join(gdpdef, by = "year") |>
  filter(year >= 1965, year <= 2025) |>
  mutate(cpi_1992    = cpi_annual    / cpi_annual[year == 1992],
         gdpdef_1992 = gdpdef_annual / gdpdef_annual[year == 1992]) |>
  arrange(year)

# 3. Checks: 1992 is exactly 1 on both; the 1992 CPI-U annual average is 140.3 (BLS)
stopifnot(abs(deflators$cpi_1992[deflators$year == 1992] - 1) < 1e-12,
          abs(deflators$gdpdef_1992[deflators$year == 1992] - 1) < 1e-12,
          abs(deflators$cpi_annual[deflators$year == 1992] - 140.3) < 0.1)
deflators |> filter(year %in% c(1971, 1992, 1998, 2024, 2025))   # 2025 averages 11 months: FRED carries no October 2025 CPI (not published by the BLS)

write_csv(deflators, here("data", "raw", "public", "fred_deflators.csv"))
