-- SheIn Connect: Payment Details Table and RLS Policies
-- Migration: 20260930_payment_details_table.sql

-- 1. Create payment_details table
CREATE TABLE IF NOT EXISTS public.payment_details (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('bank', 'airtel_money', 'mpamba')),
  account_name TEXT NOT NULL,         -- Name of owner of the account
  account_number TEXT NOT NULL,       -- Account or mobile number
  bank_name TEXT,                     -- Bank name (e.g., National Bank, Standard Bank, FDH Bank; null/empty for mobile money)
  branch_name TEXT,                   -- Optional bank branch
  instructions TEXT,                  -- Optional instructions or notes (e.g. "Use Order ID as reference")
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_payment_details_type ON public.payment_details(type);
CREATE INDEX IF NOT EXISTS idx_payment_details_is_active ON public.payment_details(is_active);

-- 3. Enable RLS
ALTER TABLE public.payment_details ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
-- Authenticated & anonymous users (customers) can read active payment details
DROP POLICY IF EXISTS "Payment details read all" ON public.payment_details;
CREATE POLICY "Payment details read all" ON public.payment_details
  FOR SELECT TO authenticated, anon
  USING (true);

-- Only Admins can INSERT, UPDATE, DELETE
DROP POLICY IF EXISTS "Payment details admin insert" ON public.payment_details;
CREATE POLICY "Payment details admin insert" ON public.payment_details
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Payment details admin update" ON public.payment_details;
CREATE POLICY "Payment details admin update" ON public.payment_details
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Payment details admin delete" ON public.payment_details;
CREATE POLICY "Payment details admin delete" ON public.payment_details
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- 5. Seed default/starter accounts for Malawi (National Bank, Airtel Money, TNM Mpamba)
INSERT INTO public.payment_details (type, bank_name, account_name, account_number, instructions, is_active)
VALUES
  ('bank', 'National Bank of Malawi', 'SheIn Connect Procurement', '1006543210', 'Use your Session Order ID as payment reference.', true),
  ('airtel_money', NULL, 'SheIn Connect MW', '0995936887', 'Send Money and keep the SMS transaction ID.', true),
  ('mpamba', NULL, 'SheIn Connect MW', '0888000000', 'TNM Mpamba - Send Money and keep the SMS transaction ID.', true)
ON CONFLICT DO NOTHING;
