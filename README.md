# Alfacred WhatsApp Automation

Estrutura inicial para automação do primeiro atendimento da Alfacred pelo WhatsApp, usando exclusivamente a WhatsApp Business Platform Cloud API oficial da Meta, n8n e PostgreSQL.

Esta primeira versão não usa inteligência artificial, WhatsApp Web, Selenium, Puppeteer, extensões de navegador ou bibliotecas não oficiais. O fluxo é determinístico, baseado em estados, menus, formulários e encaminhamento para atendimento humano.

## Objetivo do projeto

Automatizar o primeiro contato iniciado pelo cliente no WhatsApp da empresa, registrar o andamento da conversa, apresentar opções configuráveis, enviar links de formulários e pausar a automação quando houver solicitação de atendimento humano.

## Escopo atual

- Receber mensagens enviadas por clientes ao WhatsApp da empresa.
- Identificar o telefone do cliente.
- Criar ou atualizar contato e conversa.
- Enviar boas-vindas, aviso de privacidade e menu de serviços.
- Gerar o menu dinamicamente a partir de serviços ativos.
- Salvar o serviço escolhido.
- Confirmar a escolha antes de enviar o formulário.
- Enviar o link de formulário configurado.
- Perguntar se o cliente deseja falar com uma atendente.
- Registrar solicitação de atendimento humano.
- Pausar o fluxo automático durante atendimento humano.
- Permitir o comando `menu` quando a automação não estiver pausada.
- Tratar opções inválidas.
- Registrar data e hora da última interação.
- Evitar processamento duplicado pelo ID da mensagem recebido da Meta.

## Fora do escopo da primeira versão

- Inteligência artificial ou interpretação livre de intenção.
- WhatsApp Web, automação de navegador ou simulação de cliques.
- APIs não oficiais do WhatsApp.
- Campanhas, disparos em massa ou mensagens iniciadas pela empresa.
- Painel administrativo.
- Integração com CB Negocial, login automatizado ou cliques em sistemas externos.
- Cadastro de serviços reais sem confirmação da proprietária.
- Armazenamento de CPF, dados bancários, documentos ou fotos de clientes.
- Escolha de plataforma paga de atendimento humano sem solicitação expressa.

## Tecnologias utilizadas

- WhatsApp Business Platform Cloud API oficial da Meta.
- n8n para orquestração do workflow.
- PostgreSQL para contatos, conversas, serviços e logs operacionais.
- Webhooks HTTPS para recebimento de mensagens e integração com atendimento humano.

## Estrutura de diretórios

```text
alfacred-whatsapp-automation/
  config/
    messages.example.json
    services.example.json
  database/
    schema.sql
  docs/
    configuracao-meta.md
    configuracao-n8n.md
    fluxo-conversa.md
    perguntas-para-o-cliente.md
    plano-de-testes.md
    requisitos.md
    seguranca-lgpd.md
  n8n/
    README.md
  .env.example
  .gitignore
  README.md
```

## Pré-requisitos

- Conta Meta for Developers com produto WhatsApp configurado.
- Número de teste ou número oficial do WhatsApp Business Platform.
- Instância n8n acessível por HTTPS público.
- Banco PostgreSQL acessível pelo n8n.
- Permissão para criar credenciais no n8n.
- Link público dos formulários que serão enviados aos clientes.

## Variáveis de ambiente

Copie `.env.example` para `.env` apenas no ambiente local ou no servidor. Preencha os valores reais fora do Git.

```env
META_APP_ID=
META_APP_SECRET=
WHATSAPP_ACCESS_TOKEN=
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_BUSINESS_ACCOUNT_ID=
WHATSAPP_VERIFY_TOKEN=
DATABASE_URL=
N8N_ENCRYPTION_KEY=
PUBLIC_WEBHOOK_URL=
TIMEZONE=America/Bahia
```

Não coloque tokens, senhas ou chaves reais em documentação, commits, prints ou mensagens de suporte.

## Configuração do banco PostgreSQL

1. Crie um banco PostgreSQL para a automação.
2. Execute `database/schema.sql`.
3. Cadastre os serviços ativos na tabela `services` usando como referência `config/services.example.json`.
4. Garanta que o usuário do banco usado pelo n8n tenha apenas as permissões necessárias.

Exemplo de execução:

```bash
psql "$DATABASE_URL" -f database/schema.sql
```

## n8n

O fluxo importável `n8n/workflow-development.json` não foi criado nesta versão porque a compatibilidade exata depende da versão instalada do n8n, dos tipos de credenciais disponíveis e dos nós habilitados no ambiente.

A especificação detalhada, nó por nó, está em `docs/fluxo-conversa.md`. Use esse documento para montar o workflow no n8n com:

- Webhook ou WhatsApp Trigger.
- Nós PostgreSQL.
- Nós HTTP Request para a Cloud API da Meta.
- Switch baseado em `current_state`.
- Tratamento de erros e deduplicação por `whatsapp_message_id`.

## Webhook da Meta

1. Publique a instância n8n com HTTPS.
2. Crie um endpoint público para validação e recebimento do webhook.
3. Configure o token de verificação usando `WHATSAPP_VERIFY_TOKEN`.
4. Assine eventos de mensagens do WhatsApp.
5. Valide que o payload recebido contém `entry[].changes[].value.messages[]`.
6. Responda apenas mensagens iniciadas pelo cliente nesta primeira versão.

Detalhes operacionais estão em `docs/configuracao-meta.md`.

## Testes com número de teste da Meta

1. Use o número de teste do WhatsApp no painel da Meta.
2. Envie uma primeira mensagem a partir de um telefone autorizado.
3. Confirme o recebimento do webhook no n8n.
4. Verifique a criação do contato, conversa e log.
5. Escolha uma opção válida.
6. Teste opção inválida, comando `menu`, envio de formulário e solicitação de atendente.

O plano completo está em `docs/plano-de-testes.md`.

## Cadastro de serviços

Os serviços devem ser configurados no arquivo `config/services.example.json` e depois cadastrados na tabela `services`.

Cada serviço precisa ter:

- `id` técnico estável.
- `option` ou `option_number` usado no menu.
- `name` exibido ao cliente.
- `description` curta.
- `form_url` HTTPS.
- flags `requires_human_before_form` e `requires_human_after_form`.
- `active` para controlar exibição.

Não cadastre serviços reais sem confirmação da proprietária da empresa.

## Alteração de mensagens

As mensagens ficam em `config/messages.example.json`. Elas podem usar placeholders como:

- `{{menu_options}}`
- `{{human_option}}`
- `{{service_name}}`
- `{{service_description}}`
- `{{form_url}}`

As mensagens não devem prometer aprovação, taxa, liberação de crédito, prazo ou qualquer condição financeira.

## Estados da conversa

Estados previstos:

- `INICIO`
- `AGUARDANDO_SERVICO`
- `SERVICO_SELECIONADO`
- `AGUARDANDO_CONFIRMACAO_FORMULARIO`
- `FORMULARIO_ENVIADO`
- `AGUARDANDO_ESCOLHA_ATENDIMENTO`
- `AGUARDANDO_ATENDENTE`
- `ATENDIMENTO_HUMANO`
- `FINALIZADO`

As transições estão documentadas em `docs/fluxo-conversa.md`.

## Ativar e pausar atendimento automático

Para pausar automaticamente quando o cliente pedir atendente:

- `human_service_requested = true`
- `automation_paused = true`
- `current_state = 'AGUARDANDO_ATENDENTE'`

Durante `AGUARDANDO_ATENDENTE` ou `ATENDIMENTO_HUMANO`, o workflow deve registrar novas mensagens, mas não responder automaticamente.

Para reativar manualmente após atendimento humano, uma pessoa autorizada deve atualizar a conversa:

```sql
UPDATE conversations
SET automation_paused = false,
    human_service_requested = false,
    assigned_employee = NULL,
    current_state = 'AGUARDANDO_SERVICO'
WHERE id = '<conversation_id>';
```

Também é possível finalizar:

```sql
UPDATE conversations
SET automation_paused = false,
    current_state = 'FINALIZADO'
WHERE id = '<conversation_id>';
```

## Checklist antes de produção

- Confirmar serviços reais, ordem e links de formulários.
- Revisar todas as mensagens com a proprietária.
- Validar política de privacidade e finalidade do tratamento.
- Garantir HTTPS no n8n.
- Armazenar tokens apenas no gerenciador de credenciais do n8n.
- Criar usuário PostgreSQL com menor privilégio.
- Testar deduplicação de mensagens.
- Testar status enviado, entregue, lido e falhou.
- Validar logs sem CPF, documentos, fotos ou dados bancários.
- Configurar backup protegido.
- Definir responsável pelo atendimento humano.
- Definir horário de atendimento.
- Fazer teste com número de teste da Meta antes do número oficial.

## Limitações conhecidas

- Não há IA nem classificação de mensagens abertas.
- Mensagens de áudio, imagem e documentos não são processadas como conteúdo.
- Não há painel administrativo para editar serviços ou mensagens.
- Não há confirmação automática de preenchimento do formulário.
- Não há campanha ativa nem envio para clientes que não iniciaram conversa.
- O workflow importável do n8n deve ser criado somente após confirmar a versão instalada.
