-- ============================================================
--  BusGo — Migration v2
--  Run AFTER schema.sql in Supabase SQL Editor
-- ============================================================

-- 1. Add role column to users (passenger | driver | admin)
DO $$ BEGIN
  CREATE TYPE user_role_enum AS ENUM ('passenger', 'driver', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS role user_role_enum NOT NULL DEFAULT 'passenger';

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- 2. Add ML columns to emergency_alerts
ALTER TABLE emergency_alerts
  ADD COLUMN IF NOT EXISTS ml_priority       SMALLINT,
  ADD COLUMN IF NOT EXISTS ml_priority_label TEXT,
  ADD COLUMN IF NOT EXISTS ml_is_false       BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ml_confidence     NUMERIC(4,3),
  ADD COLUMN IF NOT EXISTS ml_action         TEXT;

CREATE INDEX IF NOT EXISTS idx_emergency_ml_priority ON emergency_alerts(ml_priority DESC);

-- 3. Add ML columns to ratings
ALTER TABLE ratings
  ADD COLUMN IF NOT EXISTS ml_rating     NUMERIC(4,1),
  ADD COLUMN IF NOT EXISTS ml_confidence NUMERIC(4,3),
  ADD COLUMN IF NOT EXISTS ml_context    TEXT;

-- 4. Add driver_user_id to buses (links a driver user to their bus)
ALTER TABLE buses
  ADD COLUMN IF NOT EXISTS driver_user_id UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_buses_driver_user ON buses(driver_user_id);

-- 5. Admin audit log table
CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action      TEXT NOT NULL,
  table_name  TEXT NOT NULL,
  record_id   UUID,
  metadata    JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_admin   ON admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_action  ON admin_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_created ON admin_audit_logs(created_at DESC);

ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Admins can see all audit logs; others see none
CREATE POLICY "audit_logs_admin_only"
  ON admin_audit_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 6. Seed default admin user (change password immediately after setup!)
-- Password: Admin@BusGo2026!
-- Run this only once. The bcrypt hash below is for the default password.
-- Generate a fresh hash with: node -e "const b=require('bcryptjs');b.hash('Admin@BusGo2026!',12).then(console.log)"
INSERT INTO users (email, password_hash, full_name, username, role, membership_type)
VALUES (
  'admin@busgo.lk',
  '$2a$12$placeholderHashReplaceThisWithRealBcryptHash00000000000',
  'BusGo Administrator',
  'busgo_admin',
  'admin',
  'standard'
) ON CONFLICT (email) DO NOTHING;

-- NOTE: Replace the password_hash above with a real bcrypt hash before deploying.
-- Command: node -e "const b=require('bcryptjs');b.hash('YOUR_SECURE_PASSWORD',12).then(h=>console.log(h))"
