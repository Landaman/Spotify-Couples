<script lang="ts">
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';
	import * as AlertDialog from '$lib/components/ui/alert-dialog';
	import type { PageData } from './$types';
	import PresetPairingCode from './preset-pairing-code.svelte';
	import InputPairingCode from './input-pairing-code.svelte';
	import { InvalidCodeSearchParameter } from './shared';
	import { buttonVariants } from '$lib/components/ui/button';
	import { goto } from '$app/navigation';
	import { applyAction } from '$app/forms';

	// Users first name
	const userFirstName = page.data.session?.user.profile.name.split(' ')[0];

	interface Props {
		data: PageData;
	}
	const { data }: Props = $props();

	// This fades the users name in
	let isMounted = $state(false);
	onMount(() => {
		isMounted = true;

		return () => {
			isMounted = false;
		};
	});
</script>

<div class="flex w-full grow">
	<AlertDialog.Root
		open={page.status === 400 || page.url.searchParams.get(InvalidCodeSearchParameter) === 'true'}
	>
		<AlertDialog.Content>
			<AlertDialog.Header>
				<AlertDialog.Title>Invalid Pairing Code</AlertDialog.Title>
				<AlertDialog.Description>
					The pairing code you provided is either invalid or expired. Please contact your partner
					for a new code.
				</AlertDialog.Description>
			</AlertDialog.Header>

			<AlertDialog.Footer>
				<AlertDialog.Action
					onclick={async () => {
						if (page.url.searchParams.has(InvalidCodeSearchParameter)) {
							page.url.searchParams.delete(InvalidCodeSearchParameter);
							// No need to resolve, we're just going to the current page anyway
							// eslint-disable-next-line svelte/no-navigation-without-resolve
							return await goto(page.url);
						}

						// Reset form state
						return await applyAction({ status: 200, type: 'success' });
					}}>Continue</AlertDialog.Action
				>
			</AlertDialog.Footer>
		</AlertDialog.Content>
	</AlertDialog.Root>

	<div class="mx-auto flex max-w-min flex-col items-center justify-center gap-5 px-4 md:px-8">
		<div class="flex w-0 min-w-full flex-row items-center justify-center gap-2 md:gap-3">
			<div class="h-14 w-14 shrink-0 md:h-16 md:w-16">
				<enhanced:img src="$lib/assets/logo.png" alt="Spotify Couples" />
			</div>
			<h1 class="min-w-0 grow-0 text-3xl md:text-4xl">
				<span class="font-semibold">Welcome,</span>
				{#if isMounted}
					<span in:fade={{ duration: 500, delay: 250 }} class="wrap-break-word"
						>{userFirstName}</span
					>
				{:else}
					<span class="invisible wrap-break-word">{userFirstName}</span>
				{/if}
			</h1>
		</div>

		<p class="text-muted-foreground text-center text-xl">
			We're so excited to have you. Let's get you connected with your partner:
		</p>

		<div class="flex flex-col items-center gap-4 md:flex-row">
			<PresetPairingCode
				presetPairingCode={data.pairingCode}
				presetPairingCodeExpiry={data.pairingCodeExpiry}
			/>
			<p class="text-muted-foreground text-nowrap text-xl">- OR -</p>
			<InputPairingCode />
		</div>
	</div>
</div>
