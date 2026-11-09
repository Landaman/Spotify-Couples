<script lang="ts">
	import { goto, invalidateAll } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { navigating, page } from '$app/state';
	import PageHeader from '#lib/components/page-header.svelte';
	import { Button } from '#lib/components/ui/button/index.js';
	import * as Card from '#lib/components/ui/card/index.js';
	import * as NativeSelect from '#lib/components/ui/native-select/index.js';
	import { onMount } from 'svelte';
	import { SvelteURLSearchParams } from 'svelte/reactivity';
	import type { PageData } from './$types';
	import JournalContent from './journal-content.svelte';
	import DashboardSkeleton from './dashboard-skeleton.svelte';
	import PairingCompleteDialog from './pairing-complete-dialog.svelte';
	import { ShowPartnerSearchParameter } from './shared';

	const { data }: { /** Server-provided journal and authenticated profiles */ data: PageData } =
		$props();
	// Show the dialog based on page state
	let dialogOpen = $state(page.url.searchParams.get(ShowPartnerSearchParameter) == 'true');
	let retrying = $state(false);
	let timezone = $state<string>();

	$effect(() => {
		if (!dialogOpen && page.url.searchParams.has(ShowPartnerSearchParameter)) {
			// Make sure that back button doesn't go back to dialog open, that would be annoying...
			const url = new URL(page.url.href);
			url.searchParams.delete(ShowPartnerSearchParameter);
			// The resolve is pointless here
			// eslint-disable-next-line svelte/no-navigation-without-resolve
			void goto(url, { replace: true });
		}
	});

	onMount(() => {
		timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
		if (!page.url.searchParams.has('tz')) {
			void changeRange(data.days, timezone, true);
		}
	});

	/**
	 * Navigates with a single range and timezone for every section
	 * @param days - 1 for rolling 24 hours, otherwise calendar days including today
	 * @param zone - IANA timezone for boundaries and labels
	 * @param replaceState - Replace initial UTC fallback in browser history
	 * @returns Navigation completion
	 */
	async function changeRange(days: number, zone = data.timezone, replaceState = false) {
		const params = new SvelteURLSearchParams(page.url.searchParams.toString());
		params.set('days', String(days));
		params.set('tz', zone);
		// The query string is appended to a resolved app route
		// eslint-disable-next-line svelte/no-navigation-without-resolve
		await goto(`${resolve('/dashboard')}?${params}`, { replace: replaceState, reset: false });
	}

	/**
	 * Retries the journal request and clears the busy state after completion
	 * @returns Completion of the retry navigation
	 */
	async function retry() {
		retrying = true;
		try {
			await invalidateAll();
		} finally {
			retrying = false;
		}
	}
</script>

<PairingCompleteDialog user={data.session.user.profile} partner={data.partner} bind:dialogOpen />
<div class="flex w-full flex-col px-4 pt-4 pb-8 md:px-8 md:pt-6">
	<PageHeader title="Dashboard">
		{#snippet actions()}
			{#if timezone && data.timezone !== timezone}
				<Button variant="outline" size="sm" onclick={() => changeRange(data.days, timezone)}
					>Use my timezone</Button
				>
			{/if}
			<label class="sr-only" for="journal-range">Dashboard timeframe</label>
			<NativeSelect.Root
				id="journal-range"
				value={data.days}
				onchange={(event) => changeRange(Number(event.currentTarget.value))}
			>
				<NativeSelect.Option value={1}>Last 24 hours</NativeSelect.Option><NativeSelect.Option
					value={7}>Last 7 days</NativeSelect.Option
				><NativeSelect.Option value={30}>Last 30 days</NativeSelect.Option>
			</NativeSelect.Root>
		{/snippet}
	</PageHeader>
	<main class="min-w-0 pt-6 md:pb-12" aria-busy={!!navigating.to}>
		{#await data.journalResult}
			<DashboardSkeleton days={data.days} />
		{:then result}
			{#if result.journal}
				<JournalContent
					journal={result.journal}
					user={data.session.user.profile}
					partner={data.partner}
				/>
			{:else}
				<Card.Root role="alert" class="p-6">
					<p>{result.error}</p>
					<Button class="mt-4" variant="outline" disabled={retrying} onclick={retry}
						>{retrying ? 'Retrying…' : 'Try again'}</Button
					>
				</Card.Root>
			{/if}
		{/await}
	</main>
</div>
