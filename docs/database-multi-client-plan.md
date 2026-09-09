# Plano de Banco Multi-cliente

Este documento descreve a primeira migracao proposta para transformar o banco atual em uma base reutilizavel por varios clientes.

Nenhuma migracao deve ser aplicada direto em producao. Antes disso, exporte backup, teste em DEV/DEMO e revise as diferencas.

## Schema atual

O schema inicial esta em `database/schema.sql` e possui:

- `contacts`: contato identificado por numero de WhatsApp.
- `services`: servicos exibidos no menu.
- `conversations`: estado atual da conversa.
- `message_logs`: registro operacional de mensagens.
- `conversation_state`: enum dos estados atuais do atendimento.

Limitacao atual: as tabelas nao possuem `client_id`. Isso significa que o banco foi criado para um cliente principal, a Alfacred.

Observacao: a tabela `message_logs` cumpre o papel de historico de mensagens nesta etapa. Nao foi criada uma tabela separada chamada `messages` para evitar duplicacao desnecessaria agora.

## Migracao proposta

Arquivo:

```text
database/migrations/001_add_multi_client_foundation.up.sql
```

O que ela adiciona:

- tabela `clients`;
- `client_id` em `contacts`;
- `client_id` em `services`;
- `client_id`, `flow_id`, `step_id`, `session_data`, `status` e `last_event_at` em `conversations`;
- `client_id`, `flow_id`, `step_id`, `event`, `status`, `error_code`, `error_message` e `metadata` em `message_logs`;
- tabela `leads`;
- tabela `conversation_events`;
- tabela `error_logs`;
- indices por `client_id`;
- cliente inicial `alfacred` para preservar compatibilidade.

## Impacto

A migracao e aditiva e mantem os dados existentes associados ao cliente `alfacred`.

Mudancas de constraint:

- `contacts.whatsapp_number` deixa de ser unico globalmente e passa a ser unico por `client_id`.
- `services.option_number` deixa de ser unico globalmente e passa a ser unico por `client_id`.

Isso permite que dois clientes diferentes tenham o mesmo numero de opcao no menu, como `1`, `2`, `3`, sem conflito.

## Rollback

Arquivo:

```text
database/migrations/001_add_multi_client_foundation.down.sql
```

O rollback remove a base multi-cliente. Se ja houver dados reais de mais de um cliente, revise duplicidades antes de voltar, principalmente em:

- `contacts.whatsapp_number`;
- `services.option_number`.

## Backup antes de aplicar

Exemplo PostgreSQL:

```bash
pg_dump "$DATABASE_URL" > backup-before-multi-client.sql
```

O backup nao deve ser salvo no Git, porque pode conter dados pessoais.

## Ordem recomendada de teste

1. Criar banco DEV vazio.
2. Aplicar `database/schema.sql`.
3. Aplicar `database/migrations/001_add_multi_client_foundation.up.sql`.
4. Conferir se `clients` tem o registro `alfacred`.
5. Inserir um contato e servico de teste.
6. Conferir se `client_id` foi preenchido automaticamente.
7. Testar rollback em banco descartavel.
8. So depois planejar aplicacao em producao.

## Cuidados de seguranca

Nao registrar em `message_logs.metadata`, `leads.data`, `conversation_events.metadata` ou `error_logs.safe_context`:

- tokens;
- senhas;
- App Secret;
- CPF;
- dados bancarios;
- documentos;
- fotos;
- payload bruto completo da Meta quando houver dado sensivel.
