<script lang="ts">
	import * as Card from '#lib/components/ui/card/index.js';
	import * as Select from '#lib/components/ui/select/index.js';
	import { ChevronDown } from '@lucide/svelte';
	import { Select as SelectPrimitive } from 'bits-ui';
	import { untrack } from 'svelte';
	import { getTopAlbums, getTopArtists, getTopGenres, getTopSongs } from '../../rankings.remote';
	import { TopListensCategories, type RankingFilters, type TopListensCategory } from '../../shared';
	import ArtworkRankings from './artwork-rankings.svelte';
	import GenreRankings from './genre-rankings.svelte';
	import SongRankings from './song-rankings.svelte';

	/** Selection and dashboard-wide filters for the card */
	interface Props {
		/** Kind of entry being ranked */
		category: TopListensCategory;
		/** Listener and date range for the ranking */
		filters: RankingFilters;
		/** Whether a dashboard-wide filter change is in flight */
		disabled: boolean;
		/** Name shown in the Combined play breakdown */
		partnerName: string;
		/** Update the category in the URL */
		onCategoryChange: (category: string) => void;
	}

	const { category, filters, disabled, partnerName, onCategoryChange }: Props = $props();
	const title = $derived(`Top ${TopListensCategories[category]}`);
	const rankings = {
		song: getTopSongs,
		artist: getTopArtists,
		album: getTopAlbums,
		genre: getTopGenres
	};

	let previousCategory: TopListensCategory | undefined;
	$effect(() => {
		const changed = previousCategory !== undefined && previousCategory !== category;
		previousCategory = category;
		if (!changed) return;

		// Refresh a previously viewed category without repeating a request already in flight
		untrack(() => {
			const result = rankings[category](filters);
			if (!result.loading && (result.ready || result.error)) {
				void result.refresh().catch(() => undefined);
			}
		});
	});
</script>

<Card.Root class="w-full bg-background">
	<Card.Header>
		<h2 class="text-xl font-semibold tracking-tight">
			<Select.Root type="single" value={category} onValueChange={onCategoryChange} {disabled}>
				<SelectPrimitive.Trigger
					aria-label={title}
					class="inline-flex cursor-pointer items-center gap-1.5 rounded-sm focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:outline-none"
				>
					{title}
					<ChevronDown class="size-4 text-muted-foreground" aria-hidden="true" />
				</SelectPrimitive.Trigger>
				<Select.Content align="start">
					{#each Object.entries(TopListensCategories) as [value, label] (value)}
						<Select.Item {value} {label} />
					{/each}
				</Select.Content>
			</Select.Root>
		</h2>
	</Card.Header>
	<Card.Content>
		{#if category === 'song'}
			<SongRankings query={rankings.song(filters)} listener={filters.listener} {partnerName} />
		{:else if category === 'artist'}
			<ArtworkRankings
				query={rankings.artist(filters)}
				name="Artist"
				listener={filters.listener}
				{partnerName}
			/>
		{:else if category === 'album'}
			<ArtworkRankings
				query={rankings.album(filters)}
				name="Album"
				listener={filters.listener}
				{partnerName}
			/>
		{:else}
			<GenreRankings query={rankings.genre(filters)} listener={filters.listener} {partnerName} />
		{/if}
	</Card.Content>
</Card.Root>
