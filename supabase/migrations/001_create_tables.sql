-- Migration pour créer les tables waiting_rooms et modifier clients
-- À exécuter dans Supabase SQL Editor

-- 1. Créer la table waiting_rooms
CREATE TABLE IF NOT EXISTS waiting_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Ajouter la colonne waiting_room_id à la table clients (si elle n'existe pas)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'clients' AND column_name = 'waiting_room_id'
  ) THEN
    ALTER TABLE clients ADD COLUMN waiting_room_id UUID;
  END IF;
END $$;

-- 3. Créer la clé étrangère (si elle n'existe pas)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'clients_waiting_room_id_fkey'
  ) THEN
    ALTER TABLE clients 
    ADD CONSTRAINT clients_waiting_room_id_fkey 
    FOREIGN KEY (waiting_room_id) REFERENCES waiting_rooms(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 4. Insérer des données de test (seed data)
INSERT INTO waiting_rooms (name, latitude, longitude) VALUES
  ('Downtown Clinic', 48.8566, 2.3522),
  ('Uptown Office', 48.8709, 2.3383),
  ('Westside Health', 48.8810, 2.3125)
ON CONFLICT DO NOTHING;

-- 5. Créer un index pour améliorer les performances des requêtes
CREATE INDEX IF NOT EXISTS idx_clients_waiting_room_id ON clients(waiting_room_id);
CREATE INDEX IF NOT EXISTS idx_clients_created_at ON clients(created_at);

