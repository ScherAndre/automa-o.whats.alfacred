# Requisitos do Projeto

## Visão geral

A automação deve atender clientes que iniciam contato pelo WhatsApp da Alfacred, apresentar um menu configurável, enviar links de formulários e encaminhar para atendimento humano quando solicitado.

O projeto deve usar somente a WhatsApp Business Platform Cloud API oficial da Meta e n8n. A primeira versão não usa inteligência artificial.

## Requisitos funcionais

1. Receber mensagens pelo webhook oficial da Meta ou por nó compatível do n8n.
2. Validar e normalizar o payload recebido.
3. Identificar o cliente pelo número do WhatsApp.
4. Criar ou atualizar registro em `contacts`.
5. Criar ou atualizar registro em `conversations`.
6. Registrar a última interação em `last_message_at`.
7. Registrar mensagens em `message_logs`.
8. Ignorar mensagens duplicadas usando `whatsapp_message_id`.
9. Enviar mensagem de boas-vindas para uma nova conversa.
10. Exibir menu gerado a partir de serviços ativos.
11. Incluir opção separada para falar com uma atendente.
12. Salvar o serviço escolhido em `selected_service_id`.
13. Confirmar a escolha antes do envio do formulário.
14. Enviar o `form_url` do serviço escolhido.
15. Perguntar se o cliente deseja falar com uma atendente após o formulário.
16. Registrar solicitação de atendimento humano.
17. Pausar a automação durante atendimento humano.
18. Permitir comando `menu` quando `automation_paused = false`.
19. Tratar opções inválidas sem trocar indevidamente de estado.
20. Registrar status de envio, entrega, leitura ou falha quando a Meta disponibilizar.

## Requisitos não funcionais

- O webhook deve ser publicado com HTTPS.
- O banco deve ser PostgreSQL.
- Credenciais devem ficar no gerenciador de credenciais do n8n ou em variáveis seguras.
- O fluxo deve ser determinístico e rastreável.
- Logs devem ser mínimos e sanitizados.
- A automação não deve armazenar CPF, dados bancários, documentos ou fotos.
- A automação não deve iniciar conversas, campanhas ou disparos em massa.
- O menu deve ser configurável sem alterar a lógica central do workflow.

## Estados obrigatórios

- `INICIO`
- `AGUARDANDO_SERVICO`
- `SERVICO_SELECIONADO`
- `AGUARDANDO_CONFIRMACAO_FORMULARIO`
- `FORMULARIO_ENVIADO`
- `AGUARDANDO_ESCOLHA_ATENDIMENTO`
- `AGUARDANDO_ATENDENTE`
- `ATENDIMENTO_HUMANO`
- `FINALIZADO`

## Dados permitidos

- Número de WhatsApp.
- Nome informado ou disponibilizado pelo perfil do WhatsApp, se necessário.
- Estado atual da conversa.
- Serviço escolhido.
- Flags operacionais de formulário e atendimento humano.
- ID de mensagem da Meta para deduplicação.
- Status operacional da mensagem.
- Texto sanitizado de mensagens de menu ou comandos.

## Dados proibidos

- CPF.
- Dados bancários.
- Fotos de documentos.
- Comprovantes.
- Selfies.
- Senhas.
- Tokens.
- Chaves de API.
- Qualquer documento financeiro enviado pelo cliente.

## Integrações previstas

- Meta WhatsApp Business Cloud API para recebimento e envio de mensagens.
- PostgreSQL para persistência.
- Webhook genérico para notificar funcionária quando houver pedido de atendimento humano.

## Critérios de aceite

- Um cliente novo recebe boas-vindas, aviso de privacidade e menu.
- Uma opção válida salva o serviço e envia confirmação.
- O formulário correto é enviado após confirmação.
- A opção de atendente pausa a automação.
- O comando `menu` funciona quando a automação não está pausada.
- Mensagens duplicadas não geram respostas duplicadas.
- Mensagens de mídia não são armazenadas nem processadas como documento.
- Nenhum arquivo contém credenciais reais.
