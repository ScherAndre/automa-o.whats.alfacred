-- Migration: base multi-cliente
-- Objetivo: preparar o schema atual para separar dados por cliente.
-- Execucao: revisar e aplicar primeiro em DEV/DEMO. Nao execute direto em producao.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS clients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  segment TEXT NOT NULL DEFAULT 'financial',
  environment TEXT NOT NULL DEFAULT 'production',
  timezone TEXT NOT NULL DEFAULT 'America/Bahia',
  business_hours_label TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT clients_id_not_blank CHECK (btrim(id) <> ''),
  CONSTRAINT clients_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT clients_environment_check CHECK (environment IN ('development', 'demo', 'production'))
);

INSERT INTO clients (id, name, segment, environment, timezone, business_hours_label)
VALUES ('alfacred', 'Alfacred', 'financial', 'production', 'America/Bahia', '9h as 18h')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE contacts ADD COLUMN IF NOT EXISTS client_id TEXT;
UPDATE contacts SET client_id = 'alfacred' WHERE client_id IS NULL;
ALTER TABLE contacts ALTER COLUMN client_id SET DEFAULT 'alfacred';
ALTER TABLE contacts ALTER COLUMN client_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'contacts_client_id_fkey'
  ) THEN
    ALTER TABLE contacts
      ADD CONSTRAINT contacts_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT;
  END IF;
END $$;

ALTER TABLE contacts DROP CONSTRAINT IF EXISTS contacts_whatsapp_number_unique;
CREATE UNIQUE INDEX IF NOT EXISTS contacts_client_whatsapp_number_unique
  ON contacts (client_id, whatsapp_number);
CREATE INDEX IF NOT EXISTS contacts_client_id_idx ON contacts (client_id);

ALTER TABLE services ADD COLUMN IF NOT EXISTS client_id TEXT;
UPDATE services SET client_id = 'alfacred' WHERE client_id IS NULL;
ALTER TABLE services ALTER COLUMN client_id SET DEFAULT 'alfacred';
ALTER TABLE services ALTER COLUMN client_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'services_client_id_fkey'
  ) THEN
    ALTER TABLE services
      ADD CONSTRAINT services_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT;
  END IF;
END $$;

ALTER TABLE services DROP CONSTRAINT IF EXISTS services_option_number_unique;
CREATE UNIQUE INDEX IF NOT EXISTS services_client_option_number_unique
  ON services (client_id, option_number);
CREATE INDEX IF NOT EXISTS services_client_active_idx ON services (client_id, active, option_number);

ALTER TABLE conversations ADD COLUMN IF NOT EXISTS client_id TEXT;
UPDATE conversations
SET client_id = contacts.client_id
FROM contacts
WHERE conversations.contact_id = contacts.id
  AND conversations.client_id IS NULL;
UPDATE conversations SET client_id = 'alfacred' WHERE client_id IS NULL;
ALTER TABLE conversations ALTER COLUMN client_id SET DEFAULT 'alfacred';
ALTER TABLE conversations ALTER COLUMN client_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'conversations_client_id_fkey'
  ) THEN
    ALTER TABLE conversations
      ADD CONSTRAINT conversations_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT;
  END IF;
END $$;

ALTER TABLE conversations ADD COLUMN IF NOT EXISTS flow_id TEXT;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS step_id TEXT;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS session_data JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_event_at TIMESTAMPTZ;

UPDATE conversations
SET status = CASE
  WHEN automation_paused = true AND current_state IN ('AGUARDANDO_ATENDENTE', 'ATENDIMENTO_HUMANO') THEN 'waiting_human'
  WHEN current_state = 'FINALIZADO' THEN 'finished'
  ELSE 'active'
END
WHERE status IS NULL OR status = 'active';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'conversations_status_check'
  ) THEN
    ALTER TABLE conversations
      ADD CONSTRAINT conversations_status_check
      CHECK (status IN ('active', 'waiting_human', 'human', 'finished', 'archived'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS conversations_client_state_idx ON conversations (client_id, current_state);
CREATE INDEX IF NOT EXISTS conversations_client_status_idx ON conversations (client_id, status);
CREATE INDEX IF NOT EXISTS conversations_flow_step_idx ON conversations (client_id, flow_id, step_id);

ALTER TABLE message_logs ADD COLUMN IF NOT EXISTS client_id TEXT;
UPDATE message_logs
SET client_id = conversations.client_id
FROM conversations
WHERE message_logs.conversation_id = conversations.id
  AND message_logs.client_id IS NULL;
UPDATE message_logs SET client_id = 'alfacred' WHERE client_id IS NULL;
ALTER TABLE message_logs ALTER COLUMN client_id SET DEFAULT 'alfacred';
ALTER TABLE message_logs ALTER COLUMN client_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'message_logs_client_id_fkey'
  ) THEN
    ALTER TABLE message_logs
      ADD CONSTRAINT message_logs_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT;
  END IF;
END $$;

ALTER TABLE message_logs ADD COLUMN IF NOT EXISTS flow_id TEXT;
ALTER TABLE message_logs ADD COLUMN IF NOT EXISTS step_id TEXT;
ALTER TABLE message_logs ADD COLUMN IF NOT EXISTS event TEXT;
ALTER TABLE message_logs ADD COLUMN IF NOT EXISTS status TEXT;
ALTER TABLE message_logs ADD COLUMN IF NOT EXISTS error_code TEXT;
ALTER TABLE message_logs ADD COLUMN IF NOT EXISTS error_message TEXT;
ALTER TABLE message_logs ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS message_logs_client_created_at_idx
  ON message_logs (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS message_logs_client_event_idx
  ON message_logs (client_id, event, created_at DESC);
CREATE INDEX IF NOT EXISTS message_logs_flow_step_idx
  ON message_logs (client_id, flow_id, step_id, created_at DESC);

CREATE TABLE IF NOT EXISTS leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  flow_id TEXT,
  step_id TEXT,
  source TEXT NOT NULL DEFAULT 'whatsapp',
  status TEXT NOT NULL DEFAULT 'new',
  summary TEXT,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT leads_status_check CHECK (status IN ('new', 'qualified', 'sent_to_human', 'converted', 'lost', 'archived'))
);

CREATE INDEX IF NOT EXISTS leads_client_status_idx ON leads (client_id, status);
CREATE INDEX IF NOT EXISTS leads_client_created_at_idx ON leads (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS leads_contact_id_idx ON leads (contact_id);
CREATE INDEX IF NOT EXISTS leads_conversation_id_idx ON leads (conversation_id);

CREATE TABLE IF NOT EXISTS conversation_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  flow_id TEXT,
  step_id TEXT,
  event TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'ok',
  error_code TEXT,
  error_message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT conversation_events_event_not_blank CHECK (btrim(event) <> ''),
  CONSTRAINT conversation_events_status_check CHECK (status IN ('ok', 'warning', 'error', 'ignored'))
);

CREATE INDEX IF NOT EXISTS conversation_events_client_created_at_idx
  ON conversation_events (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS conversation_events_client_event_idx
  ON conversation_events (client_id, event, created_at DESC);
CREATE INDEX IF NOT EXISTS conversation_events_conversation_id_idx
  ON conversation_events (conversation_id, created_at DESC);

CREATE TABLE IF NOT EXISTS error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  source TEXT NOT NULL,
  event TEXT,
  status TEXT NOT NULL DEFAULT 'error',
  error_type TEXT,
  error_code TEXT,
  error_message TEXT,
  safe_context JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT error_logs_source_not_blank CHECK (btrim(source) <> ''),
  CONSTRAINT error_logs_status_check CHECK (status IN ('error', 'warning', 'recovered'))
);

CREATE INDEX IF NOT EXISTS error_logs_client_created_at_idx
  ON error_logs (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS error_logs_client_source_idx
  ON error_logs (client_id, source, created_at DESC);
CREATE INDEX IF NOT EXISTS error_logs_conversation_id_idx
  ON error_logs (conversation_id, created_at DESC);

DROP TRIGGER IF EXISTS clients_set_updated_at ON clients;
CREATE TRIGGER clients_set_updated_at
BEFORE UPDATE ON clients
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS leads_set_updated_at ON leads;
CREATE TRIGGER leads_set_updated_at
BEFORE UPDATE ON leads
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE clients IS 'Clientes/empresas atendidas pela base multi-cliente da automacao.';
COMMENT ON TABLE leads IS 'Leads gerados por fluxos de atendimento. Evitar dados sensiveis desnecessarios.';
COMMENT ON TABLE conversation_events IS 'Eventos operacionais de conversa, roteamento, etapas e integracoes.';
COMMENT ON TABLE error_logs IS 'Erros operacionais sanitizados. Nunca armazenar tokens, senhas ou payload bruto sensivel.';
COMMENT ON COLUMN message_logs.metadata IS 'Metadados sanitizados. Nao armazenar tokens, documentos, CPF, dados bancarios ou payload bruto.';
COMMENT ON COLUMN leads.data IS 'Dados estruturados minimos do lead. Nao armazenar documentos, senhas, CPF ou dados bancarios.';

COMMIT;
