ALTER TABLE public.ledger_entries
  DROP CONSTRAINT IF EXISTS ledger_entries_entry_type_check;

ALTER TABLE public.ledger_entries
  ADD CONSTRAINT ledger_entries_entry_type_check
  CHECK (
    entry_type IN (
      'settlement_created',
      'settlement_available',
      'settlement_locked',
      'payout_paid',
      'refund',
      'adjustment',
      'provider_collection_fee'
    )
  );
