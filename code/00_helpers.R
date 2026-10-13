# 00. Helpers shared by the scripts (sourced by 03, 04, 05 and 06; nothing runs here)
#
# trim_tails(): the paper's trimming rule applied to one exhibit's sample. Frank and Goyal (2003)
# trimmed each ratio "to remove the most extreme 0.50% in either tail of the distribution" of their
# 1971 to 1998 sample. Cut points therefore belong to the sample an exhibit covers: a table of the
# paper's years is trimmed on the paper's years, a table of 1999 to 2025 on those years, and each
# population on its own distribution (docs/DECISIONS.md F3). The trimmed value becomes NA, so the
# observation leaves that variable only ("trimmed to remove"), and the counts removed are appended
# to data/processed/trimming_counts.csv under the exhibit's label, with the cut points used.
#
# exhibit_sample(): one exhibit's sample under that rule. The population's firm-years of the window
# the cut points come from are trimmed, then the estimation window is cut out of them. For the
# brief's windows the two coincide; for the paper's sub-windows (1971 to 1989, 1990 to 1998) the cut
# points come from 1971 to 1998, because the paper trimmed its whole sample and estimated the
# sub-windows inside it (its Tables 3 and 4). Trimmed values are NA, so the caller can count them.
#
# manifest_rows(): what the licensed extracts contain, in a form that can be compared. Row counts,
# bytes and MD5 per file, rows per fiscal year, and column sums of the items the formulas depend on.
# It was run once on the extracts of record to write the reference (docs/data_manifest.csv, a fixed
# file in the repository); script 03 recomputes it for
# the files on disk and reports where a later pull differs, year by year, instead of failing on a
# bare checksum (Compustat is revised, so a fresh pull is expected to differ at the margin).

trim_tails <- function(d, vars, exhibit, log = here::here("data", "processed", "trimming_counts.csv")) {
  cuts <- d |>
    summarise(across(all_of(vars), list(lower = ~ quantile(.x, 0.005, na.rm = TRUE),
                                        upper = ~ quantile(.x, 0.995, na.rm = TRUE),
                                        before = ~ sum(!is.na(.x))), .names = "{.col}.{.fn}")) |>
    pivot_longer(everything(), names_to = c("variable", ".value"), names_sep = "\\.")
  d <- d |>
    mutate(across(all_of(vars), ~ if_else(.x < quantile(.x, 0.005, na.rm = TRUE) | .x > quantile(.x, 0.995, na.rm = TRUE), NA_real_, .x)))
  after <- d |> summarise(across(all_of(vars), ~ sum(!is.na(.x)))) |>
    pivot_longer(everything(), names_to = "variable", values_to = "after")
  counts <- cuts |>
    left_join(after, by = "variable") |>
    mutate(exhibit = exhibit, removed = before - after, share_removed = removed / before, .before = 1)
  write_csv(counts, log, append = file.exists(log))
  d
}

exhibit_sample <- function(d, from, to, cut_from, cut_to, vars, label) {
  d |>
    filter(fyear >= cut_from, fyear <= cut_to) |>
    trim_tails(vars, label) |>
    filter(fyear >= from, fyear <= to)
}

manifest_rows <- function(funda, footnotes, company, ccm, crsp_dec, dir = here::here("data", "raw", "wrds")) {
  files <- c(funda = "funda_1969_2025.csv", footnotes = "funda_footnotes.csv", company = "company.csv",
             ccm = "ccm_link.csv", crsp = "crsp_msf_december.csv")
  per_file <- tibble(file = unname(files),
                     rows = c(nrow(funda), nrow(footnotes), nrow(company), nrow(ccm), nrow(crsp_dec))) |>
    mutate(path = file.path(dir, file),
           bytes = file.size(path),
           md5 = unname(tools::md5sum(path))) |>
    select(-path) |>
    pivot_longer(-file, names_to = "key", values_to = "value", values_transform = as.character)
  by_year <- bind_rows(
    funda |> group_by(key = paste0("fyear_", fyear)) |>
      summarise(rows = n(), at = sum(at, na.rm = TRUE), sale = sum(sale, na.rm = TRUE), dltis = sum(dltis, na.rm = TRUE),
                dltr = sum(dltr, na.rm = TRUE), sstk = sum(sstk, na.rm = TRUE), prstkc = sum(prstkc, na.rm = TRUE)) |>
      pivot_longer(-key, names_to = "item", values_to = "value") |>
      mutate(file = files[["funda"]], key = paste(key, item, sep = "_"), value = format(round(value, 3), scientific = FALSE, trim = TRUE)) |>
      select(file, key, value),
    footnotes |> count(key = paste0("fyear_", fyear, "_rows")) |>
      mutate(file = files[["footnotes"]], value = as.character(n)) |> select(file, key, value),
    crsp_dec |> group_by(key = paste0("year_", lubridate::year(date))) |>
      summarise(rows = n(), shrout = sum(shrout, na.rm = TRUE)) |>
      pivot_longer(-key, names_to = "item", values_to = "value") |>
      mutate(file = files[["crsp"]], key = paste(key, item, sep = "_"), value = format(round(value, 3), scientific = FALSE, trim = TRUE)) |>
      select(file, key, value),
    ccm |> count(key = paste0("linktype_", linktype, "_rows")) |>
      mutate(file = files[["ccm"]], value = as.character(n)) |> select(file, key, value))
  bind_rows(per_file, by_year) |> arrange(file, key)
}
