# Template n8n Multi-cliente

Este guia explica como usar o fluxo atual da Alfacred como base para novos clientes, sem alterar o workflow de producao.

## Arquivos relacionados

- `clients/alfacred/client.config.json`: configuracao do cliente real atual.
- `clients/demo/client.config.json`: configuracao ficticia para demonstracao.
- `n8n/exports/whatsapp-alfacred-webhook-meta.sanitized.json`: export sanitizado do workflow atual.
- `n8n/templates/whatsapp-base-webhook-meta.template.json`: template-base para novos clientes.

## Antes de importar

Nunca importe o template por cima do workflow de producao da Alfacred.

Crie uma copia do arquivo template e substitua:

```text
{{CLIENT_NAME}}
{{WHATSAPP_PHONE_NUMBER_ID}}
{{WHATSAPP_ACCESS_TOKEN}}
{{WHATSAPP_VERIFY_TOKEN}}
{{BUSINESS_HOURS_LABEL}}
{{COMPANY_ADDRESS}}
{{DEFAULT_FORM_URL}}
{{HUMAN_ATTENDANT_NUMBER}}
{{HUMAN_ATTENDANT_WA_LINK}}
```

Segredos reais devem ser configurados dentro do n8n, de preferencia usando credenciais ou variaveis protegidas.

## Passo a passo para novo cliente

1. Criar pasta do cliente em `clients/<cliente_id>/`.
2. Criar `client.config.json`, `messages.json`, `services.json` e `forms.json`.
3. Copiar o template de `n8n/templates/`.
4. Substituir os placeholders nao sensiveis.
5. Importar no n8n como workflow novo.
6. Conferir que o workflow importado esta inativo.
7. Configurar as credenciais protegidas no n8n.
8. Configurar o webhook no app Meta do cliente.
9. Testar com mensagem inicial, menus, formularios e atendimento humano.
10. Ativar o workflow somente depois dos testes.

## Checklist tecnico

- Nome do cliente revisado.
- Numero do WhatsApp correto.
- Phone Number ID correto.
- Verify token definido no n8n e na Meta.
- Token real fora do Git.
- Formularios corretos.
- Numero do atendente correto.
- Demo sem envio para numero real.
- Workflow novo criado como copia, nao por cima da Alfacred.
- Execucoes do n8n sem erro.
- Logs sem tokens ou payload sensivel.

## Limitacoes atuais

O template ainda e baseado em nodes HTTP separados por mensagem. Ele ja ajuda a reaproveitar estrutura, mas ainda nao e o formato ideal.

Proxima evolucao recomendada:

- criar um node de configuracao do cliente no inicio do workflow;
- centralizar envio de mensagens em menos nodes;
- trocar headers fixos por credenciais do n8n;
- usar banco para `contacts`, `conversations`, `leads`, `events` e `errors`;
- carregar menus e mensagens a partir de configuracao por cliente.
