CREATE TABLE public.plays (
  id uuid DEFAULT gen_random_uuid () NOT NULL PRIMARY KEY,
  played_date_time timestamp with time zone NOT NULL,
  spotify_played_context_uri text,
  spotify_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE INDEX plays_user_id_idx ON public.plays (user_id);

ALTER TABLE public.plays ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable users to view their own and their partners plays" ON public.plays FOR
SELECT
  USING (
    (
      (
        (
          SELECT
            auth.uid ()
        ) = user_id
      )
      OR (
        (
          SELECT
            profiles.partner_id
          FROM
            public.profiles
          WHERE
            (
              profiles.id = (
                SELECT
                  auth.uid ()
              )
            )
        ) = user_id
      )
    )
  );
