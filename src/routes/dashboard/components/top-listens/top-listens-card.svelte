<script lang="ts">
	import SpotifyItemPicture from '#lib/components/spotify-item-picture.svelte';
	import * as Card from '#lib/components/ui/card/index.js';
	import * as Select from '#lib/components/ui/select/index.js';
	import { Skeleton } from '#lib/components/ui/skeleton/index.js';
	import * as Table from '#lib/components/ui/table/index.js';
	import { ChevronDown, Music } from '@lucide/svelte';
	import { Select as SelectPrimitive } from 'bits-ui';
	import type { PageData } from '../../$types';
	import { TopListensCategories, TopListensListener, type TopListensCategory } from '../../shared';
	import ListenTableRow from './listen-table-row.svelte';
	import PlayBreakdown from './play-breakdown.svelte';

	/** Data needed to render the Top Listens card */
	interface Props {
		/** Streamed rankings, or undefined while waiting for the selected category */
		listens: PageData['listens'] | undefined;
		/** Kind of entry being ranked */
		category: TopListensCategory;
		/** Listener whose plays are ranked */
		listener: TopListensListener;
		/** Name shown in the Combined play breakdown */
		partnerName: string;
		/** Update the category when the selector changes */
		onCategoryChange: (category: string) => void;
	}

	const { listens, category, listener, partnerName, onCategoryChange }: Props = $props();
	const title = $derived(`Top ${TopListensCategories[category]}`);
	const showPicture = $derived(category !== 'genre');
	const showAlbum = $derived(category === 'song');
	const columnCount = $derived(3 + Number(showPicture) + Number(showAlbum));
</script>

{#snippet loadingRows()}
	{#each Array(5) as _, index (index)}
		{#snippet picture()}
			<Skeleton class="aspect-square w-14 md:w-20" />
		{/snippet}
		{#snippet album()}
			<Skeleton class="h-4 w-24 max-w-full" />
		{/snippet}
		<ListenTableRow
			{index}
			picture={showPicture ? picture : undefined}
			album={showAlbum ? album : undefined}
		>
			{#snippet details()}
				<Skeleton class="h-5 w-32 max-w-full" />
				{#if showAlbum}
					<Skeleton class="mt-2 h-3 w-20 max-w-full" />
				{/if}
			{/snippet}
			{#snippet plays()}
				<Skeleton class="h-4 w-8" />
			{/snippet}
		</ListenTableRow>
	{/each}
{/snippet}

<Card.Root class="w-full bg-background">
	<Card.Header>
		<h2 class="text-xl font-semibold tracking-tight">
			<Select.Root type="single" value={category} onValueChange={onCategoryChange}>
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
		<Table.Root class="table-fixed">
			<Table.Header>
				<Table.Row>
					<Table.Head scope="col" class="w-8 px-1.5 md:px-2">#</Table.Head>
					{#if showPicture}
						<Table.Head scope="col" class="w-17 px-1.5 md:w-24 md:px-2">
							<span class="sr-only">Artwork</span>
						</Table.Head>
					{/if}
					<Table.Head scope="col" class="px-1.5 capitalize md:px-2">{category}</Table.Head>
					{#if showAlbum}
						<Table.Head scope="col" class="w-[20%] px-1.5 md:w-[30%] md:px-2">Album</Table.Head>
					{/if}
					<Table.Head scope="col" class="w-14 px-1.5 md:px-2">Plays</Table.Head>
				</Table.Row>
			</Table.Header>
			<Table.Body class="text-xs text-muted-foreground md:text-sm">
				{#await listens}
					{@render loadingRows()}
				{:then rankedListens}
					{#if rankedListens === undefined}
						{@render loadingRows()}
					{:else if rankedListens === null}
						<Table.Row>
							<Table.Cell colspan={columnCount} role="status" class="whitespace-normal">
								An unexpected error occurred loading your top {TopListensCategories[
									category
								].toLowerCase()}. Please try again later.
							</Table.Cell>
						</Table.Row>
					{:else if rankedListens.length === 0}
						<Table.Row>
							<Table.Cell colspan={columnCount} role="status" class="whitespace-normal">
								{category === 'genre'
									? 'No genre data for this listener in the selected date range.'
									: 'No plays for this listener in the selected date range.'}
							</Table.Cell>
						</Table.Row>
					{:else}
						{#each rankedListens as listen, index ('track' in listen ? listen.track.id : 'id' in listen ? listen.id : listen.name)}
							{@const song = 'track' in listen ? listen.track : undefined}
							{@const name = 'name' in listen ? listen.name : (song?.name ?? '')}
							{@const pictureUrl =
								'picture_url' in listen ? listen.picture_url : song?.album?.picture_url}
							{@const artists = song?.artists?.map((artist) => artist.name).join(', ')}
							{#snippet picture()}
								{#if pictureUrl}
									<SpotifyItemPicture
										class="w-14 md:w-20"
										src={pictureUrl}
										alt={song?.album?.name ?? name}
									/>
								{:else}
									<div
										class="grid aspect-square w-14 place-items-center rounded-sm bg-muted md:w-20 md:rounded-md"
										aria-hidden="true"
									>
										<Music class="size-5" />
									</div>
								{/if}
							{/snippet}
							{#snippet album()}
								{song?.album?.name}
							{/snippet}
							<ListenTableRow
								{index}
								picture={showPicture ? picture : undefined}
								album={showAlbum ? album : undefined}
							>
								{#snippet details()}
									<h4
										class="truncate text-base text-primary md:text-lg"
										class:capitalize={category === 'genre'}
									>
										{name}
									</h4>
									{#if artists}
										<h5 class="truncate">{artists}</h5>
									{/if}
								{/snippet}
								{#snippet plays()}
									{#if listener === TopListensListener.combined}
										<PlayBreakdown {listen} {name} {partnerName} />
									{:else}
										{listen.plays}
									{/if}
								{/snippet}
							</ListenTableRow>
						{/each}
					{/if}
				{/await}
			</Table.Body>
		</Table.Root>
	</Card.Content>
</Card.Root>
