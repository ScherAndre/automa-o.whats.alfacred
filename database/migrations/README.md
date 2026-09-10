# Migrations

Esta pasta guarda alteracoes incrementais de banco.

Regras:

- Revise cada arquivo antes de executar em qualquer banco real.
- Gere backup antes de aplicar migracoes em producao.
- Execute primeiro em DEV ou DEMO.
- Nunca coloque credenciais, dumps com dados pessoais ou tokens nesta pasta.
- Use os arquivos `.down.sql` somente para rollback planejado.

Ordem inicial:

1. `001_add_multi_client_foundation.up.sql`
2. `001_add_multi_client_foundation.down.sql`
