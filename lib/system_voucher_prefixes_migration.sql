-- Add is_system column to omtbl_voucher_prefixes
ALTER TABLE public.omtbl_voucher_prefixes ADD COLUMN IF NOT EXISTS is_system BOOLEAN DEFAULT FALSE;

-- Update existing standard prefixes to be system protected
UPDATE public.omtbl_voucher_prefixes SET is_system = TRUE WHERE prefix_code IN ('SI', 'SIR', 'PI', 'PIR', 'JV', 'CP', 'CR', 'BP', 'BR', 'OB');

-- Insert standard prefixes if they don't exist (optional, but good for new organizations or ensuring consistency)
-- This logic is slightly complex for multi-tenant (organization_id) if we want to add for all orgs.
-- For now, we will just ensure the structure is there.

-- If you want to view the list:
-- SELECT * FROM public.omtbl_voucher_prefixes;
