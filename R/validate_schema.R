# R/validate_schema.R
# Validação do analytical.parquet contra o contrato (schema.yml)
# Requer: arrow, dplyr, lubridate, rlang, yaml

validate_analytical <- function(df,
                                schema_path = here::here("schema.yml"),
                                area_tol = 1e-9) {
  stopifnot(!is.null(df))
  
  # ---- deps defensivo ----
  req_pkgs <- c("arrow", "dplyr", "lubridate", "rlang", "yaml")
  missing_pkgs <- req_pkgs[!vapply(req_pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_pkgs) > 0) {
    stop("Pacotes ausentes: ", paste(missing_pkgs, collapse = ", "), call. = FALSE)
  }
  
  # ---- ler schema ----
  schema <- yaml::read_yaml(schema_path)
  cols_spec <- schema$columns
  
  required_cols <- vapply(cols_spec, function(x) isTRUE(x$required), logical(1))
  required_names <- vapply(cols_spec[required_cols], `[[`, character(1), "name")
  
  # ---- check 1: colunas obrigatórias ----
  missing_cols <- setdiff(required_names, names(df))
  if (length(missing_cols) > 0) {
    stop("Schema inválido: faltam colunas obrigatórias: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  
  # ---- check 2: tipos (Arrow schema quando possível) ----
  # Preferimos validar via arrow types se df vier de arrow::read_parquet (data.frame também ok)
  # Mapeamento simples para checagem mínima (não tenta cobrir tudo do Arrow)
  type_map <- list(
    string  = c("character"),
    int32   = c("integer"),
    float64 = c("numeric", "double"),
    bool    = c("logical"),
    date32  = c("Date")
  )
  
  for (col in cols_spec) {
    nm <- col$name
    if (!nm %in% names(df)) next
    
    declared <- col$type
    allowed_r <- type_map[[declared]]
    
    if (is.null(allowed_r)) next
    
    # class() pode ter múltiplos; usa a 1ª classe mais informativa
    cls <- class(df[[nm]])[1]
    if (!cls %in% allowed_r) {
      stop("Tipo inválido na coluna '", nm, "': esperado ", declared,
           " (R: ", paste(allowed_r, collapse = "/"),
           "), recebido ", cls, call. = FALSE)
    }
  }
  
  # ---- check 3: PK única e sem NA ----
  pk <- schema$primary_key
  if (anyNA(df[pk])) {
    stop("PK inválida: há NA em uma ou mais colunas-chave (",
         paste(pk, collapse = ", "), ").", call. = FALSE)
  }
  dup_pk <- df |>
    dplyr::count(dplyr::across(dplyr::all_of(pk)), name = "n") |>
    dplyr::filter(.data$n > 1)
  if (nrow(dup_pk) > 0) {
    stop("PK inválida: existem duplicatas em (", paste(pk, collapse = ", "),
         "). Ex.: ", paste0(capture.output(utils::head(dup_pk, 3)), collapse = " | "),
         call. = FALSE)
  }
  
  # ---- check 4: domínios básicos ----
  if (any(df$mes < 1L | df$mes > 12L, na.rm = TRUE)) {
    stop("Domínio inválido: 'mes' fora de 1..12.", call. = FALSE)
  }
  
  # ---- check 5: física básica ----
  if (any(df$alerts_n < 0L, na.rm = TRUE)) stop("'alerts_n' < 0.", call. = FALSE)
  if (any(df$area_ha < 0, na.rm = TRUE)) stop("'area_ha' < 0.", call. = FALSE)
  if ("precip_mm" %in% names(df) && any(df$precip_mm < 0, na.rm = TRUE)) {
    stop("'precip_mm' < 0.", call. = FALSE)
  }
  
  # ---- check 6: consistência area_km2 ----
  if (!("area_km2" %in% names(df))) stop("Falta 'area_km2'.", call. = FALSE)
  ok_area <- is.na(df$area_ha) | is.na(df$area_km2) |
    (abs(df$area_km2 - (df$area_ha / 100)) <= area_tol)
  if (!all(ok_area)) {
    bad <- which(!ok_area)[1]
    stop("Invariante violada: area_km2 != area_ha/100. Ex. linha ",
         bad, ": area_ha=", df$area_ha[bad], " area_km2=", df$area_km2[bad],
         call. = FALSE)
  }
  
  # ---- check 7: ordenação de temperatura ----
  if (all(c("tmin_c", "tmed_c", "tmax_c") %in% names(df))) {
    idx <- !is.na(df$tmin_c) & !is.na(df$tmed_c) & !is.na(df$tmax_c)
    bad_temp <- idx & (df$tmin_c > df$tmed_c | df$tmed_c > df$tmax_c)
    if (any(bad_temp)) {
      i <- which(bad_temp)[1]
      stop("Invariante violada: tmin_c <= tmed_c <= tmax_c falhou. Linha ",
           i, ": tmin=", df$tmin_c[i], " tmed=", df$tmed_c[i], " tmax=", df$tmax_c[i],
           call. = FALSE)
    }
  }
  
  # ---- check 8: semântica de zero (alerts_n == 0 => area_ha == 0) ----
  bad_zero <- !is.na(df$alerts_n) & df$alerts_n == 0L &
    (!is.na(df$area_ha) & df$area_ha != 0)
  # (se area_ha for NA aqui, isso também é problema conceitual: zero observado deveria ser 0)
  bad_zero_na <- !is.na(df$alerts_n) & df$alerts_n == 0L & is.na(df$area_ha)
  
  if (any(bad_zero) || any(bad_zero_na)) {
    i <- c(which(bad_zero), which(bad_zero_na))[1]
    stop("Semântica inválida: alerts_n==0 exige area_ha==0 (não NA). Linha ",
         i, ": alerts_n=", df$alerts_n[i], " area_ha=", df$area_ha[i],
         call. = FALSE)
  }
  
  # ---- check 9: clima_granularity domínios + cobertura ----
  allowed_gran <- schema$columns[[which(vapply(schema$columns, function(x) x$name == "clima_granularity", logical(1)) )]]$allowed_values
  if (!all(df$clima_granularity %in% allowed_gran)) {
    bad <- setdiff(unique(df$clima_granularity), allowed_gran)
    stop("Domínio inválido: clima_granularity contém valores fora do permitido: ",
         paste(bad, collapse = ", "), call. = FALSE)
  }
  
  if ("clima_coverage" %in% names(df)) {
    out_cov <- !is.na(df$clima_coverage) & (df$clima_coverage < 0 | df$clima_coverage > 1)
    if (any(out_cov)) stop("Domínio inválido: clima_coverage fora de 0..1.", call. = FALSE)
  }
  
  # ---- check 10: flags boolean ----
  for (flag in c("flag_missing_clima", "flag_missing_deforestation")) {
    if (!flag %in% names(df)) stop("Falta coluna flag: ", flag, call. = FALSE)
    if (!is.logical(df[[flag]])) stop("Flag '", flag, "' deve ser logical.", call. = FALSE)
    if (anyNA(df[[flag]])) stop("Flag '", flag, "' não pode ter NA.", call. = FALSE)
  }
  
  invisible(TRUE)
}
