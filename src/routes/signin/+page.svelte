<script lang="ts">
	import { page } from '$app/stores';
	import { REDIRECT_TO_PARAM_NAME } from '$lib/constants';
	import { signIn } from '@auth/sveltekit/client';
	import { onMount } from 'svelte';

	// If this page renders, we need to log in, so do that immediately
	onMount(() => {
		signIn('spotify', {
			callbackUrl: $page.url.searchParams.get(REDIRECT_TO_PARAM_NAME) ?? undefined
		});
	});
</script>
