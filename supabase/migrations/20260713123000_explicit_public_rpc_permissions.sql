REVOKE EXECUTE ON FUNCTION public.get_partner_id () FROM public;
REVOKE EXECUTE ON FUNCTION public.get_partner_id () FROM anon;
GRANT EXECUTE ON FUNCTION public.get_partner_id () TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_partner_id (uuid) FROM public;
REVOKE EXECUTE ON FUNCTION public.get_partner_id (uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_partner_id (uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_or_create_pairing_code () FROM public;
REVOKE EXECUTE ON FUNCTION public.get_or_create_pairing_code () FROM anon;
GRANT EXECUTE ON FUNCTION public.get_or_create_pairing_code () TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_partner_profile () FROM public;
REVOKE EXECUTE ON FUNCTION public.get_partner_profile () FROM anon;
GRANT EXECUTE ON FUNCTION public.get_partner_profile () TO authenticated;

REVOKE EXECUTE ON FUNCTION public.pair_with_code (character varying) FROM public;
REVOKE EXECUTE ON FUNCTION public.pair_with_code (character varying) FROM anon;
GRANT EXECUTE ON FUNCTION public.pair_with_code (character varying) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.process_spotify_refresh_token (text) FROM public;
REVOKE EXECUTE ON FUNCTION public.process_spotify_refresh_token (text) FROM anon;
GRANT EXECUTE ON FUNCTION public.process_spotify_refresh_token (text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.read_plays_for_user_if_needed () FROM public;
REVOKE EXECUTE ON FUNCTION public.read_plays_for_user_if_needed () FROM anon;
GRANT EXECUTE ON FUNCTION public.read_plays_for_user_if_needed () TO authenticated;

REVOKE EXECUTE ON FUNCTION public.user_needs_play_refresh () FROM public;
REVOKE EXECUTE ON FUNCTION public.user_needs_play_refresh () FROM anon;
GRANT EXECUTE ON FUNCTION public.user_needs_play_refresh () TO authenticated;
