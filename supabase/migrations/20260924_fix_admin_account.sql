-- Migration to fix admin account instance_id and authentication credentials
SET search_path TO public, extensions, auth;

DO $$
DECLARE
  admin_id UUID := 'a0000000-0000-0000-0000-000000000001'::uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@admin.com') THEN
    UPDATE auth.users
    SET 
      instance_id = '00000000-0000-0000-0000-000000000000'::uuid,
      aud = 'authenticated',
      role = 'authenticated',
      encrypted_password = extensions.crypt('root360', extensions.gen_salt('bf')),
      email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
      raw_app_meta_data = '{"provider": "email", "providers": ["email"]}'::jsonb,
      raw_user_meta_data = jsonb_build_object(
        'full_name', 'System Administrator',
        'phone_number', '+265999000111',
        'role', 'admin'
      ),
      is_super_admin = false,
      updated_at = NOW()
    WHERE email = 'admin@admin.com';
  ELSE
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      is_super_admin
    ) VALUES (
      '00000000-0000-0000-0000-000000000000'::uuid,
      admin_id,
      'authenticated',
      'authenticated',
      'admin@admin.com',
      extensions.crypt('root360', extensions.gen_salt('bf')),
      NOW(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object(
        'full_name', 'System Administrator',
        'phone_number', '+265999000111',
        'role', 'admin'
      ),
      NOW(),
      NOW(),
      false
    );
  END IF;

  INSERT INTO public.profiles (id, full_name, phone_number, role, created_at)
  SELECT id, 'System Administrator', '+265999000111', 'admin', NOW()
  FROM auth.users
  WHERE email = 'admin@admin.com'
  ON CONFLICT (id) DO UPDATE
  SET role = 'admin',
      full_name = EXCLUDED.full_name,
      phone_number = EXCLUDED.phone_number;
END $$;
