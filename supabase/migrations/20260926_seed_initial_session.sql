-- Seed initial active procurement session if none exists
INSERT INTO public.procurement_sessions (session_code, exchange_rate, status, target_amount_usd)
VALUES ('SHEIN-MW-SEPT-01', 1750.00, 'OPEN', 1500.00)
ON CONFLICT (session_code) DO NOTHING;
