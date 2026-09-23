-- Migration: Allow users to update proof of payment on their own orders
-- and update payment proof images in storage

-- 1. Table RLS: User update own orders (e.g. proof_of_payment_url, payment_status)
DROP POLICY IF EXISTS "Orders user update own proof" ON public.session_orders;
CREATE POLICY "Orders user update own proof" ON public.session_orders
  FOR UPDATE
  USING (auth.uid() = user_id OR public.is_admin())
  WITH CHECK (auth.uid() = user_id OR public.is_admin());

-- 2. Storage RLS: Allow authenticated users to update/overwrite files in payment_proofs
DROP POLICY IF EXISTS "Payment proofs authenticated update" ON storage.objects;
CREATE POLICY "Payment proofs authenticated update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'payment_proofs')
  WITH CHECK (bucket_id = 'payment_proofs');
