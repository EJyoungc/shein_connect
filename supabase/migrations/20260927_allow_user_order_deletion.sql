-- Migration: Allow users to delete their own orders and admins to delete any orders
DROP POLICY IF EXISTS "Orders user or admin delete" ON public.session_orders;
CREATE POLICY "Orders user or admin delete" ON public.session_orders
  FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "Order items user or admin delete" ON public.order_items;
CREATE POLICY "Order items user or admin delete" ON public.order_items
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.session_orders
      WHERE session_orders.id = order_items.order_id
        AND (session_orders.user_id = auth.uid() OR public.is_admin())
    )
  );
