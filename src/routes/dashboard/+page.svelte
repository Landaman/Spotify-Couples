<script lang="ts">
	import * as Select from '#lib/components/ui/select/index.js';
	import { resolve } from '$app/paths';
	import { SvelteURLSearchParams } from 'svelte/reactivity';
	import { page } from '$app/state';
	import PageLayout from '#lib/components/page-layout.svelte';
	import {
		TopSongsListener,
		TopSongsListeners,
		isTopSongsListener,
		ShowPartnerSearchParameter
	} from './shared';
	import { goto } from '$app/navigation';
	import TopSongsCard from './components/top-songs-card.svelte';
	import PairingCompleteDialog from './pairing-complete-dialog.svelte';
	import type { PageData } from './$types';

	// Show the dialog based on page state
	let dialogOpen = $state(page.url.searchParams.get(ShowPartnerSearchParameter) == 'true');
	$effect(() => {
		if (!dialogOpen && page.url.searchParams.has(ShowPartnerSearchParameter)) {
			// Make sure that back button doesn't go back to dialog open, that would be annoying...
			const url = new URL(page.url.href);
			url.searchParams.delete(ShowPartnerSearchParameter);
			// The resolve is pointless here
			// eslint-disable-next-line svelte/no-navigation-without-resolve
			goto(url, {
				replace: true
			});
		}
	});

	const {
		data
	}: {
		data: PageData;
	} = $props();
	const {
		session: {
			user: { profile: userProfile }
		},
		partner
	} = $derived(data);

	/** Display labels for each Top Songs listener */
	const listenerLabels: Record<TopSongsListener, string> = $derived({
		combined: 'Combined',
		you: 'You',
		partner: partner.name
	});

	/**
	 * Navigate to the selected listener's ranking, preserving other URL parameters
	 * @param listener - Combined, current user, or partner ranking
	 * @returns Completion of the dashboard navigation
	 */
	async function selectListener(listener: string): Promise<void> {
		if (!isTopSongsListener(listener)) return;
		const search = new SvelteURLSearchParams(page.url.search);
		if (listener === TopSongsListener.combined) search.delete('listener');
		else search.set('listener', listener);
		await goto(resolve(`/dashboard?${search}`), { reset: false });
	}
</script>

<PairingCompleteDialog user={userProfile} {partner} bind:dialogOpen />
<PageLayout title="Dashboard">
	{#snippet headingActions()}
		<Select.Root type="single" value={data.listener} onValueChange={selectListener}>
			<Select.Trigger aria-label="Top Songs listener" class="w-40 min-w-0">
				<span class="truncate">{listenerLabels[data.listener]}</span>
			</Select.Trigger>
			<Select.Content>
				{#each TopSongsListeners as listener (listener)}
					<Select.Item value={listener} label={listenerLabels[listener]}>
						{listenerLabels[listener]}
					</Select.Item>
				{/each}
			</Select.Content>
		</Select.Root>
	{/snippet}

	<TopSongsCard songs={data.songs} listener={data.listener} partnerName={partner.name} />
</PageLayout>
