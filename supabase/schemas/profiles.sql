CREATE TABLE public.profiles (
    id UUID NOT NULL PRIMARY KEY 
	    REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE,
    partner_id UUID UNIQUE
		REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable users to view their own data and their partners data" 
ON public.profiles 
FOR SELECT 
TO authenticated 
USING (
	    ((( SELECT auth.uid() ) = id) OR ((( SELECT auth.uid() ) IS NOT NULL) AND (( SELECT auth.uid() ) = partner_id)))
);
