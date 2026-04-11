-- ============================================================
--  BusGo — Seed Data
--  Run AFTER schema.sql in Supabase SQL Editor
-- ============================================================

-- ── 1. Demo user (admin@gmail.com / 12345678) ─────────────────────────────────
-- Password hash for "12345678" with bcrypt rounds=12
-- Pre-generated: $2b$12$rOmXqKt3KVdlz1mFH3Ry3OQpYJKVqRhFf8wTrKPKpVH6JlF9QXBJ2
INSERT INTO users (
  id, email, password_hash, full_name, username, phone,
  membership_type, is_active
) VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'admin@gmail.com',
  '$2b$12$rOmXqKt3KVdlz1mFH3Ry3OQpYJKVqRhFf8wTrKPKpVH6JlF9QXBJ2',
  'Admin User',
  'admin',
  '+94771234567',
  'standard',
  TRUE
) ON CONFLICT (email) DO NOTHING;

-- Demo user notification preferences
INSERT INTO notification_preferences (user_id)
VALUES ('a1b2c3d4-e5f6-7890-abcd-ef1234567890')
ON CONFLICT (user_id) DO NOTHING;

-- ── 2. Bus Routes ─────────────────────────────────────────────────────────────

-- Route 138: Maharagama → Pettah (via Nugegoda, Borella, Maradana)
INSERT INTO bus_routes (id, route_number, route_name, origin, destination, color, waypoints) VALUES (
  'r138-0000-0000-0000-000000000001',
  '138',
  'Maharagama - Pettah',
  'Maharagama',
  'Pettah',
  '#E53935',
  '[
    {"lat": 6.8447, "lng": 79.9262},
    {"lat": 6.8480, "lng": 79.9220},
    {"lat": 6.8650, "lng": 79.9000},
    {"lat": 6.8790, "lng": 79.8950},
    {"lat": 6.8900, "lng": 79.8900},
    {"lat": 6.9000, "lng": 79.8800},
    {"lat": 6.9100, "lng": 79.8650},
    {"lat": 6.9200, "lng": 79.8520}
  ]'::jsonb
) ON CONFLICT (route_number) DO NOTHING;

-- Route 163: Kottawa → Fort (via Borella, Maradana)
INSERT INTO bus_routes (id, route_number, route_name, origin, destination, color, waypoints) VALUES (
  'r163-0000-0000-0000-000000000002',
  '163',
  'Kottawa - Fort',
  'Kottawa',
  'Colombo Fort',
  '#1E88E5',
  '[
    {"lat": 6.8370, "lng": 79.9700},
    {"lat": 6.8450, "lng": 79.9600},
    {"lat": 6.8600, "lng": 79.9450},
    {"lat": 6.8750, "lng": 79.9200},
    {"lat": 6.8900, "lng": 79.9000},
    {"lat": 6.9050, "lng": 79.8800},
    {"lat": 6.9200, "lng": 79.8520}
  ]'::jsonb
) ON CONFLICT (route_number) DO NOTHING;

-- Route 171: Nugegoda → Maradana (via Borella)
INSERT INTO bus_routes (id, route_number, route_name, origin, destination, color, waypoints) VALUES (
  'r171-0000-0000-0000-000000000003',
  '171',
  'Nugegoda - Maradana',
  'Nugegoda',
  'Maradana',
  '#43A047',
  '[
    {"lat": 6.8650, "lng": 79.9000},
    {"lat": 6.8720, "lng": 79.8980},
    {"lat": 6.8800, "lng": 79.8950},
    {"lat": 6.8900, "lng": 79.8900},
    {"lat": 6.9000, "lng": 79.8820},
    {"lat": 6.9070, "lng": 79.8750},
    {"lat": 6.9120, "lng": 79.8700},
    {"lat": 6.9170, "lng": 79.8640}
  ]'::jsonb
) ON CONFLICT (route_number) DO NOTHING;

-- ── 3. Bus Stops ──────────────────────────────────────────────────────────────
INSERT INTO bus_stops (id, stop_name, latitude, longitude) VALUES
  ('s001-0000-0000-0000-000000000001', 'Maharagama Bus Stand',    6.8447,  79.9262),
  ('s002-0000-0000-0000-000000000002', 'Nugegoda Junction',        6.8650,  79.9000),
  ('s003-0000-0000-0000-000000000003', 'Borella',                  6.9000,  79.8800),
  ('s004-0000-0000-0000-000000000004', 'Maradana',                 6.9170,  79.8640),
  ('s005-0000-0000-0000-000000000005', 'Pettah / Colombo Fort',   6.9200,  79.8520),
  ('s006-0000-0000-0000-000000000006', 'Kottawa',                  6.8370,  79.9700),
  ('s007-0000-0000-0000-000000000007', 'Rajagiriya',               6.9000,  79.9100),
  ('s008-0000-0000-0000-000000000008', 'Kirulapone',               6.8790,  79.8950)
ON CONFLICT DO NOTHING;

-- ── 4. Bus Stop ↔ Route associations ─────────────────────────────────────────
INSERT INTO bus_stop_routes (stop_id, route_id, stop_order) VALUES
  -- Route 138 stops
  ('s001-0000-0000-0000-000000000001', 'r138-0000-0000-0000-000000000001', 1),
  ('s002-0000-0000-0000-000000000002', 'r138-0000-0000-0000-000000000001', 2),
  ('s003-0000-0000-0000-000000000003', 'r138-0000-0000-0000-000000000001', 3),
  ('s004-0000-0000-0000-000000000004', 'r138-0000-0000-0000-000000000001', 4),
  ('s005-0000-0000-0000-000000000005', 'r138-0000-0000-0000-000000000001', 5),
  -- Route 163 stops
  ('s006-0000-0000-0000-000000000006', 'r163-0000-0000-0000-000000000002', 1),
  ('s002-0000-0000-0000-000000000002', 'r163-0000-0000-0000-000000000002', 2),
  ('s003-0000-0000-0000-000000000003', 'r163-0000-0000-0000-000000000002', 3),
  ('s005-0000-0000-0000-000000000005', 'r163-0000-0000-0000-000000000002', 4),
  -- Route 171 stops
  ('s002-0000-0000-0000-000000000002', 'r171-0000-0000-0000-000000000003', 1),
  ('s008-0000-0000-0000-000000000008', 'r171-0000-0000-0000-000000000003', 2),
  ('s003-0000-0000-0000-000000000003', 'r171-0000-0000-0000-000000000003', 3),
  ('s004-0000-0000-0000-000000000004', 'r171-0000-0000-0000-000000000003', 4)
ON CONFLICT (stop_id, route_id) DO NOTHING;

-- ── 5. Buses (2 per route = 6 total) ─────────────────────────────────────────
INSERT INTO buses (id, route_id, bus_number, driver_name, driver_phone, current_lat, current_lng, heading, speed_kmh, crowd_level, status) VALUES
  -- Route 138 buses
  ('b138-0000-0000-0000-000000000001', 'r138-0000-0000-0000-000000000001',
   'NC-1381', 'Suresh Perera',   '+94771000001', 6.8550, 79.9100, 315.0, 35.0, 'medium', 'active'),
  ('b138-0000-0000-0000-000000000002', 'r138-0000-0000-0000-000000000001',
   'NC-1382', 'Chamara Silva',   '+94771000002', 6.8900, 79.8870, 315.0, 42.0, 'low',    'active'),
  -- Route 163 buses
  ('b163-0000-0000-0000-000000000001', 'r163-0000-0000-0000-000000000002',
   'NC-1631', 'Ruwan Fernando',  '+94771000003', 6.8500, 79.9530, 315.0, 30.0, 'high',   'active'),
  ('b163-0000-0000-0000-000000000002', 'r163-0000-0000-0000-000000000002',
   'NC-1632', 'Pradeep Jayasena','+94771000004', 6.8950, 79.8950, 315.0, 28.0, 'medium', 'active'),
  -- Route 171 buses
  ('b171-0000-0000-0000-000000000001', 'r171-0000-0000-0000-000000000003',
   'NC-1711', 'Thilanka Bandara','+94771000005', 6.8700, 79.8970, 315.0, 45.0, 'low',    'active'),
  ('b171-0000-0000-0000-000000000002', 'r171-0000-0000-0000-000000000003',
   'NC-1712', 'Nuwan Rathnayake','+94771000006', 6.9050, 79.8790, 315.0, 38.0, 'full',   'active')
ON CONFLICT (bus_number) DO NOTHING;

-- ── 6. Sample notifications for demo user ────────────────────────────────────
INSERT INTO notifications (user_id, category, title, body, meta) VALUES
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'bus_alert', 'Bus 138 Approaching',
   'Bus 138 (Maharagama - Pettah) is 2 stops away from Nugegoda Junction.',
   '{"route_number": "138", "eta_minutes": 4}'::jsonb),
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'trip', 'Trip Completed',
   'Your trip on Route 163 has been completed. Fare: LKR 45.00',
   '{"route_number": "163", "fare_lkr": 45.00}'::jsonb),
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'general', 'Welcome to BusGo!',
   'Track buses in real-time across Colombo. Have a safe journey!',
   '{}'::jsonb)
ON CONFLICT DO NOTHING;
