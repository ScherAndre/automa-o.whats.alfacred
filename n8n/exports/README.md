# Exports do n8n

Esta pasta guarda copias exportadas e sanitizadas dos workflows existentes.

Regras:

- Nao salvar tokens reais.
- Nao salvar App Secret, senhas ou credenciais.
- Trocar `Authorization: Bearer ...` por placeholder antes de versionar.
- Usar exports como backup tecnico e referencia, nao como fonte unica de configuracao.

Arquivo atual:

- `whatsapp-alfacred-webhook-meta.sanitized.json`: export sanitizado do workflow atual da Alfacred, incluindo aviso ao atendente humano.
