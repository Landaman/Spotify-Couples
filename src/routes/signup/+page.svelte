<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';
	import PresetPairingCode from './preset-pairing-code.svelte';
	import InputPairingCode from './input-pairing-code.svelte';
	import type { PageData } from './$types';

	// Users first name
	const userFirstName = $page.data.user?.displayName.split(' ')[0];

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
		<div class="flex w-0 min-w-full flex-row items-center justify-center gap-2 md:gap-3">
			<div class="h-14 w-14 flex-shrink-0 md:h-16 md:w-16">
				<enhanced:img src="$lib/assets/logo.png" alt="Spotify Couples" />
			</div>
			<h1 class="min-w-0 flex-grow-0 text-3xl md:text-4xl">
				<span class="font-semibold">Welcome,</span>
				{#if isMounted}
					<span in:fade={{ duration: 500, delay: 250 }} class="break-words">{userFirstName}</span>
				{:else}
					<span class="invisible break-words">{userFirstName}</span>
				{/if}
			</h1>
		</div>

		<p class="text-center text-xl text-muted-foreground">
			We're so excited to have you. Let's get you connected with your partner:
		</p>

		<div class="flex flex-col items-center gap-4 md:flex-row">
			<PresetPairingCode
				presetPairingCode={data.pairingCode}
				presetPairingCodeExpiry={data.pairingCodeExpiry}
			/>
			<p class="text-nowrap text-xl text-muted-foreground">- OR -</p>
			<InputPairingCode />
		</div>
	</div>
</div>
