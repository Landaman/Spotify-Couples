CREATE TABLE public.pairing_codes (
    code CHARACTER VARYING NOT NULL PRIMARY KEY,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    owner_id UUID NOT NULL UNIQUE 
	    REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE
);

ALTER TABLE public.pairing_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable select for users to their own pairing codes" 
ON public.pairing_codes 
FOR SELECT 
	    TO authenticated 
	    USING (
			(( SELECT auth.uid() ) = owner_id)
	    );

CREATE POLICY "Enable users to create pairing codes for themselves" 
ON public.pairing_codes 
FOR INSERT 
TO authenticated 
	    WITH CHECK (
(( SELECT auth.uid() ) = owner_id)
);

CREATE POLICY "Enable delete for users to their own pairing code" 
ON public.pairing_codes 
FOR DELETE 
TO authenticated 
USING (
(( SELECT auth.uid() ) = owner_id)
);


CREATE FUNCTION public.pair_with_code(pairing_code character varying) RETURNS void
    LANGUAGE plpgsql
    SET "search_path" TO 'public'
    AS $$
DECLARE
  code_expiry TIMESTAMPTZ;
  code_owner_id UUID;
BEGIN  
  IF (SELECT partner_id FROM profiles WHERE id = auth.uid()) IS NOT NULL 
  THEN
    RAISE EXCEPTION 'Unable to pair with a code when the user already has a partner';
  END IF;

  SELECT owner_id, expires_at INTO code_owner_id, code_expiry FROM pairing_codes WHERE code = pairing_code;

  IF code_owner_id = auth.uid()
  THEN
    RAISE EXCEPTION 'Unable to pair with a code the user owns';
  END IF;

  IF code_expiry IS NULL OR code_expiry < NOW()
  THEN
    RAISE EXCEPTION 'Invalid pairing code';
  END IF;

  IF (SELECT partner_id FROM profiles WHERE id = code_owner_id) IS NOT NULL
  THEN
    RAISE EXCEPTION 'Unable to pair with a code from a user that has a partner';
  END IF;

  UPDATE profiles SET partner_id = code_owner_id WHERE id = auth.uid();
  UPDATE profiles SET partner_id = auth.uid() WHERE id = code_owner_id;

  DELETE FROM pairing_codes WHERE code = pairing_code;
END;
$$;
