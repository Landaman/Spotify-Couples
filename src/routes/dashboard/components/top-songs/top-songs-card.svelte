<script lang="ts">
	import * as Card from '#lib/components/ui/card/index.js';
	import SongPlayBreakdown from './song-play-breakdown.svelte';
	import SongTableRow from './song-table-row.svelte';
	import SpotifyItemPicture from '#lib/components/spotify-item-picture.svelte';
	import { Skeleton } from '#lib/components/ui/skeleton/index.js';
	import * as Table from '#lib/components/ui/table/index.js';
	import type { PageData } from '../../$types';
	import { TopSongsListener } from '../../shared';

	/** Data needed to render the Top Songs card */
	interface Props {
		/** Streamed rankings, or null if loading failed */
		songs: PageData['songs'];
		/** Listener whose plays are ranked */
		listener: TopSongsListener;
		/** Name shown in the Combined play breakdown */
		partnerName: string;
	}

	const { songs, listener, partnerName }: Props = $props();
</script>

<Card.Root class="w-full bg-background">
	<Card.Header>
		<Card.Title class="text-xl font-semibold tracking-tight">Top Songs</Card.Title>
	</Card.Header>
	<Card.Content>
		<Table.Root class="table-fixed">
			<Table.Header>
				<Table.Row>
					<Table.Head class="w-8 px-1.5 md:px-2">#</Table.Head>
					<Table.Head class="w-17 px-1.5 md:w-24 md:px-2">Song</Table.Head>
					<Table.Head class="px-1.5 md:px-2"></Table.Head>
					<Table.Head class="w-[20%] px-1.5 md:w-[30%] md:px-2">Album</Table.Head>
					<Table.Head class="w-14 px-1.5 md:px-2">Plays</Table.Head>
				</Table.Row>
			</Table.Header>
			<Table.Body class="text-xs text-muted-foreground md:text-sm">
				{#await songs}
					{#each Array(5) as _, index (index)}
						<SongTableRow {index}>
							{#snippet picture()}
								<Skeleton class="aspect-square w-14 md:w-20" />
							{/snippet}
							{#snippet title()}
								<Skeleton class="mb-2 h-5 w-32 max-w-full" />
							{/snippet}
							{#snippet subtitle()}
								<Skeleton class="h-3 w-20 max-w-full" />
							{/snippet}
							{#snippet album()}
								<Skeleton class="h-4 w-24 max-w-full" />
							{/snippet}
							{#snippet plays()}
								<Skeleton class="h-4 w-8" />
							{/snippet}
						</SongTableRow>
					{/each}
				{:then rankedSongs}
					{#if rankedSongs === null}
						<Table.Row>
							<Table.Cell colspan={5} role="status" class="whitespace-normal">
								An unexpected error occurred loading your top songs. Please try again later.
							</Table.Cell>
						</Table.Row>
					{:else}
						{#each rankedSongs as song, index (index)}
							<SongTableRow {index}>
								{#snippet picture()}
									<SpotifyItemPicture
										class="w-14 md:w-20"
										src={song.track.album?.picture_url ?? ''}
										alt={song.track.album?.name ?? ''}
									/>
								{/snippet}
								{#snippet title()}
									<h4 class="truncate text-base text-primary md:text-lg">
										{song.track.name}
									</h4>
								{/snippet}
								{#snippet subtitle()}
									<h5 class="truncate">
										{song.track.artists?.map((artist) => artist.name).join(', ')}
									</h5>
								{/snippet}
								{#snippet album()}
									{song.track.album?.name}
								{/snippet}
								{#snippet plays()}
									{#if listener === TopSongsListener.combined}
										<SongPlayBreakdown {song} {partnerName} />
									{:else}
										{song.plays}
									{/if}
								{/snippet}
							</SongTableRow>
						{/each}
					{/if}
				{/await}
			</Table.Body>
		</Table.Root>
	</Card.Content>
</Card.Root>
