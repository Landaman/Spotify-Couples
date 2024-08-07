<script lang="ts">
	import { page } from '$app/stores';
	import { signIn } from '@auth/sveltekit/client';
	import { onMount } from 'svelte';
	import type { PageData } from './$types';

	// Page data, used for the redirect param pathname
	export let data: PageData;

	// If this page renders, we need to log in, so do that immediately
	onMount(() => {
		signIn('spotify', {
			callbackUrl: $page.url.searchParams.get(data.redirectToParamName) ?? undefined
		});
	});
</script>
