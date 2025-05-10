CREATE TABLE IF NOT EXISTS public.plays (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    played_date_time TIMESTAMP WITH TIME ZONE NOT NULL,
    spotify_played_context_uri TEXT,
    spotify_id TEXT NOT NULL,
    user_id UUID NOT NULL 
	    REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE INDEX plays_user_id_idx ON public.plays (user_id);

ALTER TABLE public.plays ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable users to view their own and their partners plays" 
ON public.plays 
FOR SELECT 
	    USING (
	    ((( SELECT auth.uid() ) = user_id) OR (( SELECT profiles.partner_id FROM public.profiles WHERE (profiles.id = ( SELECT auth.uid() ))) = user_id))
	    );
