# R/00_config.R

options(stringsAsFactors = FALSE)

# Paths centrais
PATH_RAW       <- here::here("data", "raw")
PATH_INTERIM   <- here::here("data", "interim")
PATH_PROCESSED <- here::here("data", "processed")
PATH_REPORTS   <- here::here("reports")

# Arquivos canônicos (saídas)
FILE_ANALYTICAL <- here::here("data", "processed", "analytical.parquet")
FILE_DIM_UF     <- here::here("data", "processed", "dim_uf.parquet")
FILE_DIM_BIOMA  <- here::here("data", "processed", "dim_bioma.parquet")

# Chaves padrão (contrato)
KEY_UF    <- "uf"
KEY_BIOMA <- "bioma"
KEY_DATE  <- "ano_mes"

# Variáveis padrão (contrato) — ajuste para seus nomes reais
VAR_PRECIP <- "precipitacao_mm"
VAR_TEMP   <- "temperatura_c"

# Flags
VERBOSE <- TRUE
