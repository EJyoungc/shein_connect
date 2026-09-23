-- SheIn Connect: Complete Supabase Schema & Security Governance
-- Migration: 20260922_shein_connect_initial_schema.sql

-- 1. Profiles Table (Linked to auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Procurement Sessions Table
CREATE TABLE IF NOT EXISTS public.procurement_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_code TEXT UNIQUE NOT NULL,
  exchange_rate NUMERIC(10,2) NOT NULL, -- e.g., local currency MWK per 1 USD
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'LOCKED', 'PURCHASED', 'IN_TRANSIT', 'READY_FOR_PICKUP', 'CLOSED')),
  target_amount_usd NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Cart Items Table (Customer Working Cart)
CREATE TABLE IF NOT EXISTS public.cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  product_url TEXT NOT NULL,
  image_url TEXT NOT NULL,
  price_usd NUMERIC(10,2) NOT NULL,
  selected_option TEXT, -- Size, Color, SKU
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Session Orders Table
CREATE TABLE IF NOT EXISTS public.session_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.procurement_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  total_cost_local NUMERIC(12,2) NOT NULL,
  payment_status TEXT NOT NULL DEFAULT 'PENDING_PAYMENT' CHECK (payment_status IN ('PENDING_PAYMENT', 'VERIFYING', 'PAID', 'REJECTED')),
  proof_of_payment_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Order Snapshot Line Items Table (Immutable historical order record)
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.session_orders(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  product_url TEXT NOT NULL,
  image_url TEXT NOT NULL,
  price_usd NUMERIC(10,2) NOT NULL,
  price_local NUMERIC(10,2) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  selected_option TEXT
);

-- 6. Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON public.cart_items(user_id);
CREATE INDEX IF NOT EXISTS idx_session_orders_session_id ON public.session_orders(session_id);
CREATE INDEX IF NOT EXISTS idx_session_orders_user_id ON public.session_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_procurement_sessions_status ON public.procurement_sessions(status);

-- 7. RLS Helper Function to Check Admin Role Safely
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procurement_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- 9. Row Level Security Policies

-- Profiles Policies
DROP POLICY IF EXISTS "Profile self or admin" ON public.profiles;
CREATE POLICY "Profile self or admin" ON public.profiles
  FOR ALL USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "Profile insert on signup" ON public.profiles;
CREATE POLICY "Profile insert on signup" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Procurement Sessions Policies
-- Anyone authenticated can view sessions, only admin can insert/update/delete
DROP POLICY IF EXISTS "Sessions read authenticated" ON public.procurement_sessions;
CREATE POLICY "Sessions read authenticated" ON public.procurement_sessions
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Sessions admin modify" ON public.procurement_sessions;
CREATE POLICY "Sessions admin modify" ON public.procurement_sessions
  FOR ALL USING (public.is_admin());

-- Cart Items Policies
-- Users can only see, add, edit, and delete their own cart items
DROP POLICY IF EXISTS "Cart self access" ON public.cart_items;
CREATE POLICY "Cart self access" ON public.cart_items
  FOR ALL USING (auth.uid() = user_id);

-- Session Orders Policies
-- Users can see their own orders; admin can see all orders
DROP POLICY IF EXISTS "Orders user read/admin all" ON public.session_orders;
CREATE POLICY "Orders user read/admin all" ON public.session_orders
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "Orders user create" ON public.session_orders;
CREATE POLICY "Orders user create" ON public.session_orders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Orders admin update" ON public.session_orders;
CREATE POLICY "Orders admin update" ON public.session_orders
  FOR UPDATE USING (public.is_admin());

-- Order Items Policies
-- Accessible if user owns the parent session_order or if admin
DROP POLICY IF EXISTS "Order items read own or admin" ON public.order_items;
CREATE POLICY "Order items read own or admin" ON public.order_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.session_orders
      WHERE session_orders.id = order_items.order_id
        AND (session_orders.user_id = auth.uid() OR public.is_admin())
    )
  );

DROP POLICY IF EXISTS "Order items insert own order" ON public.order_items;
CREATE POLICY "Order items insert own order" ON public.order_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.session_orders
      WHERE session_orders.id = order_items.order_id
        AND session_orders.user_id = auth.uid()
    )
  );

-- 10. Auto-Profile Creation Trigger on auth.users Sign-Up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone_number, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Customer'),
    COALESCE(NEW.raw_user_meta_data->>'phone_number', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name,
      phone_number = EXCLUDED.phone_number;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 11. Storage Bucket for Payment Proofs (Private)
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-proofs', 'payment-proofs', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: Users can upload their own proof; admins can view all proofs
DROP POLICY IF EXISTS "User upload payment proof" ON storage.objects;
CREATE POLICY "User upload payment proof" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'payment-proofs' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "User and admin read payment proof" ON storage.objects;
CREATE POLICY "User and admin read payment proof" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'payment-proofs' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin()));
