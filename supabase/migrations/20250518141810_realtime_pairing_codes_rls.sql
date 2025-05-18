CREATE POLICY "Users can listen to messages about their own pairing codes"
ON realtime.messages
FOR SELECT
TO AUTHENTICATED
USING (
  EXISTS (
    SELECT
      owner_id
    FROM
      public.pairing_codes
    WHERE
      owner_id = (select auth.uid())
      AND 'pairing_codes:' || CODE = (select realtime.topic())
      AND expires_at > NOW()
      AND realtime.messages.extension in ('broadcast')
  )
);
