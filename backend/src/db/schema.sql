-- ============================================================
--  BusGo — PostgreSQL Schema (Supabase)
--  Run this in Supabase SQL Editor → New Query
-- ============================================================

-- ── Extensions ────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Custom ENUM types ─────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE membership_type_enum  AS ENUM ('standard', 'premium', 'student');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE crowd_level_enum  AS ENUM ('low', 'medium', 'high', 'full');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bus_status_enum  AS ENUM ('active', 'inactive', 'breakdown');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE trip_status_enum  AS ENUM ('ongoing', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE emergency_type_enum  AS ENUM ('medical', 'criminal', 'breakdown', 'harassment', 'other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE emergency_status_enum  AS ENUM ('pending', 'acknowledged', 'resolved');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE notification_category_enum AS ENUM ('bus_alert', 'trip', 'emergency', 'payment', 'general');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
--  1. users
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS users (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email                   TEXT UNIQUE NOT NULL,
  password_hash           TEXT NOT NULL,
  full_name               TEXT NOT NULL,
  username                TEXT UNIQUE,
  phone                   TEXT,
  date_of_birth           DATE,
  avatar_url              TEXT,
  membership_type         membership_type_enum NOT NULL DEFAULT 'standard',
  -- QR token
  qr_token                UUID DEFAULT uuid_generate_v4(),
  qr_expires_at           TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 seconds'),
  -- Password reset
  reset_pin               TEXT,                         -- bcrypt hash of PIN
  reset_pin_expires_at    TIMESTAMPTZ,
  -- Misc
  is_active               BOOLEAN NOT NULL DEFAULT TRUE,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_set_updated_at ON users;
CREATE TRIGGER users_set_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════════
--  2. notification_preferences
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS notification_preferences (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bus_alerts              BOOLEAN NOT NULL DEFAULT TRUE,
  trip_updates            BOOLEAN NOT NULL DEFAULT TRUE,
  emergency_alerts        BOOLEAN NOT NULL DEFAULT TRUE,
  payment_notifications   BOOLEAN NOT NULL DEFAULT TRUE,
  promotions              BOOLEAN NOT NULL DEFAULT FALSE,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_notif_prefs_user UNIQUE (user_id)
);

DROP TRIGGER IF EXISTS notif_prefs_set_updated_at ON notification_preferences;
CREATE TRIGGER notif_prefs_set_updated_at
  BEFORE UPDATE ON notification_preferences
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════════
--  3. bus_routes
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bus_routes (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  route_number    TEXT NOT NULL UNIQUE,            -- e.g. '138'
  route_name      TEXT NOT NULL,
  origin          TEXT NOT NULL,
  destination     TEXT NOT NULL,
  waypoints       JSONB NOT NULL DEFAULT '[]',     -- [{lat, lng}, ...]
  color           TEXT NOT NULL DEFAULT '#1565C0', -- hex color for map
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
--  4. bus_stops
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bus_stops (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  stop_name   TEXT NOT NULL,
  latitude    DOUBLE PRECISION NOT NULL,
  longitude   DOUBLE PRECISION NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
--  5. bus_stop_routes (junction)
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bus_stop_routes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  stop_id     UUID NOT NULL REFERENCES bus_stops(id)  ON DELETE CASCADE,
  route_id    UUID NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE,
  stop_order  INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT uq_stop_route UNIQUE (stop_id, route_id)
);

-- ═══════════════════════════════════════════════════════════════════════════════
--  6. buses
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS buses (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  route_id                UUID NOT NULL REFERENCES bus_routes(id) ON DELETE RESTRICT,
  bus_number              TEXT NOT NULL UNIQUE,
  driver_name             TEXT NOT NULL,
  driver_phone            TEXT,
  current_lat             DOUBLE PRECISION,
  current_lng             DOUBLE PRECISION,
  heading                 DOUBLE PRECISION,        -- degrees 0-360
  speed_kmh               DOUBLE PRECISION DEFAULT 0,
  crowd_level             crowd_level_enum NOT NULL DEFAULT 'low',
  status                  bus_status_enum  NOT NULL DEFAULT 'active',
  last_location_update    TIMESTAMPTZ,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
--  7. trips
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS trips (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id)      ON DELETE CASCADE,
  bus_id            UUID NOT NULL REFERENCES buses(id)      ON DELETE RESTRICT,
  route_id          UUID NOT NULL REFERENCES bus_routes(id) ON DELETE RESTRICT,
  boarding_stop_id  UUID REFERENCES bus_stops(id)           ON DELETE SET NULL,
  alighting_stop_id UUID REFERENCES bus_stops(id)           ON DELETE SET NULL,
  boarded_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  alighted_at       TIMESTAMPTZ,
  fare_lkr          NUMERIC(10, 2),
  status            trip_status_enum NOT NULL DEFAULT 'ongoing',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
--  8. ratings
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS ratings (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id     UUID NOT NULL REFERENCES trips(id)  ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
  bus_id      UUID NOT NULL REFERENCES buses(id)  ON DELETE CASCADE,
  stars       SMALLINT NOT NULL CHECK (stars BETWEEN 1 AND 5),
  tags        TEXT[] NOT NULL DEFAULT '{}',
  comment     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_rating_trip UNIQUE (trip_id)
);

-- ═══════════════════════════════════════════════════════════════════════════════
--  9. emergency_alerts
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS emergency_alerts (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  bus_id      UUID         REFERENCES buses(id)    ON DELETE SET NULL,
  trip_id     UUID         REFERENCES trips(id)    ON DELETE SET NULL,
  alert_type  emergency_type_enum   NOT NULL,
  description TEXT,
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  status      emergency_status_enum NOT NULL DEFAULT 'pending',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS emergency_set_updated_at ON emergency_alerts;
CREATE TRIGGER emergency_set_updated_at
  BEFORE UPDATE ON emergency_alerts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════════
--  10. notifications
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
  category    notification_category_enum NOT NULL DEFAULT 'general',
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  meta        JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
--  11. recent_searches
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS recent_searches (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
  query       TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger: enforce max 5 recent searches per user (delete oldest beyond 5)
CREATE OR REPLACE FUNCTION enforce_max_recent_searches()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM recent_searches
  WHERE id IN (
    SELECT id FROM recent_searches
    WHERE user_id = NEW.user_id
    ORDER BY created_at DESC
    OFFSET 5
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS recent_searches_max_5 ON recent_searches;
CREATE TRIGGER recent_searches_max_5
  AFTER INSERT ON recent_searches
  FOR EACH ROW EXECUTE FUNCTION enforce_max_recent_searches();

-- ═══════════════════════════════════════════════════════════════════════════════
--  12. refresh_tokens
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
--  INDEXES
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_users_email               ON users(email);
CREATE INDEX IF NOT EXISTS idx_notif_prefs_user          ON notification_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_buses_route               ON buses(route_id);
CREATE INDEX IF NOT EXISTS idx_buses_status              ON buses(status);
CREATE INDEX IF NOT EXISTS idx_bus_stop_routes_stop      ON bus_stop_routes(stop_id);
CREATE INDEX IF NOT EXISTS idx_bus_stop_routes_route     ON bus_stop_routes(route_id);
CREATE INDEX IF NOT EXISTS idx_trips_user                ON trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_status              ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_bus                 ON trips(bus_id);
CREATE INDEX IF NOT EXISTS idx_trips_route               ON trips(route_id);
CREATE INDEX IF NOT EXISTS idx_ratings_user              ON ratings(user_id);
CREATE INDEX IF NOT EXISTS idx_ratings_bus               ON ratings(bus_id);
CREATE INDEX IF NOT EXISTS idx_emergency_user            ON emergency_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_emergency_status          ON emergency_alerts(status);
CREATE INDEX IF NOT EXISTS idx_notifications_user        ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read     ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_category    ON notifications(user_id, category);
CREATE INDEX IF NOT EXISTS idx_recent_searches_user      ON recent_searches(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user       ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_hash       ON refresh_tokens(token_hash);

-- ═══════════════════════════════════════════════════════════════════════════════
--  ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTE: The backend uses the SERVICE ROLE key which bypasses RLS.
-- These policies protect direct Supabase client access (e.g., anon key).

ALTER TABLE users                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_alerts        ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications           ENABLE ROW LEVEL SECURITY;
ALTER TABLE recent_searches         ENABLE ROW LEVEL SECURITY;
ALTER TABLE refresh_tokens          ENABLE ROW LEVEL SECURITY;

-- bus_routes, bus_stops, bus_stop_routes, buses — publicly readable
ALTER TABLE bus_routes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE bus_stops       ENABLE ROW LEVEL SECURITY;
ALTER TABLE bus_stop_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE buses           ENABLE ROW LEVEL SECURITY;

-- Public read policies for bus data
CREATE POLICY "bus_routes_public_read"      ON bus_routes      FOR SELECT USING (true);
CREATE POLICY "bus_stops_public_read"       ON bus_stops       FOR SELECT USING (true);
CREATE POLICY "bus_stop_routes_public_read" ON bus_stop_routes FOR SELECT USING (true);
CREATE POLICY "buses_public_read"           ON buses           FOR SELECT USING (true);

-- Users can only access their own data
CREATE POLICY "users_own_row"        ON users                    FOR ALL USING (auth.uid() = id);
CREATE POLICY "notif_prefs_own_row"  ON notification_preferences FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "trips_own_row"        ON trips                    FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "ratings_own_row"      ON ratings                  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "emergency_own_row"    ON emergency_alerts         FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "notifications_own_row" ON notifications           FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "searches_own_row"     ON recent_searches          FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "refresh_tokens_own"   ON refresh_tokens           FOR ALL USING (auth.uid() = user_id);
