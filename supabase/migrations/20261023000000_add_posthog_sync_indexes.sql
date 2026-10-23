-- Support time-filtered PostHog syncs independently of the user filter
CREATE INDEX plays_played_date_time_idx ON public.plays (played_date_time);

-- Support track foreign key checks during deletes and cascading ID updates
CREATE INDEX plays_track_id_idx ON public.plays (track_id);

-- Support album foreign key cascades without scanning every track
CREATE INDEX tracks_album_id_idx ON public.tracks (album_id);

-- Support the nightly cleanup of expired pairing codes
CREATE INDEX pairing_codes_expires_at_idx ON public.pairing_codes (expires_at);
