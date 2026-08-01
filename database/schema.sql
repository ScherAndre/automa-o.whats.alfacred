CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE conversation_state AS ENUM (
  'INICIO',
  'AGUARDANDO_SERVICO',
  'SERVICO_SELECIONADO',
  'AGUARDANDO_CONFIRMACAO_FORMULARIO',
  'FORMULARIO_ENVIADO',
  'AGUARDANDO_ESCOLHA_ATENDIMENTO',
  'AGUARDANDO_ATENDENTE',
  'ATENDIMENTO_HUMANO',
  'FINALIZADO'
);

CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  whatsapp_number TEXT NOT NULL,
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT contacts_whatsapp_number_unique UNIQUE (whatsapp_number),
  CONSTRAINT contacts_whatsapp_number_not_blank CHECK (btrim(whatsapp_number) <> '')
);

CREATE TABLE services (
  id TEXT PRIMARY KEY,
  option_number TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  form_url TEXT NOT NULL,
  requires_human_before_form BOOLEAN NOT NULL DEFAULT false,
  requires_human_after_form BOOLEAN NOT NULL DEFAULT false,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT services_option_number_unique UNIQUE (option_number),
  CONSTRAINT services_option_number_not_blank CHECK (btrim(option_number) <> ''),
  CONSTRAINT services_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT services_form_url_https CHECK (form_url ~ '^https://')
);

CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  current_state conversation_state NOT NULL DEFAULT 'INICIO',
  selected_service_id TEXT REFERENCES services(id) ON DELETE SET NULL,
  form_sent BOOLEAN NOT NULL DEFAULT false,
  human_service_requested BOOLEAN NOT NULL DEFAULT false,
  automation_paused BOOLEAN NOT NULL DEFAULT false,
  assigned_employee TEXT,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT conversations_contact_unique UNIQUE (contact_id),
  CONSTRAINT conversations_human_pause_consistency CHECK (
    automation_paused = false
    OR current_state IN ('AGUARDANDO_ATENDENTE', 'ATENDIMENTO_HUMANO')
  )
);

CREATE TABLE message_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  whatsapp_message_id TEXT,
  direction TEXT NOT NULL,
  message_type TEXT NOT NULL,
  message_text TEXT,
  delivery_status TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT message_logs_direction_check CHECK (direction IN ('inbound', 'outbound')),
  CONSTRAINT message_logs_type_not_blank CHECK (btrim(message_type) <> ''),
  CONSTRAINT message_logs_delivery_status_check CHECK (
    delivery_status IS NULL
    OR delivery_status IN ('received', 'sent', 'delivered', 'read', 'failed')
  )
);

CREATE UNIQUE INDEX message_logs_whatsapp_message_id_unique
  ON message_logs (whatsapp_message_id)
  WHERE whatsapp_message_id IS NOT NULL;

CREATE INDEX contacts_whatsapp_number_idx ON contacts (whatsapp_number);
CREATE INDEX conversations_current_state_idx ON conversations (current_state);
CREATE INDEX conversations_automation_paused_idx ON conversations (automation_paused);
CREATE INDEX conversations_last_message_at_idx ON conversations (last_message_at);
CREATE INDEX services_active_option_idx ON services (active, option_number);
CREATE INDEX message_logs_conversation_created_at_idx ON message_logs (conversation_id, created_at DESC);
CREATE INDEX message_logs_delivery_status_idx ON message_logs (delivery_status);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER contacts_set_updated_at
BEFORE UPDATE ON contacts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER services_set_updated_at
BEFORE UPDATE ON services
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER conversations_set_updated_at
BEFORE UPDATE ON conversations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE contacts IS 'Contatos identificados pelo número de WhatsApp. Não armazenar documentos, CPF ou dados bancários.';
COMMENT ON TABLE conversations IS 'Estado atual da conversa determinística do atendimento.';
COMMENT ON TABLE services IS 'Catálogo configurável de serviços exibidos no menu.';
COMMENT ON TABLE message_logs IS 'Registro operacional de mensagens. O conteúdo deve ser sanitizado e não deve guardar documentos, fotos, CPF ou dados bancários.';
