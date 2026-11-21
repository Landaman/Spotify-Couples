<script lang="ts">
	import { buttonVariants } from '#lib/components/ui/button/index.js';
	import * as DropdownMenu from '#lib/components/ui/dropdown-menu/index.js';
	import { ChevronDown } from '@lucide/svelte';
	import { resolve } from '$app/paths';
	import { SvelteURLSearchParams } from 'svelte/reactivity';
	import { page } from '$app/state';
	import PageLayout from '#lib/components/page-layout.svelte';
	import {
		TopSongsListener,
		TopSongsListeners,
		TopSongsDateRanges,
		isTopSongsListener,
		ShowPartnerSearchParameter
	} from './shared';
	import { goto } from '$app/navigation';
	import TopSongsCard from './components/top-songs/top-songs-card.svelte';
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
	 * Change the selected listener while preserving the date range
	 * @param listener - Selected listener from the menu
	 * @returns Completion of the dashboard navigation
	 */
	async function selectListener(listener: string): Promise<void> {
		if (!isTopSongsListener(listener)) return;
		const search = new SvelteURLSearchParams(page.url.search);
		if (listener === TopSongsListener.combined) search.delete('listener');
		else search.set('listener', listener);
		await goto(resolve(`/dashboard?${search}`), { reset: false });
	}

	/**
	 * Change the selected date range while preserving the listener
	 * @param days - Number of days from the menu, or an empty string for all time
	 * @returns Completion of the dashboard navigation
	 */
	async function selectDateRange(days: string): Promise<void> {
		const search = new SvelteURLSearchParams(page.url.search);
		if (days === '') search.delete('range');
		else search.set('range', days);
		await goto(resolve(`/dashboard?${search}`), { reset: false });
	}
</script>

<PairingCompleteDialog user={userProfile} {partner} bind:dialogOpen />
<PageLayout title="Dashboard">
	{#snippet headingActions()}
		<DropdownMenu.Root>
			<DropdownMenu.Trigger
				class={buttonVariants({ variant: 'outline', class: 'min-w-0 shrink' })}
				aria-label={`Dashboard filters: ${listenerLabels[data.listener]}, ${data.dateRange.label}`}
			>
				<span
					class="flex min-w-0 flex-col items-start gap-x-1.5 leading-tight sm:flex-row sm:items-baseline"
				>
					<span class="max-w-full truncate">{listenerLabels[data.listener]}</span>
					<span aria-hidden="true" class="hidden text-muted-foreground sm:inline">·</span>
					<span class="max-w-full truncate max-sm:text-xs max-sm:text-muted-foreground sm:shrink-0">
						{data.dateRange.label}
					</span>
				</span>
				<ChevronDown class="text-muted-foreground" />
			</DropdownMenu.Trigger>
			<DropdownMenu.Content align="end" class="w-48">
				<DropdownMenu.Group>
					<DropdownMenu.Label>Listener</DropdownMenu.Label>
					<DropdownMenu.RadioGroup
						aria-label="Listener"
						value={data.listener}
						onValueChange={selectListener}
					>
						{#each TopSongsListeners as listener (listener)}
							<DropdownMenu.RadioItem value={listener} closeOnSelect>
								<span class="truncate">{listenerLabels[listener]}</span>
							</DropdownMenu.RadioItem>
						{/each}
					</DropdownMenu.RadioGroup>
				</DropdownMenu.Group>
				<DropdownMenu.Separator />
				<DropdownMenu.Group>
					<DropdownMenu.Label>Date range</DropdownMenu.Label>
					<!-- Radio items require a string value, so All time uses an empty string -->
					<DropdownMenu.RadioGroup
						aria-label="Date range"
						value={data.dateRange.days?.toString() ?? ''}
						onValueChange={selectDateRange}
					>
						{#each TopSongsDateRanges as range (range.days)}
							<DropdownMenu.RadioItem value={range.days?.toString() ?? ''} closeOnSelect>
								{range.label}
							</DropdownMenu.RadioItem>
						{/each}
					</DropdownMenu.RadioGroup>
				</DropdownMenu.Group>
			</DropdownMenu.Content>
		</DropdownMenu.Root>
	{/snippet}

	<TopSongsCard songs={data.songs} listener={data.listener} partnerName={partner.name} />
</PageLayout>
