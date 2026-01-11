# R/functions/io_helpers.R

ensure_dirs <- function(...) {
  paths <- list(...)
  invisible(lapply(paths, function(p) {
    if (!dir.exists(p)) {
      dir.create(p, recursive = TRUE, showWarnings = FALSE)
    }
  }))
}

read_if_exists <- function(path, read_fun = readRDS, ...) {
  if (!file.exists(path)) return(NULL)
  read_fun(path, ...)
}