-- Rollback: base multi-cliente
-- Atencao: este rollback remove colunas/tabelas multi-cliente.
-- Se houver dados de mais de um cliente, revise duplicidades antes de restaurar constraints globais.

BEGIN;

DROP TRIGGER IF EXISTS leads_set_updated_at ON leads;
DROP TRIGGER IF EXISTS clients_set_updated_at ON clients;

DROP TABLE IF EXISTS error_logs;
DROP TABLE IF EXISTS conversation_events;
DROP TABLE IF EXISTS leads;

DROP INDEX IF EXISTS message_logs_flow_step_idx;
DROP INDEX IF EXISTS message_logs_client_event_idx;
DROP INDEX IF EXISTS message_logs_client_created_at_idx;
ALTER TABLE message_logs DROP CONSTRAINT IF EXISTS message_logs_client_id_fkey;
ALTER TABLE message_logs DROP COLUMN IF EXISTS metadata;
ALTER TABLE message_logs DROP COLUMN IF EXISTS error_message;
ALTER TABLE message_logs DROP COLUMN IF EXISTS error_code;
ALTER TABLE message_logs DROP COLUMN IF EXISTS status;
ALTER TABLE message_logs DROP COLUMN IF EXISTS event;
ALTER TABLE message_logs DROP COLUMN IF EXISTS step_id;
ALTER TABLE message_logs DROP COLUMN IF EXISTS flow_id;
ALTER TABLE message_logs DROP COLUMN IF EXISTS client_id;

DROP INDEX IF EXISTS conversations_flow_step_idx;
DROP INDEX IF EXISTS conversations_client_status_idx;
DROP INDEX IF EXISTS conversations_client_state_idx;
ALTER TABLE conversations DROP CONSTRAINT IF EXISTS conversations_status_check;
ALTER TABLE conversations DROP CONSTRAINT IF EXISTS conversations_client_id_fkey;
ALTER TABLE conversations DROP COLUMN IF EXISTS last_event_at;
ALTER TABLE conversations DROP COLUMN IF EXISTS status;
ALTER TABLE conversations DROP COLUMN IF EXISTS session_data;
ALTER TABLE conversations DROP COLUMN IF EXISTS step_id;
ALTER TABLE conversations DROP COLUMN IF EXISTS flow_id;
ALTER TABLE conversations DROP COLUMN IF EXISTS client_id;

DROP INDEX IF EXISTS services_client_active_idx;
DROP INDEX IF EXISTS services_client_option_number_unique;
ALTER TABLE services DROP CONSTRAINT IF EXISTS services_client_id_fkey;
ALTER TABLE services DROP COLUMN IF EXISTS client_id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'services_option_number_unique'
  ) THEN
    ALTER TABLE services
      ADD CONSTRAINT services_option_number_unique UNIQUE (option_number);
  END IF;
END $$;

DROP INDEX IF EXISTS contacts_client_id_idx;
DROP INDEX IF EXISTS contacts_client_whatsapp_number_unique;
ALTER TABLE contacts DROP CONSTRAINT IF EXISTS contacts_client_id_fkey;
ALTER TABLE contacts DROP COLUMN IF EXISTS client_id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'contacts_whatsapp_number_unique'
  ) THEN
    ALTER TABLE contacts
      ADD CONSTRAINT contacts_whatsapp_number_unique UNIQUE (whatsapp_number);
  END IF;
END $$;

DROP TABLE IF EXISTS clients;

COMMIT;
