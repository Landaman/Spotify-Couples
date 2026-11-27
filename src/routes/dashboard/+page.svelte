<script lang="ts">
	import { buttonVariants } from '#lib/components/ui/button/index.js';
	import * as DropdownMenu from '#lib/components/ui/dropdown-menu/index.js';
	import { ChevronDown } from '@lucide/svelte';
	import { resolve } from '$app/paths';
	import { SvelteURLSearchParams } from 'svelte/reactivity';
	import { navigating, page } from '$app/state';
	import PageLayout from '#lib/components/page-layout.svelte';
	import {
		TopListensListener,
		TopListensListeners,
		TopListensDateRanges,
		findTopListensDateRange,
		isTopListensCategory,
		isTopListensListener,
		parseTopListensCategory,
		parseTopListensListener,
		ShowPartnerSearchParameter
	} from './shared';
	import { goto } from '$app/navigation';
	import TopListensCard from './components/top-listens/top-listens-card.svelte';
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

	/** Display labels for each Top Listens listener */
	const listenerLabels: Record<TopListensListener, string> = $derived({
		combined: 'Combined',
		you: 'You',
		partner: partner.name
	});

	/** Target of an in-progress dashboard navigation */
	const pendingUrl = $derived(
		navigating.type !== null && !navigating.shallow && navigating.to?.route.id === '/dashboard'
			? navigating.to.url
			: null
	);
	/** URL including a category selected through shallow navigation */
	const dashboardUrl = $derived(page.shallow?.url ?? page.url);
	/** Listener to show in the picker while results load */
	const selectedListener = $derived(
		pendingUrl ? parseTopListensListener(pendingUrl.searchParams.get('listener')) : data.listener
	);
	/** Date range to show in the picker while results load */
	const selectedDateRange = $derived(
		pendingUrl
			? (findTopListensDateRange(pendingUrl.searchParams.get('range')) ?? data.dateRange)
			: data.dateRange
	);
	/** Category to show in the card while navigation loads */
	const selectedCategory = $derived(
		parseTopListensCategory(dashboardUrl.searchParams.get('category'))
	);

	/**
	 * Change the selected listener while preserving the date range
	 * @param listener - Selected listener from the menu
	 * @returns Completion of the dashboard navigation
	 */
	async function selectListener(listener: string): Promise<void> {
		if (!isTopListensListener(listener)) return;
		const search = new SvelteURLSearchParams((pendingUrl ?? dashboardUrl).search);
		if (listener === TopListensListener.combined) search.delete('listener');
		else search.set('listener', listener);
		await goto(resolve(`/dashboard?${search}`), { reset: false });
	}

	/**
	 * Change the selected date range while preserving the listener
	 * @param days - Number of days from the menu, or an empty string for all time
	 * @returns Completion of the dashboard navigation
	 */
	async function selectDateRange(days: string): Promise<void> {
		const search = new SvelteURLSearchParams((pendingUrl ?? dashboardUrl).search);
		if (days === '') search.delete('range');
		else search.set('range', days);
		await goto(resolve(`/dashboard?${search}`), { reset: false });
	}

	/**
	 * Change the Top Listens category while preserving the dashboard filters
	 * @param category - Selected category from the card
	 * @returns Completion of the dashboard navigation
	 */
	async function selectCategory(category: string): Promise<void> {
		if (pendingUrl || !isTopListensCategory(category)) return;
		const search = new SvelteURLSearchParams(dashboardUrl.search);
		if (category === 'song') search.delete('category');
		else search.set('category', category);
		await goto(resolve(`/dashboard?${search}`), { shallow: true, state: page.state });
	}
</script>

<PairingCompleteDialog user={userProfile} {partner} bind:dialogOpen />
<PageLayout title="Dashboard">
	{#snippet headingActions()}
		<DropdownMenu.Root>
			<DropdownMenu.Trigger
				class={buttonVariants({ variant: 'outline', class: 'min-w-0 shrink' })}
				aria-label={`Dashboard filters: ${listenerLabels[selectedListener]}, ${selectedDateRange.label}`}
			>
				<span
					class="flex min-w-0 flex-col items-start gap-x-1.5 leading-tight sm:flex-row sm:items-baseline"
				>
					<span class="max-w-full truncate">{listenerLabels[selectedListener]}</span>
					<span aria-hidden="true" class="hidden text-muted-foreground sm:inline">·</span>
					<span class="max-w-full truncate max-sm:text-xs max-sm:text-muted-foreground sm:shrink-0">
						{selectedDateRange.label}
					</span>
				</span>
				<ChevronDown class="text-muted-foreground" />
			</DropdownMenu.Trigger>
			<DropdownMenu.Content align="end" class="w-48">
				<DropdownMenu.Group>
					<DropdownMenu.Label>Listener</DropdownMenu.Label>
					<DropdownMenu.RadioGroup
						aria-label="Listener"
						value={selectedListener}
						onValueChange={selectListener}
					>
						{#each TopListensListeners as listener (listener)}
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
						value={selectedDateRange.days?.toString() ?? ''}
						onValueChange={selectDateRange}
					>
						{#each TopListensDateRanges as range (range.days)}
							<DropdownMenu.RadioItem value={range.days?.toString() ?? ''} closeOnSelect>
								{range.label}
							</DropdownMenu.RadioItem>
						{/each}
					</DropdownMenu.RadioGroup>
				</DropdownMenu.Group>
			</DropdownMenu.Content>
		</DropdownMenu.Root>
	{/snippet}

	<TopListensCard
		category={selectedCategory}
		filters={{ listener: data.listener, rangeDays: data.dateRange.days ?? null }}
		disabled={pendingUrl !== null}
		partnerName={partner.name}
		onCategoryChange={selectCategory}
	/>
</PageLayout>
