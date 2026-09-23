-- Create payment_proofs storage bucket if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment_proofs', 'payment_proofs', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS Policies
DROP POLICY IF EXISTS "Payment proofs authenticated upload" ON storage.objects;
CREATE POLICY "Payment proofs authenticated upload" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'payment_proofs');

DROP POLICY IF EXISTS "Payment proofs public read" ON storage.objects;
CREATE POLICY "Payment proofs public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'payment_proofs');

DROP POLICY IF EXISTS "Payment proofs admin all" ON storage.objects;
CREATE POLICY "Payment proofs admin all" ON storage.objects
  FOR ALL TO authenticated USING (bucket_id = 'payment_proofs');
