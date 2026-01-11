## Decisão: Agregação da precipitação

Data: 2026-01-03

Problema: Dados do INMET podem ser diários ou mensais.

Decisão: - Detectar granularidade via mediana de linhas por UF/mês (p50) - Se p50 \> 1 → assumir diário → somar precipitação - Se p50 == 1 → assumir mensal → usar first()

Justificativa: Evita dupla agregação e mantém coerência física do indicador.

Implementação: R/03_transform.R

## 2025-01-11

-   Início do ciclo diário de trabalho.
-   Foco: estrutura do projeto, ingestão SEEG e MapBiomas Alerta.
-   DEFININDO ESTRUTURA DO PROJETO
