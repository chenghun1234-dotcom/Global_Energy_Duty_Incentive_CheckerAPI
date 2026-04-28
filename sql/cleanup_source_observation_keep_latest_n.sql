-- Keep latest N rows per source_id by captured_at DESC, then observation_id DESC
-- Replace __KEEP_N__ before execution (default suggestion: 5)
WITH ranked AS (
  SELECT
    observation_id,
    ROW_NUMBER() OVER (
      PARTITION BY source_id
      ORDER BY datetime(captured_at) DESC, observation_id DESC
    ) AS rn
  FROM source_observation
  WHERE captured_at IS NOT NULL
)
DELETE FROM source_observation
WHERE observation_id IN (
  SELECT observation_id
  FROM ranked
  WHERE rn > __KEEP_N__
);
