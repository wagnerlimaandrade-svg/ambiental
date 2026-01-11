suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(arrow)
  library(lubridate)
  library(sf)
})

options(
  scipen = 999,
  dplyr.summarise.inform = FALSE
)

set.seed(123)

ensure_dirs(PATH_RAW, PATH_INTERIM, PATH_PROCESSED, PATH_REPORTS)

source("R/00_config.R")
source("R/functions/io_helpers.R")
