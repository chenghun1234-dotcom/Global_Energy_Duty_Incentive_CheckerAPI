-- Safe migration for existing DBs
ALTER TABLE source_observation ADD COLUMN captured_at TEXT;

CREATE INDEX IF NOT EXISTS idx_observation_source_captured
ON source_observation(source_id, captured_at);
