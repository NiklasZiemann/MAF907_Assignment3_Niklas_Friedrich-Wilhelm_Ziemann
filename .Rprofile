# Switches renv on when the project opens.
# On a fresh copy renv first downloads itself, and RStudio 2026.04 on Windows kills the R session if a
# download runs while the session is starting ("Error Starting R"). So inside RStudio, while renv is not
# yet in the project library, renv is set up once the session is up, and R restarts once to load it.
if (nzchar(Sys.getenv("RSTUDIO")) &&
    length(Sys.glob(c("renv/library/*/*/renv", "renv/library/*/*/*/renv"))) == 0) {
  setHook("rstudio.sessionInit", function(newSession) {
    options(renv.config.namespaces.check = FALSE)
    source("renv/activate.R")
    message("renv installed; restarting R once so the project starts cleanly.")
    .rs.restartR()
  }, action = "append")
} else {
  source("renv/activate.R")
}
