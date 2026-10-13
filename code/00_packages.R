# 00. Packages: installs what the scripts need when any of it is missing, so run_all.R (or any script on
# its own) runs through on a fresh copy without a manual step. Sourced first by run_all.R and 01 to 06.
#
# renv::restore() installs the versions recorded in renv.lock (first run only; a few minutes). If that
# fails, for instance because a locked version would have to be compiled on Windows, the packages still
# missing are installed from CRAN in their current versions instead.

local({
  pkgs <- c("tidyverse", "here", "fixest", "DBI", "dbplyr", "RPostgres")
  missing <- function() pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing()) == 0) return(invisible())
  message("Installing the packages this project needs (first run only; this takes a few minutes).")
  if (requireNamespace("renv", quietly = TRUE))
    tryCatch(renv::restore(prompt = FALSE),
             error = function(e) message("renv::restore() failed (", conditionMessage(e), "); using CRAN instead."))
  if (length(missing()) > 0) {
    repos <- getOption("repos")
    if (!"CRAN" %in% names(repos) || repos[["CRAN"]] %in% c("@CRAN@", ""))
      options(repos = c(CRAN = "https://cloud.r-project.org"))
    install.packages(missing())
  }
  if (length(missing()) > 0) stop("These packages could not be installed: ", paste(missing(), collapse = ", "))
})
