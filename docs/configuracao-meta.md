# Configuração da Meta

Este projeto usa exclusivamente a WhatsApp Business Platform Cloud API oficial da Meta.

## Pré-requisitos

- Conta no Meta for Developers.
- Aplicativo Meta com o produto WhatsApp habilitado.
- WhatsApp Business Account vinculado.
- Número de teste ou número oficial configurado.
- URL pública HTTPS do n8n.
- Token de verificação definido em `WHATSAPP_VERIFY_TOKEN`.

## Variáveis relacionadas

```env
META_APP_ID=
META_APP_SECRET=
WHATSAPP_ACCESS_TOKEN=
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_BUSINESS_ACCOUNT_ID=
WHATSAPP_VERIFY_TOKEN=
PUBLIC_WEBHOOK_URL=
```

Os valores reais devem ser salvos fora do Git, preferencialmente no gerenciador de credenciais do n8n.

## Webhook

Configure no painel da Meta:

- Callback URL: URL pública HTTPS do webhook no n8n.
- Verify Token: mesmo valor configurado em `WHATSAPP_VERIFY_TOKEN`.
- Evento assinado: mensagens do WhatsApp.

Durante a validação, a Meta envia uma requisição `GET` contendo desafio. O endpoint deve validar o token recebido e devolver o desafio quando o token corresponder ao valor configurado.

Para mensagens reais, a Meta envia requisições `POST` com estrutura contendo `entry`, `changes`, `value`, `messages` e, quando disponível, `statuses`.

## Envio de mensagens

O envio deve ser feito pela Cloud API oficial:

```text
POST https://graph.facebook.com/vXX.X/{WHATSAPP_PHONE_NUMBER_ID}/messages
```

Use a versão da Graph API suportada no aplicativo Meta em produção. Não fixe uma versão sem validar no painel da Meta.

Headers esperados:

```text
Authorization: Bearer <WHATSAPP_ACCESS_TOKEN>
Content-Type: application/json
```

O token real nunca deve aparecer em código, documentação, logs ou exports do workflow.

## Janela de conversa

Nesta primeira versão, a automação responde apenas clientes que iniciaram a conversa. Não há campanhas, disparos em massa nem mensagens ativas iniciadas pela empresa.

## Número de teste

Para testar:

1. No painel da Meta, cadastre o telefone pessoal autorizado para o número de teste.
2. Envie uma mensagem para o número de teste.
3. Confirme que o n8n recebeu o webhook.
4. Verifique que o contato e a conversa foram criados no PostgreSQL.
5. Confirme que a resposta foi enviada pela Cloud API.

## Cuidados

- Use HTTPS obrigatório.
- Não use WhatsApp Web.
- Não use Selenium, Puppeteer ou extensões de navegador.
- Não salve tokens no banco.
- Não armazene mídia enviada por clientes.
- Não exponha payloads completos em logs permanentes.
