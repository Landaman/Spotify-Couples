<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';

	const userName = $page.data.session?.user?.name?.split(' ')[0];

	// This fades the users name in
	let isMounted = false;
	onMount(() => {
		isMounted = true;

		return () => {
			isMounted = false;
		};
	});
</script>

<div class="flex flex-col gap-4 px-4 md:px-8">
	<div class="flex flex-row items-center gap-1 md:gap-3">
		<enhanced:img
			src="$lib/assets/logo.png"
			alt="Spotify Couples"
			class="h-14 w-14 flex-shrink-0 md:h-16 md:w-16"
		/>
		<h1 class="text-3xl md:text-4xl">
			<span class="font-semibold">Welcome,</span>
			{#if isMounted}
				<span in:fade={{ duration: 500 }}>{userName}</span>
			{/if}
		</h1>
	</div>
</div>
