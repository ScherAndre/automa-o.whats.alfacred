# Referência: Jasper's Market da Meta

O repositório `fbsamples/whatsapp-business-jaspers-market` é um exemplo oficial da Meta para demonstrar recursos da WhatsApp Business Platform. Ele não deve ser copiado como arquitetura principal da Alfacred, porque usa uma aplicação Node.js com Express e Redis, enquanto este projeto foi definido para n8n, PostgreSQL e fluxo determinístico.

Mesmo assim, alguns padrões do exemplo podem ser absorvidos com segurança.

## O que vale absorver agora

### Validação completa do webhook

O exemplo valida duas coisas:

- `hub.verify_token` no `GET /webhook`, usado na configuração inicial do webhook.
- Assinatura `x-hub-signature-256` no `POST`, usando o `APP_SECRET`.

Para a Alfacred, o workflow deve manter a validação do token de verificação e também validar a assinatura HMAC SHA-256 quando a infraestrutura do n8n permitir acesso ao corpo bruto da requisição. Se a instância do n8n não expuser o corpo bruto com segurança, usar um pequeno endpoint intermediário ou gateway antes do n8n para validar a assinatura e encaminhar somente eventos confiáveis.

### Separar mensagens de status

O exemplo trata `messages` e `statuses` separadamente. Isso combina com o nosso schema:

- `messages`: entram no fluxo de conversa.
- `statuses`: atualizam `message_logs.delivery_status`.

Na Alfacred, status como `sent`, `delivered`, `read` e `failed` devem ser usados para auditoria operacional, não para iniciar campanhas ou novas abordagens.

### Responder rapidamente ao webhook

O exemplo responde `200 EVENT_RECEIVED` após receber eventos válidos. No n8n, o workflow deve evitar processamento longo antes de responder à Meta. Sempre que possível:

- responder rapidamente ao webhook;
- continuar processamento em etapas seguintes;
- evitar retentativas duplicadas causadas por timeout.

### Mensagens interativas

O exemplo usa botões interativos de resposta. Isso pode melhorar o menu da Alfacred, principalmente para:

- confirmar serviço escolhido;
- perguntar se deseja receber formulário;
- perguntar se deseja falar com atendente;
- oferecer retorno ao menu.

Como o menu pode ter vários serviços, usar:

- botões quando houver até três escolhas simples;
- lista interativa quando houver mais opções;
- texto numerado como fallback.

O cadastro dos serviços continua vindo da tabela `services` ou de `config/services.example.json`.

### Marcar mensagem como lida e indicador de digitação

O exemplo marca a mensagem recebida como lida e envia indicador de digitação antes da resposta. Isso pode ser absorvido como melhoria de experiência, desde que:

- seja feito pela Cloud API oficial;
- não atrase a resposta;
- falhas nessa etapa não interrompam o fluxo principal.

### Conferência de variáveis obrigatórias

O exemplo avisa quando variáveis obrigatórias estão ausentes. No n8n, isso pode virar um checklist de ativação:

- `META_APP_ID`
- `META_APP_SECRET`
- `WHATSAPP_ACCESS_TOKEN`
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_BUSINESS_ACCOUNT_ID`
- `WHATSAPP_VERIFY_TOKEN`
- `DATABASE_URL`
- `PUBLIC_WEBHOOK_URL`

## O que não deve ser absorvido nesta versão

### Redis como requisito

O exemplo usa Redis para marcar mensagens que precisam de follow-up temporário. Para a Alfacred, PostgreSQL já cobre conversas, estados e logs. Redis só deve entrar depois se houver necessidade real de fila, cache ou controle de latência.

### Templates de marketing

O exemplo cria templates de marketing, ofertas e carrossel. Isso não combina com a primeira versão da Alfacred, que não deve fazer campanhas nem disparos em massa.

Templates podem ser considerados no futuro apenas para mensagens permitidas pela Meta, com aprovação da empresa e finalidade clara.

### Conteúdo promocional

O exemplo fala de ofertas e promo. A Alfacred não deve absorver esse tipo de conteúdo nesta etapa. As mensagens não devem prometer aprovação, taxa, liberação de crédito, prazo ou condições financeiras.

### Aplicação Node.js completa

Não há necessidade de trocar a arquitetura para Express, SDK Node ou servidor próprio. O n8n continua sendo o orquestrador definido para esta versão.

## Melhorias recomendadas para a Alfacred

1. Incluir validação de assinatura `x-hub-signature-256` antes da normalização do payload.
2. Modelar o menu como mensagem interativa quando a quantidade de opções permitir.
3. Registrar status recebido da Meta sem disparar novas mensagens automáticas.
4. Criar um checklist de variáveis obrigatórias antes de ativar o workflow.
5. Tratar falhas de indicador de digitação e marcar como lida como não críticas.
6. Manter PostgreSQL como fonte de verdade para estado da conversa.

## Decisão de arquitetura

O Jasper's Market deve ser usado como referência de padrões da Cloud API, não como base de código. Para este projeto, a melhor absorção é documental e operacional:

- reforçar segurança do webhook;
- melhorar experiência com mensagens interativas;
- separar mensagens e status;
- manter o fluxo determinístico e auditável no n8n.
