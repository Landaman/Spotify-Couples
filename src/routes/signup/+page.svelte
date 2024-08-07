<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';
	import PresetPairingCode from './preset-pairing-code.svelte';
	import InputPairingCode from './input-pairing-code.svelte';
	import type { PageData } from './$types';

	// Users first name
	const userFirstName = $page.data.session?.user?.name?.split(' ')[0];

	export let data: PageData;

	// This fades the users name in
	let isMounted = false;
	onMount(() => {
		isMounted = true;

		return () => {
			isMounted = false;
		};
	});
</script>

<div class="flex w-full flex-grow">
	<div class="mx-auto flex max-w-min flex-col items-center justify-center gap-5 px-4 md:px-8">
		<div class="flex flex-row items-center gap-2 md:gap-3">
			<enhanced:img
				src="$lib/assets/logo.png"
				alt="Spotify Couples"
				class="h-14 w-14 flex-shrink-0 md:h-16 md:w-16"
			/>
			<h1 class="text-3xl md:text-4xl">
				<span class="font-semibold">Welcome,</span>
				{#if isMounted}
					<span in:fade={{ duration: 500, delay: 250 }}>{userFirstName}</span>
				{:else}
					<span class="invisible">{userFirstName}</span>
				{/if}
			</h1>
		</div>

		<p class="text-xl text-muted-foreground">
			We're so excited to have you. Let's get you connected with your partner:
		</p>

		<div class="flex flex-col items-center gap-4 md:flex-row">
			<PresetPairingCode
				presetPairingCode={data.pairingCode}
				secondsLeftToCodeExpiry={data.pairingCodeSecondsToExpiry}
			/>
			<p class="text-nowrap text-xl text-muted-foreground">- OR -</p>
			<InputPairingCode />
		</div>
	</div>
</div>
