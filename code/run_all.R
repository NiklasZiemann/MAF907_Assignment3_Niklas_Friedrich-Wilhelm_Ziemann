# Run the whole pipeline in order and record the session. Each script prints its counts as it goes
# (echo = TRUE), so a mismatch with the README's "What to expect" shows up at the script that caused it.
#
# Two routes (README, "How to reproduce", step 6):
#   1. The raw data sample that accompanies the report: its five CSV files copied into data/raw/wrds.
#      Script 02 is then skipped, so no WRDS login is needed.
#   2. A fresh pull: data/raw/wrds holds only .gitkeep, and script 02 downloads the five extracts with
#      your WRDS login (README, steps 4 and 5).

source("code/00_packages.R")   # installs any missing package first (see that file)
library(here)

extracts <- here("data", "raw", "wrds", c("funda_1969_2025.csv", "funda_footnotes.csv", "company.csv",
                                           "ccm_link.csv", "crsp_msf_december.csv"))

scripts <- c("01_public_deflators.R",
             "02_wrds_pull.R",
             "03_sample.R",
             "04_q1_tables_1_2_fig1.R",
             "05_q2_q4_table3_horse_race.R",
             "06_q3_table5_size.R")

if (all(file.exists(extracts))) {
  scripts <- setdiff(scripts, "02_wrds_pull.R")
  cat("The five extracts are in data/raw/wrds, so script 02 is skipped (empty the folder to pull afresh).\n")
} else {
  cat("The five extracts are not all in data/raw/wrds, so script 02 pulls them (a WRDS login is needed).\n")
}

for (s in scripts) {
  cat("\n\n==========", s, "==========\n")
  source(here("code", s), echo = TRUE, max.deparse.length = Inf)
}

writeLines(capture.output(sessionInfo()), here("docs", "session_info.txt"))
cat("\nDone. Session info written to docs/session_info.txt\n")
