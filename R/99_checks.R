stopifnot(file.exists(FILE_ANALYTICAL))

df <- arrow::read_parquet(FILE_ANALYTICAL)

# Granularidade
stopifnot(!any(duplicated(df[c("uf","bioma","ano_mes")])))

# Intervalos plausíveis
stopifnot(all(df$area_desmatada_ha >= 0, na.rm = TRUE))
stopifnot(all(df$temperatura_c > -10 & df$temperatura_c < 50, na.rm = TRUE))

message("Checks OK: analytical dataset válido.")