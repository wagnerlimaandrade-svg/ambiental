# R/05_build_analytical.R
# Constrói o analytical.parquet no schema final (UF×bioma×ano_mes)

source("R/00_setup.R")
source("R/00_config.R")
source("R/validate_schema.R")

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

# ---- paths (adapte aos seus PATH_*) ----
# Sugestão: mantenha interim separado do processed final
PATH_INTERIM <- if (exists("PATH_INTERIM")) PATH_INTERIM else here::here("data", "processed", "interim")
PATH_PROCESSED <- if (exists("PATH_PROCESSED")) PATH_PROCESSED else here::here("data", "processed")

in_mb    <- file.path(PATH_INTERIM, "mb_monthly.parquet")
in_clima <- file.path(PATH_INTERIM, "clima_monthly.parquet")
out_analytical <- file.path(PATH_PROCESSED, "analytical.parquet")

# ---- leitura ----
mb <- arrow::read_parquet(in_mb) |> as.data.frame()
clima <- arrow::read_parquet(in_clima) |> as.data.frame()

# ---- checks mínimos de entrada (não é o schema final; é sanity) ----
need_mb <- c("uf","bioma","ano_mes","alerts_n","area_ha")
need_cl <- c("uf","ano_mes","clima_granularity")

stopifnot(all(need_mb %in% names(mb)))
stopifnot(all(need_cl %in% names(clima)))

# garantir tipos base
if (!inherits(mb$ano_mes, "Date")) mb$ano_mes <- as.Date(mb$ano_mes)
if (!inherits(clima$ano_mes, "Date")) clima$ano_mes <- as.Date(clima$ano_mes)

# ---- definir período (universo temporal) ----
# Estratégia recomendada: grade completa de meses no período observado por qualquer fonte
min_mes <- min(c(min(mb$ano_mes, na.rm = TRUE), min(clima$ano_mes, na.rm = TRUE)), na.rm = TRUE)
max_mes <- max(c(max(mb$ano_mes, na.rm = TRUE), max(clima$ano_mes, na.rm = TRUE)), na.rm = TRUE)

all_months <- seq.Date(from = floor_date(min_mes, "month"),
                       to   = floor_date(max_mes, "month"),
                       by   = "month")

# ---- universo espacial (UF×bioma) ----
# Aqui vem a decisão: UF×bioma vem do MapBiomas (é o que tem bioma).
uf_bioma <- mb |>
  distinct(uf, bioma)

# ---- grade completa UF×bioma×mês ----
grid <- tidyr::crossing(
  uf_bioma,
  ano_mes = all_months
)

# ---- padronizações defensivas antes do join ----
mb2 <- mb |>
  mutate(
    ano_mes = floor_date(.data$ano_mes, "month"),
    uf = str_to_upper(.data$uf)
  )

clima2 <- clima |>
  mutate(
    ano_mes = floor_date(.data$ano_mes, "month"),
    uf = str_to_upper(.data$uf)
  )

# ---- join (left join na grade completa) ----
# Resultado: clima replicado por bioma dentro de UF (por design)
analytical <- grid |>
  left_join(mb2, by = c("uf","bioma","ano_mes")) |>
  left_join(clima2, by = c("uf","ano_mes"))

# ---- regra de semântica: zero observado vs NA (importante) ----
# Para desmatamento: se não veio linha do MB no mês, isso é "missing de insumo" (flag TRUE)
# Se veio e alerts_n==0, deve existir e area_ha==0.
analytical <- analytical |>
  mutate(
    flag_missing_deforestation = is.na(.data$alerts_n) & is.na(.data$area_ha),
    
    # Preencher "ausente" como zero? NÃO automaticamente.
    # Só preenchemos zeros quando sabemos que "observou e foi zero".
    # Então aqui: se alerts_n está NA mas area_ha NA, deixamos NA (missing), e a flag marca.
    
    # Mas se alerts_n vem NA e area_ha vem 0, isso é incoerente; validação pega depois.
    # Se alerts_n vem 0 e area_ha vem NA, também pega depois.
    alerts_n = dplyr::if_else(flag_missing_deforestation, NA_integer_, .data$alerts_n),
    area_ha  = dplyr::if_else(flag_missing_deforestation, NA_real_, .data$area_ha),
    
    # area_km2 derivada (só quando area_ha não-NA)
    area_km2 = dplyr::if_else(is.na(.data$area_ha), NA_real_, .data$area_ha / 100.0)
  )

# ---- derivados de tempo ----
analytical <- analytical |>
  mutate(
    ano = year(.data$ano_mes),
    mes = month(.data$ano_mes)
  )

# ---- flags de clima ----
# Defina "missing clima" como ausência das variáveis principais.
# Ajuste o conjunto conforme seu pipeline real.
vars_clima_core <- intersect(c("tmed_c","tmax_c","tmin_c","precip_mm"), names(analytical))

analytical <- analytical |>
  mutate(
    clima_granularity = dplyr::coalesce(.data$clima_granularity, "unknown"),
    flag_missing_clima = if (length(vars_clima_core) == 0) {
      # Se você ainda não entrega clima no interim, isso deve ser TRUE (e você não deveria ligar o app)
      TRUE
    } else {
      # missing se todas as variáveis core estiverem NA
      rowSums(!is.na(dplyr::across(dplyr::all_of(vars_clima_core)))) == 0
    }
  )

# ---- invariantes adicionais antes de exportar (opcional, redundante com validate) ----
# Ex.: garantir ano_mes no 1º dia do mês (Date)
if (!all(day(analytical$ano_mes) == 1)) {
  stop("ano_mes deve ser o 1º dia do mês em todas as linhas.", call. = FALSE)
}

# ---- coercions finais de tipo (evitar int64 acidental) ----
analytical <- analytical |>
  mutate(
    alerts_n = as.integer(.data$alerts_n),
    n_stations = if ("n_stations" %in% names(.)) as.integer(.data$n_stations) else .data$n_stations,
    ano = as.integer(.data$ano),
    mes = as.integer(.data$mes)
  )

# ---- validação formal do schema final ----
validate_analytical(analytical, schema_path = here::here("schema.yml"))

# ---- exportar parquet ----
arrow::write_parquet(analytical, out_analytical)

message("OK: analytical.parquet gerado em: ", out_analytical)
