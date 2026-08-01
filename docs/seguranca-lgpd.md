# Segurança e LGPD

Este projeto trata dados pessoais mínimos para atendimento pelo WhatsApp. A automação deve seguir o princípio da finalidade, necessidade e minimização de dados.

## HTTPS obrigatório

Todos os webhooks públicos devem usar HTTPS válido. Não use endpoints HTTP em produção.

## Credenciais

- Use o gerenciador de credenciais do n8n.
- Não salve tokens no banco.
- Não exponha tokens em código, documentação, prints, exports ou logs.
- Não versionar `.env`.
- Rotacione tokens quando houver suspeita de exposição.

## Menor privilégio

- O usuário PostgreSQL do n8n deve ter apenas as permissões necessárias.
- Pessoas atendentes devem acessar apenas conversas sob sua responsabilidade.
- Acesso administrativo deve ser restrito.
- Use autenticação forte no n8n.

## Dados que não devem ser armazenados

- CPF.
- Dados bancários.
- Documentos.
- Fotos.
- Comprovantes.
- Senhas.
- Tokens.
- Dados financeiros sensíveis.

Se o cliente enviar esse tipo de conteúdo, o workflow não deve baixar nem armazenar o arquivo. Para texto sensível, o log deve ser sanitizado ou substituído por marcador operacional.

## Logs

Logs devem conter apenas dados necessários para auditoria operacional:

- ID da conversa.
- ID da mensagem da Meta.
- Direção da mensagem.
- Tipo de mensagem.
- Status de entrega.
- Texto sanitizado quando indispensável.

Evite armazenar payloads completos da Meta.

## Backups

- Backups devem ser criptografados ou protegidos por controle de acesso.
- Defina retenção compatível com a finalidade do atendimento.
- Não exporte dados para planilhas sem necessidade.
- Não envie backups por canais pessoais.

## Controle de acesso

- Restrinja acesso ao n8n.
- Restrinja acesso ao PostgreSQL.
- Registre quem pode reativar automação após atendimento humano.
- Revise acessos periodicamente.

## Consentimento e finalidade

A conversa deve informar a finalidade do atendimento e orientar o cliente a não enviar dados sensíveis pelo atendimento automático.

O aviso de privacidade deve aparecer no início da conversa e pode ser ajustado conforme política oficial da empresa.

## Atendimento humano

Durante atendimento humano:

- `automation_paused` deve permanecer verdadeiro.
- O robô não deve responder automaticamente.
- A responsável deve encerrar ou reativar a automação manualmente.

## Retenção

A política de retenção ainda precisa ser definida com a proprietária. Recomenda-se guardar apenas dados necessários para atendimento, auditoria e obrigações legais.

## Incidentes

Em caso de exposição de token ou dados pessoais:

1. Revogar credenciais afetadas.
2. Gerar novas credenciais.
3. Avaliar impacto.
4. Registrar o incidente.
5. Aplicar comunicação e medidas legais cabíveis com orientação responsável.
