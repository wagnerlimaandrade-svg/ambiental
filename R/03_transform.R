source("R/00_config.R")

library(readr)
library(dplyr)
library(lubridate)
library(janitor)

read_dataset <- function(raw_filename, sample_filename) {
  ensure_dirs(PATH_RAW, PATH_SAMPLE, PATH_PROCESSED)

  raw_path <- file.path(PATH_RAW, raw_filename)
  sample_path <- file.path(PATH_SAMPLE, sample_filename)

  path_to_read <- if (file.exists(raw_path)) raw_path else sample_path

  readr::read_csv(path_to_read, show_col_types = FALSE) %>%
    janitor::clean_names()
}

find_column <- function(df, candidates, label) {
  found <- candidates[candidates %in% names(df)]
  if (length(found) == 0) {
    stop(sprintf("Nenhuma coluna encontrada para %s", label), call. = FALSE)
  }
  found[[1]]
}

parse_date_safe <- function(x) {
  out <- ymd(x, quiet = TRUE)
  if (all(is.na(out))) out <- dmy(x, quiet = TRUE)
  out
}

run_transform <- function() {
  alertas <- read_dataset("mapbiomas_alertas.csv", "mapbiomas_alertas_sample.csv")
  clima <- read_dataset("inmet_clima.csv", "inmet_clima_sample.csv")

  alerta_date_col <- find_column(alertas, c("data", "data_alerta", "date"), "data de alerta")
  clima_date_col <- find_column(clima, c("data", "data_medicao", "date"), "data do clima")

  alertas <- alertas %>%
    mutate(
      ano_mes = floor_date(parse_date_safe(.data[[alerta_date_col]]), "month"),
      uf = toupper(trimws(uf)),
      bioma = trimws(bioma),
      area_ha = as.numeric(area_ha)
    )

  if (any(is.na(alertas$ano_mes))) stop("Datas de alertas não parseadas (NA).")

  alertas <- alertas %>%
    group_by(ano_mes, uf, bioma) %>%
    summarise(area_ha = sum(area_ha, na.rm = TRUE), .groups = "drop")

  precip_col <- find_column(clima, c("precip_mm", "precipitacao", "precipitacao_mm"), "precipitacao")
  temp_col <- find_column(clima, c("temp_c", "temperatura", "temperatura_c"), "temperatura")

  clima <- clima %>%
    mutate(
      ano_mes = floor_date(parse_date_safe(.data[[clima_date_col]]), "month"),
      uf = toupper(trimws(uf)),
      !!precip_col := as.numeric(.data[[precip_col]]),
      !!temp_col := as.numeric(.data[[temp_col]])
    )

  if (any(is.na(clima$ano_mes))) stop("Datas de clima não parseadas (NA).")

  gran <- clima %>%
    count(uf, ano_mes) %>%
    summarise(p50 = median(n), p90 = quantile(n, 0.9))

  message("Diagnóstico granularidade (linhas por UF/mês): p50=", gran$p50, " p90=", gran$p90)

  many_rows_per_month <- gran$p50 > 1 || gran$p90 > 1

  clima <- clima %>%
    group_by(ano_mes, uf) %>%
    summarise(
      precip_mm = if (many_rows_per_month) sum(.data[[precip_col]], na.rm = TRUE) else mean(.data[[precip_col]], na.rm = TRUE),
      temp_c = mean(.data[[temp_col]], na.rm = TRUE),
      .groups = "drop"
    )

  saveRDS(alertas, file.path(PATH_PROCESSED, "fact_deforestation.rds"))
  saveRDS(clima, file.path(PATH_PROCESSED, "fact_climate.rds"))
}

if (interactive()) {
  run_transform()
}
