# Configuração do n8n

O n8n será responsável por receber o webhook da Meta, aplicar a lógica determinística da conversa, consultar o PostgreSQL e enviar mensagens pela WhatsApp Business Cloud API.

## Estrutura multi-cliente

O projeto agora possui uma separacao inicial entre:

- configuracao por cliente em `clients/`;
- exports sanitizados em `n8n/exports/`;
- templates reutilizaveis em `n8n/templates/`;
- migracoes de banco em `database/migrations/`.

Cliente real atual:

```text
clients/alfacred/
```

Cliente ficticio para demonstracao:

```text
clients/demo/
```

Template n8n atual:

```text
n8n/templates/whatsapp-base-webhook-meta.template.json
```

Export sanitizado da Alfacred:

```text
n8n/exports/whatsapp-alfacred-webhook-meta.sanitized.json
```

Nao edite o workflow de producao da Alfacred para testar um cliente novo. Primeiro importe uma copia inativa do template, configure os placeholders e teste em DEV/DEMO.

## Credenciais

Configure no gerenciador de credenciais do n8n:

- PostgreSQL, usando `DATABASE_URL` ou campos equivalentes.
- HTTP Header Auth ou credencial HTTP para a Cloud API da Meta.
- Webhook genérico para notificação de atendimento humano, se usado.

Não coloque tokens diretamente em nós do workflow quando houver alternativa de credencial segura.

## Variáveis de ambiente

O ambiente do n8n deve receber:

```env
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_VERIFY_TOKEN=
PUBLIC_WEBHOOK_URL=
TIMEZONE=America/Bahia
```

Demais segredos devem ser cadastrados como credenciais ou variáveis protegidas.

Para novos clientes, use nomes separados quando possivel:

```env
CLIENT_ID=
CLIENT_NAME=
COMPANY_SEGMENT=
BUSINESS_HOURS_LABEL=
HUMAN_ATTENDANT_NUMBER=
DEFAULT_FORM_URL=
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_BUSINESS_ACCOUNT_ID=
PUBLIC_WEBHOOK_URL=
```

Tokens, App Secret e senhas devem ficar em credenciais do n8n ou variaveis protegidas, nunca no JSON versionado.

## Workflow recomendado

Monte o workflow seguindo `docs/fluxo-conversa.md`.

Nós conceituais:

1. Webhook de entrada.
2. Validação do token de verificação.
3. Validação da assinatura `x-hub-signature-256`, quando houver acesso ao corpo bruto.
4. Normalização do payload.
5. Deduplicação pelo ID da mensagem.
6. Upsert de contato.
7. Upsert de conversa.
8. Verificação de `automation_paused`.
9. Switch por `current_state`.
10. Consulta de serviços ativos.
11. Montagem de mensagens.
12. Envio pela Cloud API da Meta.
13. Atualização do banco.
14. Registro de logs.
15. Tratamento de erros.

## Uso do template para novo cliente

Fluxo seguro:

1. Copiar `n8n/templates/whatsapp-base-webhook-meta.template.json`.
2. Substituir placeholders do cliente.
3. Importar a copia no n8n.
4. Manter o workflow importado inativo.
5. Configurar credenciais protegidas.
6. Testar webhook, menu, formularios e atendimento humano.
7. So ativar depois de validar tudo com numero de teste ou ambiente DEMO.

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

No workflow real, prefira trocar os headers `Authorization: Bearer ...` por credencial do n8n. O export sanitizado usa placeholders apenas para documentar a estrutura.

## Assinatura dos eventos

O ideal é validar o header `x-hub-signature-256` antes de processar qualquer mensagem recebida. Essa validação exige o corpo bruto da requisição e o `META_APP_SECRET`.

Se o n8n instalado não expuser o corpo bruto de forma adequada, use um endpoint intermediário simples para:

1. receber a requisição da Meta;
2. validar a assinatura;
3. rejeitar eventos inválidos;
4. encaminhar ao webhook do n8n apenas eventos confiáveis.

## Mensagens interativas

O menu pode ser montado como texto numerado ou como mensagem interativa oficial.

Use botões para confirmações curtas:

- receber formulário;
- voltar ao menu;
- falar com atendente;
- encerrar atendimento.

Use lista interativa quando houver muitos serviços ativos. O texto numerado deve continuar documentado como fallback para compatibilidade e testes.

## Atendimento humano

Quando o cliente pedir atendimento humano:

1. Atualizar `human_service_requested = true`.
2. Atualizar `automation_paused = true`.
3. Atualizar `current_state = 'AGUARDANDO_ATENDENTE'`.
4. Enviar confirmação ao cliente.
5. Registrar log da solicitação.
6. Chamar webhook genérico configurável para notificar uma funcionária.

Payload sugerido para o webhook interno:

```json
{
  "event": "human_service_requested",
  "conversation_id": "{{conversation_id}}",
  "contact_id": "{{contact_id}}",
  "whatsapp_number": "{{whatsapp_number}}",
  "selected_service_id": "{{selected_service_id}}",
  "requested_at": "{{requested_at}}"
}
```

Não escolha plataforma paga de atendimento nesta versão sem decisão da empresa.

## Reativação manual

Após atendimento humano, uma pessoa autorizada pode reativar a automação no banco:

```sql
UPDATE conversations
SET automation_paused = false,
    human_service_requested = false,
    assigned_employee = NULL,
    current_state = 'AGUARDANDO_SERVICO'
WHERE id = '<conversation_id>';
```

Para encerrar:

```sql
UPDATE conversations
SET automation_paused = false,
    current_state = 'FINALIZADO'
WHERE id = '<conversation_id>';
```

## Tratamento de mídia

Mensagens de áudio, imagem, vídeo, documento ou sticker devem ser tratadas como tipo não suportado nesta primeira versão. Registre apenas metadados mínimos, sem baixar ou armazenar arquivos.

Resposta sugerida quando a automação não estiver pausada:

```text
No momento, este atendimento automático entende apenas opções do menu em texto. Digite "menu" para ver as opções.
```

## Erros

Em erro de banco ou API da Meta:

- Registrar erro técnico em log seguro.
- Não expor stack trace ao cliente.
- Evitar nova tentativa infinita.
- Usar retentativas limitadas apenas para falhas transitórias.
- Manter o estado anterior se a atualização do banco falhar.
