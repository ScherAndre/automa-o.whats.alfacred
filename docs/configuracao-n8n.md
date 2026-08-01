# Configuração do n8n

O n8n será responsável por receber o webhook da Meta, aplicar a lógica determinística da conversa, consultar o PostgreSQL e enviar mensagens pela WhatsApp Business Cloud API.

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

## Workflow recomendado

Monte o workflow seguindo `docs/fluxo-conversa.md`.

Nós conceituais:

1. Webhook de entrada.
2. Validação do token de verificação.
3. Normalização do payload.
4. Deduplicação pelo ID da mensagem.
5. Upsert de contato.
6. Upsert de conversa.
7. Verificação de `automation_paused`.
8. Switch por `current_state`.
9. Consulta de serviços ativos.
10. Montagem de mensagens.
11. Envio pela Cloud API da Meta.
12. Atualização do banco.
13. Registro de logs.
14. Tratamento de erros.

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
