# Configuration for project paths and utilities

# Avoid automatic conversion of strings to factors
options(stringsAsFactors = FALSE)

# Base paths
PATH_RAW <- file.path(here::here(), "data", "raw")
PATH_PROCESSED <- file.path(here::here(), "data", "processed")
PATH_SAMPLE <- file.path(here::here(), "data", "sample")
PATH_REPORTS <- file.path(here::here(), "reports")

# Create directories if they do not exist
ensure_dirs <- function(...) {
  paths <- list(...)
  invisible(lapply(paths, function(p) {
    if (!dir.exists(p)) {
      dir.create(p, recursive = TRUE, showWarnings = FALSE)
    }
  }))
}

# Read a file if it exists, otherwise return NULL
read_if_exists <- function(path, read_fun = readRDS, ...) {
  if (!file.exists(path)) {
    return(NULL)
  }
  read_fun(path, ...)
}
