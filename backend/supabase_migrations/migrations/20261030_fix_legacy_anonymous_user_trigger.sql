-- The legacy auth trigger predates anonymous accounts and inserted NEW.email
-- directly into public.users. Anonymous auth has no email, so this prevented
-- auth.users inserts from completing even though the newer trigger was safe.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, display_name, joined_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, NEW.id::text || '@guest.local'),
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name',
      CASE WHEN NEW.email IS NULL THEN 'FocusEcho user' ELSE split_part(NEW.email, '@', 1) END
    ),
    now()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_auth_user_created() FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
