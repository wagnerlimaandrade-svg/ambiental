## Decisão: Agregação da precipitação
Data: 2026-01-03

Problema:
Dados do INMET podem ser diários ou mensais.

Decisão:
- Detectar granularidade via mediana de linhas por UF/mês (p50)
- Se p50 > 1 → assumir diário → somar precipitação
- Se p50 == 1 → assumir mensal → usar first()

Justificativa:
Evita dupla agregação e mantém coerência física do indicador.

Implementação:
R/03_transform.R