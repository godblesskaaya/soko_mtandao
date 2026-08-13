ALTER TABLE public.hotels
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_hotels_is_active
  ON public.hotels(is_active);
