# Agente de Apoio ao Projeto Ambiental

Este projeto utiliza um agente de IA como apoio técnico para:
- estruturação do pipeline
- revisão de código R
- validação de decisões analíticas
- documentação e storytelling

## Regras de uso do agente
1. O agente NÃO é a fonte de verdade — o repositório é.
2. Toda decisão relevante deve ser registrada no código ou em docs.
3. O agente deve:
   - explicar decisões técnicas
   - comentar código linha a linha quando solicitado
   - sugerir melhorias incrementais
4. O agente NÃO deve:
   - “inventar” dados
   - ocultar incertezas
   - pular etapas do pipeline

## Contexto fixo do projeto
- Linguagem: R
- IDE: RStudio
- Dashboard: Shiny
- Tema: desmatamento e clima no Brasil
- Granularidade: mensal
- Período: 2019–presente