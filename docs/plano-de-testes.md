# Plano de Testes

Execute os testes primeiro com o número de teste da Meta e depois em ambiente controlado antes da produção.

| Caso | Pré-condição | Passos | Resultado esperado |
| --- | --- | --- | --- |
| Primeira mensagem | Contato não existe | Enviar "Olá" ao WhatsApp | Cria contato, cria conversa em `INICIO`, envia boas-vindas, privacidade e menu, muda para `AGUARDANDO_SERVICO`. |
| Cliente já cadastrado | Contato e conversa existem | Enviar nova mensagem | Atualiza `last_message_at` e segue o estado atual. |
| Escolha válida | Estado `AGUARDANDO_SERVICO` | Enviar número de serviço ativo | Salva `selected_service_id`, confirma serviço e muda para `AGUARDANDO_CONFIRMACAO_FORMULARIO`. |
| Escolha inválida | Estado `AGUARDANDO_SERVICO` | Enviar número inexistente | Envia opção inválida e mantém estado. |
| Comando menu | Automação não pausada | Enviar "menu" | Envia menu e muda para `AGUARDANDO_SERVICO`. |
| Envio do formulário | Estado `AGUARDANDO_CONFIRMACAO_FORMULARIO` | Enviar "1" | Envia `form_url`, marca `form_sent = true` e muda para `AGUARDANDO_ESCOLHA_ATENDIMENTO`. |
| Voltar antes do formulário | Estado `AGUARDANDO_CONFIRMACAO_FORMULARIO` | Enviar "2" | Envia menu, limpa seleção se configurado e muda para `AGUARDANDO_SERVICO`. |
| Solicitação de atendente pelo menu | Estado `AGUARDANDO_SERVICO` | Enviar opção de atendente | Marca `human_service_requested = true`, `automation_paused = true`, muda para `AGUARDANDO_ATENDENTE` e notifica funcionária. |
| Solicitação de atendente após formulário | Estado `AGUARDANDO_ESCOLHA_ATENDIMENTO` | Enviar "1" | Pausa automação, muda para `AGUARDANDO_ATENDENTE` e notifica funcionária. |
| Encerramento após formulário | Estado `AGUARDANDO_ESCOLHA_ATENDIMENTO` | Enviar "2" | Envia encerramento e muda para `FINALIZADO`. |
| Automação pausada | `automation_paused = true` | Cliente envia qualquer mensagem | Registra mensagem, atualiza `last_message_at` e não envia resposta automática. |
| Mensagem duplicada | `whatsapp_message_id` já existe | Reenviar mesmo payload | Não cria novo log e não envia resposta duplicada. |
| Mensagem de áudio | Automação não pausada | Enviar áudio | Não baixa mídia, registra tipo `audio` e orienta a usar menu em texto. |
| Imagem | Automação não pausada | Enviar imagem | Não baixa nem armazena imagem, registra tipo `image` e orienta a usar menu em texto. |
| Mensagem vazia | Payload sem texto útil | Enviar mensagem vazia ou tipo não suportado | Não quebra workflow, registra tipo e envia orientação se aplicável. |
| Erro no banco | Simular indisponibilidade do PostgreSQL | Enviar mensagem | Workflow registra erro técnico seguro, não expõe detalhes ao cliente e evita respostas duplicadas. |
| Erro da API da Meta | Simular falha HTTP no envio | Enviar resposta automática | Registra falha, marca status `failed` quando possível e evita loop infinito. |
| Cliente fora do horário | Horário configurado como fechado | Solicitar atendente | Envia mensagem fora do horário, pausa se necessário e notifica responsável conforme regra definida. |
| Retorno após conversa finalizada | Estado `FINALIZADO` | Cliente envia nova mensagem | Envia retorno ao menu e muda para `AGUARDANDO_SERVICO`. |
| Serviço inativo | Serviço `active = false` | Enviar opção do serviço inativo | Trata como opção inválida. |
| Serviço exige humano antes do formulário | `requires_human_before_form = true` | Escolher o serviço | Pausa automação e notifica atendente antes de enviar formulário. |
| Serviço exige humano após formulário | `requires_human_after_form = true` | Confirmar envio do formulário | Envia formulário e encaminha para atendente conforme regra. |

## Evidências mínimas

- Registro em `contacts`.
- Registro em `conversations`.
- Registro em `message_logs`.
- Status da mensagem enviada quando disponível.
- Print ou export seguro do n8n sem tokens.
- Confirmação de que nenhum documento, foto, CPF ou dado bancário foi armazenado.
