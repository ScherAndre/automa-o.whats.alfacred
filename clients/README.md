# Clientes

Esta pasta separa configuracoes de clientes da logica principal da automacao.

Cada cliente deve ter seus proprios arquivos de mensagens, servicos, formularios e regras de atendimento. Segredos reais nao devem ser versionados aqui.

Estrutura recomendada por cliente:

```text
clients/
  nome-do-cliente/
    client.config.json
    messages.json
    services.json
    forms.json
```

Use `clients/demo` para apresentacoes e testes sem envio para numeros reais.
