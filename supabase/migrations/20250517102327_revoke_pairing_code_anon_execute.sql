REVOKE EXECUTE ON FUNCTION public.pair_with_code FROM public;
REVOKE EXECUTE ON FUNCTION public.pair_with_code FROM anon;

REVOKE EXECUTE ON FUNCTION public.get_or_create_pairing_code FROM public;
REVOKE EXECUTE ON FUNCTION public.get_or_create_pairing_code FROM anon;
