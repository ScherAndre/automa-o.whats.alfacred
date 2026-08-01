# Fluxo da Conversa

Este documento especifica o workflow n8n para a primeira versão da automação de atendimento da Alfacred.

Não foi gerado `n8n/workflow-development.json` porque um JSON importável depende da versão instalada do n8n, dos nós disponíveis, do formato interno de credenciais e das opções habilitadas no ambiente. Para evitar um arquivo incompatível, a especificação abaixo descreve o fluxo nó por nó.

## Princípios

- Usar somente WhatsApp Business Platform Cloud API oficial da Meta.
- Responder apenas clientes que iniciaram a conversa.
- Não usar IA.
- Não usar WhatsApp Web ou automação de navegador.
- Não armazenar CPF, dados bancários, documentos ou fotos.
- Gerar o menu a partir de serviços ativos.
- Incluir sempre uma opção separada para `Falar com uma atendente`.
- Pausar a automação quando houver atendimento humano.

## Estados

| Estado | Finalidade |
| --- | --- |
| `INICIO` | Estado inicial de uma conversa nova ou reiniciada. |
| `AGUARDANDO_SERVICO` | Cliente deve escolher uma opção do menu. |
| `SERVICO_SELECIONADO` | Serviço foi salvo. Estado transitório antes da confirmação. |
| `AGUARDANDO_CONFIRMACAO_FORMULARIO` | Cliente confirma se deseja receber o formulário do serviço escolhido. |
| `FORMULARIO_ENVIADO` | Formulário foi enviado. Estado transitório antes de perguntar sobre atendimento humano. |
| `AGUARDANDO_ESCOLHA_ATENDIMENTO` | Cliente escolhe se quer falar com atendente ou encerrar. |
| `AGUARDANDO_ATENDENTE` | Solicitação humana registrada, automação pausada, aguardando responsável. |
| `ATENDIMENTO_HUMANO` | Atendimento manual em andamento, automação pausada. |
| `FINALIZADO` | Conversa encerrada. Nova mensagem pode reiniciar o menu. |

## Transições

| Estado atual | Entrada | Condição | Ação | Próximo estado |
| --- | --- | --- | --- | --- |
| Qualquer estado não pausado | `menu` | `automation_paused = false` | Limpar seleção temporária, enviar menu | `AGUARDANDO_SERVICO` |
| `INICIO` | qualquer texto | conversa nova | Enviar boas-vindas, aviso de privacidade e menu | `AGUARDANDO_SERVICO` |
| `AGUARDANDO_SERVICO` | opção de serviço | serviço ativo encontrado | Salvar `selected_service_id` | `SERVICO_SELECIONADO` |
| `SERVICO_SELECIONADO` | automático | serviço não exige humano antes do formulário | Enviar confirmação do serviço | `AGUARDANDO_CONFIRMACAO_FORMULARIO` |
| `SERVICO_SELECIONADO` | automático | `requires_human_before_form = true` | Solicitar atendimento humano | `AGUARDANDO_ATENDENTE` |
| `AGUARDANDO_SERVICO` | opção de atendente | sempre | Pausar automação e notificar funcionária | `AGUARDANDO_ATENDENTE` |
| `AGUARDANDO_SERVICO` | opção inválida | sempre | Enviar mensagem de opção inválida | `AGUARDANDO_SERVICO` |
| `AGUARDANDO_CONFIRMACAO_FORMULARIO` | `1` ou `sim` | serviço selecionado | Enviar formulário | `FORMULARIO_ENVIADO` |
| `FORMULARIO_ENVIADO` | automático | `requires_human_after_form = false` | Perguntar se deseja atendente | `AGUARDANDO_ESCOLHA_ATENDIMENTO` |
| `FORMULARIO_ENVIADO` | automático | `requires_human_after_form = true` | Solicitar atendimento humano | `AGUARDANDO_ATENDENTE` |
| `AGUARDANDO_CONFIRMACAO_FORMULARIO` | `2`, `não`, `nao` ou `menu` | sempre | Enviar menu | `AGUARDANDO_SERVICO` |
| `AGUARDANDO_CONFIRMACAO_FORMULARIO` | opção inválida | sempre | Enviar opção inválida | `AGUARDANDO_CONFIRMACAO_FORMULARIO` |
| `AGUARDANDO_ESCOLHA_ATENDIMENTO` | `1`, `sim` ou `atendente` | sempre | Pausar automação e notificar funcionária | `AGUARDANDO_ATENDENTE` |
| `AGUARDANDO_ESCOLHA_ATENDIMENTO` | `2`, `não`, `nao` ou `encerrar` | sempre | Enviar encerramento | `FINALIZADO` |
| `AGUARDANDO_ESCOLHA_ATENDIMENTO` | opção inválida | sempre | Enviar opção inválida | `AGUARDANDO_ESCOLHA_ATENDIMENTO` |
| `AGUARDANDO_ATENDENTE` | qualquer mensagem | `automation_paused = true` | Registrar mensagem, não responder automaticamente | `AGUARDANDO_ATENDENTE` |
| `ATENDIMENTO_HUMANO` | qualquer mensagem | `automation_paused = true` | Registrar mensagem, não responder automaticamente | `ATENDIMENTO_HUMANO` |
| `FINALIZADO` | qualquer mensagem | `automation_paused = false` | Enviar retorno ao menu | `AGUARDANDO_SERVICO` |

## Opções padrão

As opções de serviço vêm da tabela `services` ou de `config/services.example.json`.

A opção de atendimento humano deve ser adicionada separadamente ao menu. Sugestão:

```text
9 - Falar com uma atendente
```

O número pode ser configurado no n8n, desde que não entre em conflito com os serviços ativos.

## Workflow n8n nó por nó

### 1. Webhook: Receber evento da Meta

- Tipo: Webhook.
- Método: `GET` e `POST`, ou dois webhooks separados se a versão do n8n exigir.
- Entrada: requisição da Meta.
- Saída: payload bruto.
- Função:
  - No `GET`, validar `hub.verify_token` e devolver `hub.challenge`.
  - No `POST`, encaminhar payload para normalização.

### 2. IF: Validar token de verificação

- Entrada: query params do `GET`.
- Condição: `hub.verify_token === WHATSAPP_VERIFY_TOKEN`.
- Saída:
  - verdadeiro: responder com `hub.challenge`.
  - falso: responder `403`.

### 3. Code: Normalizar payload

- Entrada: corpo do `POST`.
- Saída esperada:

```json
{
  "event_type": "message",
  "whatsapp_message_id": "wamid...",
  "whatsapp_number": "5571999999999",
  "profile_name": "Nome do perfil",
  "message_type": "text",
  "message_text": "1",
  "received_at": "2026-08-01T12:00:00-03:00"
}
```

- Regras:
  - Se houver `statuses`, classificar como `status_update`.
  - Se não houver `messages` nem `statuses`, encerrar sem resposta.
  - Para mídia, registrar apenas `message_type`, sem baixar arquivo.
  - Normalizar texto com `trim()` e comparação sem diferenciar maiúsculas de minúsculas.

### 4. Switch: Tipo de evento

- Entrada: `event_type`.
- Saídas:
  - `message`: segue para deduplicação.
  - `status_update`: atualiza `message_logs.delivery_status`.
  - outro: encerra.

### 5. PostgreSQL: Atualizar status de mensagem

- Entrada: status recebido da Meta.
- Ação:

```sql
UPDATE message_logs
SET delivery_status = $1
WHERE whatsapp_message_id = $2;
```

- Saída: quantidade de linhas atualizadas.

### 6. PostgreSQL: Verificar duplicidade

- Entrada: `whatsapp_message_id`.
- Ação:

```sql
SELECT id
FROM message_logs
WHERE whatsapp_message_id = $1
LIMIT 1;
```

- Saída: registro existente ou vazio.

### 7. IF: Mensagem duplicada

- Condição: consulta anterior retornou registro.
- Verdadeiro: encerrar sem responder.
- Falso: continuar.

### 8. PostgreSQL: Criar ou atualizar contato

- Entrada: `whatsapp_number`, `profile_name`.
- Ação:

```sql
INSERT INTO contacts (whatsapp_number, name)
VALUES ($1, NULLIF($2, ''))
ON CONFLICT (whatsapp_number)
DO UPDATE SET
  name = COALESCE(NULLIF(EXCLUDED.name, ''), contacts.name),
  updated_at = now()
RETURNING id, whatsapp_number, name;
```

### 9. PostgreSQL: Criar ou atualizar conversa

- Entrada: `contact_id`, `received_at`.
- Ação:

```sql
INSERT INTO conversations (contact_id, current_state, last_message_at)
VALUES ($1, 'INICIO', $2)
ON CONFLICT (contact_id)
DO UPDATE SET
  last_message_at = EXCLUDED.last_message_at,
  updated_at = now()
RETURNING *;
```

### 10. PostgreSQL: Registrar mensagem recebida

- Entrada: conversa e mensagem normalizada.
- Ação:

```sql
INSERT INTO message_logs (
  conversation_id,
  whatsapp_message_id,
  direction,
  message_type,
  message_text,
  delivery_status
)
VALUES ($1, $2, 'inbound', $3, $4, 'received');
```

- Observação: `message_text` deve ser sanitizado. Não registrar CPF, dados bancários, documentos ou mídia.

### 11. IF: Automação pausada

- Condição: `automation_paused = true`.
- Verdadeiro: encerrar sem resposta automática.
- Falso: continuar.

### 12. IF: Comando menu

- Condição: texto normalizado igual a `menu`.
- Verdadeiro:
  - limpar seleção se necessário;
  - buscar serviços ativos;
  - enviar menu;
  - atualizar `current_state = 'AGUARDANDO_SERVICO'`.
- Falso: seguir para switch de estado.

### 13. Switch: Estado atual

- Entrada: `current_state`.
- Rotas:
  - `INICIO`
  - `AGUARDANDO_SERVICO`
  - `SERVICO_SELECIONADO`
  - `AGUARDANDO_CONFIRMACAO_FORMULARIO`
  - `FORMULARIO_ENVIADO`
  - `AGUARDANDO_ESCOLHA_ATENDIMENTO`
  - `AGUARDANDO_ATENDENTE`
  - `ATENDIMENTO_HUMANO`
  - `FINALIZADO`

### 14. PostgreSQL: Buscar serviços ativos

- Usado nas rotas que montam menu.
- Ação:

```sql
SELECT id, option_number, name, description, form_url,
       requires_human_before_form, requires_human_after_form
FROM services
WHERE active = true
ORDER BY option_number::int NULLS LAST, option_number;
```

Se `option_number` puder conter letras no futuro, remova o cast para inteiro.

### 15. Code: Montar menu

- Entrada: serviços ativos e mensagens configuráveis.
- Saída: texto final.
- Regra:
  - Listar cada serviço ativo como `{option_number} - {name}`.
  - Adicionar opção separada para `Falar com uma atendente`.
  - Não exibir serviços inativos.

### 16. HTTP Request: Enviar mensagem pela Meta

- Método: `POST`.
- URL:

```text
https://graph.facebook.com/vXX.X/{{WHATSAPP_PHONE_NUMBER_ID}}/messages
```

- Body conceitual:

```json
{
  "messaging_product": "whatsapp",
  "to": "{{whatsapp_number}}",
  "type": "text",
  "text": {
    "preview_url": false,
    "body": "{{message_body}}"
  }
}
```

- Saída: resposta da Meta com ID da mensagem enviada, quando disponível.

### 17. PostgreSQL: Registrar mensagem enviada

- Entrada: resposta da Meta e mensagem enviada.
- Ação:

```sql
INSERT INTO message_logs (
  conversation_id,
  whatsapp_message_id,
  direction,
  message_type,
  message_text,
  delivery_status
)
VALUES ($1, $2, 'outbound', 'text', $3, 'sent');
```

### 18. Rota `INICIO`

- Ações:
  - Buscar serviços ativos.
  - Montar boas-vindas, aviso de privacidade e menu.
  - Enviar mensagem.
  - Atualizar conversa.

```sql
UPDATE conversations
SET current_state = 'AGUARDANDO_SERVICO',
    form_sent = false,
    selected_service_id = NULL,
    updated_at = now()
WHERE id = $1;
```

### 19. Rota `AGUARDANDO_SERVICO`

- Se a entrada for a opção de atendente:
  - executar rota de atendimento humano.
- Se a entrada for uma opção de serviço ativa:
  - salvar serviço;
  - passar por `SERVICO_SELECIONADO`.
- Se a entrada for inválida:
  - enviar `invalid_option`;
  - manter estado.

Busca de serviço:

```sql
SELECT *
FROM services
WHERE active = true
  AND option_number = $1
LIMIT 1;
```

Atualização:

```sql
UPDATE conversations
SET current_state = 'SERVICO_SELECIONADO',
    selected_service_id = $2,
    form_sent = false,
    updated_at = now()
WHERE id = $1;
```

### 20. Rota `SERVICO_SELECIONADO`

- Se `requires_human_before_form = true`, executar rota de atendimento humano.
- Caso contrário:
  - enviar confirmação do serviço;
  - atualizar estado.

```sql
UPDATE conversations
SET current_state = 'AGUARDANDO_CONFIRMACAO_FORMULARIO',
    updated_at = now()
WHERE id = $1;
```

### 21. Rota `AGUARDANDO_CONFIRMACAO_FORMULARIO`

- Entrada `1` ou `sim`:
  - enviar formulário;
  - atualizar `form_sent = true`;
  - passar por `FORMULARIO_ENVIADO`.
- Entrada `2`, `não`, `nao` ou `menu`:
  - enviar menu;
  - atualizar `AGUARDANDO_SERVICO`.
- Inválida:
  - enviar `invalid_option`;
  - manter estado.

```sql
UPDATE conversations
SET current_state = 'FORMULARIO_ENVIADO',
    form_sent = true,
    updated_at = now()
WHERE id = $1;
```

### 22. Rota `FORMULARIO_ENVIADO`

- Se `requires_human_after_form = true`, executar rota de atendimento humano.
- Caso contrário:
  - perguntar se deseja falar com atendente;
  - atualizar estado.

```sql
UPDATE conversations
SET current_state = 'AGUARDANDO_ESCOLHA_ATENDIMENTO',
    updated_at = now()
WHERE id = $1;
```

### 23. Rota `AGUARDANDO_ESCOLHA_ATENDIMENTO`

- Entrada `1`, `sim`, `atendente` ou `falar com atendente`:
  - executar rota de atendimento humano.
- Entrada `2`, `não`, `nao` ou `encerrar`:
  - enviar encerramento;
  - atualizar `FINALIZADO`.
- Inválida:
  - enviar `invalid_option`;
  - manter estado.

```sql
UPDATE conversations
SET current_state = 'FINALIZADO',
    updated_at = now()
WHERE id = $1;
```

### 24. Rota de atendimento humano

- Ações obrigatórias:
  - `human_service_requested = true`;
  - `automation_paused = true`;
  - `current_state = 'AGUARDANDO_ATENDENTE'`;
  - enviar confirmação ao cliente;
  - registrar log;
  - chamar webhook genérico de notificação.

```sql
UPDATE conversations
SET human_service_requested = true,
    automation_paused = true,
    current_state = 'AGUARDANDO_ATENDENTE',
    updated_at = now()
WHERE id = $1;
```

Webhook interno sugerido:

```json
{
  "event": "human_service_requested",
  "conversation_id": "{{conversation_id}}",
  "whatsapp_number": "{{whatsapp_number}}",
  "selected_service_id": "{{selected_service_id}}",
  "requested_at": "{{received_at}}"
}
```

### 25. Rotas `AGUARDANDO_ATENDENTE` e `ATENDIMENTO_HUMANO`

- Como `automation_paused = true`, o fluxo deve:
  - registrar mensagem recebida;
  - atualizar `last_message_at`;
  - não responder automaticamente.

Uma funcionária pode mudar manualmente para `ATENDIMENTO_HUMANO` ao assumir:

```sql
UPDATE conversations
SET current_state = 'ATENDIMENTO_HUMANO',
    assigned_employee = '<nome_ou_identificador>',
    updated_at = now()
WHERE id = '<conversation_id>';
```

### 26. Rota `FINALIZADO`

- Ao receber nova mensagem:
  - enviar `return_to_menu`;
  - buscar serviços ativos;
  - enviar menu;
  - atualizar para `AGUARDANDO_SERVICO`.

```sql
UPDATE conversations
SET current_state = 'AGUARDANDO_SERVICO',
    selected_service_id = NULL,
    form_sent = false,
    human_service_requested = false,
    automation_paused = false,
    assigned_employee = NULL,
    updated_at = now()
WHERE id = $1;
```

## Tratamento de opções inválidas

Quando a opção for inválida:

- Enviar `invalid_option`.
- Não alterar `selected_service_id`.
- Não enviar formulário.
- Não pausar automação.
- Manter o estado atual, exceto se a regra específica disser o contrário.

## Tratamento fora do horário

O horário de atendimento ainda precisa ser confirmado. Até lá, o workflow pode ter um nó configurável:

- Se dentro do horário: seguir fluxo normal.
- Se fora do horário e cliente pedir atendente: pausar automação, enviar `out_of_hours` e notificar funcionária.
- Se fora do horário e cliente estiver apenas navegando no menu: manter fluxo automático, se a empresa aprovar.

## Logs e privacidade

- Não baixar mídia.
- Não armazenar documento, foto ou comprovante.
- Sanitizar texto antes de gravar `message_text`.
- Não registrar tokens em erros.
- Não salvar payload completo da Meta em logs permanentes.

## Idempotência

O campo `whatsapp_message_id` deve impedir processamento duplicado. A consulta de duplicidade deve acontecer antes de qualquer envio de resposta automática.

Se a inserção em `message_logs` falhar por violação da chave única, o workflow deve encerrar sem responder.

## Status de entrega

Quando a Meta enviar status:

- `sent`: mensagem enviada.
- `delivered`: entregue.
- `read`: lida.
- `failed`: falhou.

Atualize `message_logs.delivery_status` usando o ID da mensagem enviada.
