-- ==============================================================================
-- SheIn Connect: Admin Account Provisioning Script for Supabase
-- Credentials:
--   Email:    admin@admin.com
--   Password: root
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

SET search_path TO public, extensions, auth;

DO $$
DECLARE
  new_admin_id UUID := gen_random_uuid();
  admin_email TEXT := 'admin@admin.com';
  admin_password TEXT := 'root360';
  admin_name TEXT := 'System Administrator';
  admin_phone TEXT := '+265999000111';
BEGIN
  -- 1. If user already exists in auth.users, update password to 'root' and promote to admin
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = admin_email) THEN
    UPDATE auth.users
    SET instance_id = '00000000-0000-0000-0000-000000000000'::uuid,
        aud = 'authenticated',
        role = 'authenticated',
        encrypted_password = extensions.crypt(admin_password, extensions.gen_salt('bf')),
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        confirmation_token = COALESCE(confirmation_token, ''),
        recovery_token = COALESCE(recovery_token, ''),
        email_change = COALESCE(email_change, ''),
        email_change_token_new = COALESCE(email_change_token_new, ''),
        updated_at = NOW(),
        raw_app_meta_data = '{"provider": "email", "providers": ["email"]}'::jsonb,
        raw_user_meta_data = jsonb_set(
          COALESCE(raw_user_meta_data, '{}'::jsonb),
          '{role}',
          '"admin"'
        )
    WHERE email = admin_email;

    INSERT INTO public.profiles (id, full_name, phone_number, role, created_at)
    VALUES (
      (SELECT id FROM auth.users WHERE email = admin_email),
      admin_name,
      admin_phone,
      'admin',
      NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET role = 'admin',
        full_name = EXCLUDED.full_name,
        phone_number = EXCLUDED.phone_number;

    -- Ensure identity exists
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at, last_sign_in_at)
    SELECT id, id, jsonb_build_object('sub', id::text, 'email', email), 'email', id::text, NOW(), NOW(), NOW()
    FROM auth.users
    WHERE email = admin_email
    ON CONFLICT (provider, provider_id) DO NOTHING;

    RAISE NOTICE 'Existing user % updated with password "root" and admin role.', admin_email;
  ELSE
    -- 2. Create brand-new admin user in auth.users (confirmed email, password 'root')
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      confirmation_token,
      recovery_token,
      email_change,
      email_change_token_new,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      is_super_admin
    ) VALUES (
      '00000000-0000-0000-0000-000000000000'::uuid,
      new_admin_id,
      'authenticated',
      'authenticated',
      admin_email,
      extensions.crypt(admin_password, extensions.gen_salt('bf')),
      NOW(),
      '',
      '',
      '',
      '',
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object(
        'full_name', admin_name,
        'phone_number', admin_phone,
        'role', 'admin'
      ),
      NOW(),
      NOW(),
      false
    );

    -- 3. Insert profile record in public.profiles with role = 'admin'
    INSERT INTO public.profiles (id, full_name, phone_number, role, created_at)
    VALUES (
      new_admin_id,
      admin_name,
      admin_phone,
      'admin',
      NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET role = 'admin',
        full_name = EXCLUDED.full_name,
        phone_number = EXCLUDED.phone_number;

    -- 4. Insert identity
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at, last_sign_in_at)
    VALUES (
      new_admin_id,
      new_admin_id,
      jsonb_build_object('sub', new_admin_id::text, 'email', admin_email),
      'email',
      new_admin_id::text,
      NOW(),
      NOW(),
      NOW()
    )
    ON CONFLICT (provider, provider_id) DO NOTHING;

    RAISE NOTICE 'New admin account % created successfully with password "root".', admin_email;
  END IF;
END $$;
