-- Function to check if an email already exists in auth.users
-- This is used for real-time validation during sign-up.

CREATE OR REPLACE FUNCTION check_if_email_exists(email_check TEXT)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM auth.users WHERE email = email_check);
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to anon and authenticated users
GRANT EXECUTE ON FUNCTION check_if_email_exists(TEXT) TO anon, authenticated, service_role;
