ALTER TABLE public.hotels
  ADD COLUMN IF NOT EXISTS check_in_from text,
  ADD COLUMN IF NOT EXISTS check_in_until text,
  ADD COLUMN IF NOT EXISTS check_out_until text,
  ADD COLUMN IF NOT EXISTS stay_rules text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS check_in_requirements text[] NOT NULL DEFAULT '{}'::text[];
