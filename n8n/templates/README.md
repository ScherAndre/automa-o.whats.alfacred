# Templates do n8n

Esta pasta guarda modelos reutilizaveis para novos clientes.

Antes de importar um template no n8n:

1. Crie uma copia do arquivo.
2. Substitua os placeholders do cliente.
3. Configure credenciais reais somente dentro do n8n.
4. Teste com workflow inativo.
5. Publique somente depois de validar webhook, menu, formularios e atendimento humano.

Placeholders principais:

- `{{CLIENT_NAME}}`
- `{{WHATSAPP_PHONE_NUMBER_ID}}`
- `{{WHATSAPP_ACCESS_TOKEN}}`
- `{{WHATSAPP_VERIFY_TOKEN}}`
- `{{BUSINESS_HOURS_LABEL}}`
- `{{COMPANY_ADDRESS}}`
- `{{DEFAULT_FORM_URL}}`
- `{{HUMAN_ATTENDANT_NUMBER}}`
- `{{HUMAN_ATTENDANT_WA_LINK}}`

Arquivo atual:

- `whatsapp-base-webhook-meta.template.json`: template-base derivado do fluxo atual da Alfacred, sem credenciais reais.
