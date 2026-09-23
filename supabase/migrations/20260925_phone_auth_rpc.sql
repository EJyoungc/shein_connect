-- Add email column to profiles, update trigger, and provide get_email_by_phone RPC for login
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;

UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id AND (p.email IS NULL OR p.email = '');

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone_number, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Customer'),
    COALESCE(NEW.raw_user_meta_data->>'phone_number', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer'),
    NEW.email
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name,
      phone_number = EXCLUDED.phone_number,
      email = EXCLUDED.email;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_email_by_phone(phone_input text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  found_email text;
  digits_only text;
  local_phone text;
  intl_phone text;
BEGIN
  digits_only := regexp_replace(phone_input, '\D', '', 'g');
  
  IF digits_only LIKE '265%' THEN
    local_phone := '0' || substring(digits_only from 4);
    intl_phone := '+' || digits_only;
  ELSEIF digits_only LIKE '0%' THEN
    local_phone := digits_only;
    intl_phone := '+265' || substring(digits_only from 2);
  ELSE
    local_phone := '0' || digits_only;
    intl_phone := '+265' || digits_only;
  END IF;

  SELECT u.email INTO found_email
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE 
    p.phone_number IN (phone_input, digits_only, local_phone, intl_phone)
    OR u.phone IN (phone_input, digits_only, local_phone, intl_phone)
  LIMIT 1;

  RETURN found_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_email_by_phone(text) TO anon, authenticated;
