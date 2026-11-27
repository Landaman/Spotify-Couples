<script lang="ts">
	import type { getTopSongs } from '../../rankings.remote';
	import type { TopListensListener } from '../../shared';
	import ListenArtwork from './listen-artwork.svelte';
	import ListenTableRow from './listen-table-row.svelte';
	import PlayBreakdown from './play-breakdown.svelte';
	import RankingTable from './ranking-table.svelte';

	/** Song ranking data and listener context */
	interface Props {
		/** Query returning ranked tracks with album and artist metadata */
		query: ReturnType<typeof getTopSongs>;
		/** Listener whose counts are ranked */
		listener: TopListensListener;
		/** Name of the other listener for Combined breakdowns */
		partnerName: string;
	}
	const { query, listener, partnerName }: Props = $props();
</script>

<RankingTable {query} name="Song" artwork song>
	{#snippet rows(entries)}
		{#each entries as listen, index (listen.track.id)}
			{@const { track } = listen}
			{@const name = track.name ?? ''}
			<ListenTableRow {index}>
				{#snippet picture()}
					<ListenArtwork src={track.album?.picture_url} name={track.album?.name ?? name} />
				{/snippet}
				{#snippet details()}
					<h4 class="truncate text-base text-primary md:text-lg">{name}</h4>
					<h5 class="truncate">{track.artists?.map((artist) => artist.name).join(', ')}</h5>
				{/snippet}
				{#snippet album()}
					{track.album?.name}
				{/snippet}
				{#snippet plays()}
					<PlayBreakdown {listen} {name} {listener} {partnerName} />
				{/snippet}
			</ListenTableRow>
		{/each}
	{/snippet}
</RankingTable>
