<script lang="ts">
	import type { getTopAlbums, getTopArtists } from '../../rankings.remote';
	import type { TopListensListener } from '../../shared';
	import ListenArtwork from './listen-artwork.svelte';
	import ListenTableRow from './listen-table-row.svelte';
	import PlayBreakdown from './play-breakdown.svelte';
	import RankingTable from './ranking-table.svelte';

	/** The artist and album rankings share the artwork/name layout */
	interface Props {
		/** Category-specific artist or album query */
		query: ReturnType<typeof getTopAlbums> | ReturnType<typeof getTopArtists>;
		/** Label for the name column */
		name: 'Artist' | 'Album';
		/** Listener whose counts are ranked */
		listener: TopListensListener;
		/** Name of the other listener for Combined breakdowns */
		partnerName: string;
	}
	const { query, name, listener, partnerName }: Props = $props();
</script>

<RankingTable {query} {name} artwork>
	{#snippet rows(entries)}
		{#each entries as listen, index (listen.id)}
			<ListenTableRow {index}>
				{#snippet picture()}
					<ListenArtwork src={listen.picture_url} name={listen.name} />
				{/snippet}
				{#snippet details()}
					<h4 class="truncate text-base text-primary md:text-lg">{listen.name}</h4>
				{/snippet}
				{#snippet plays()}
					<PlayBreakdown {listen} name={listen.name} {listener} {partnerName} />
				{/snippet}
			</ListenTableRow>
		{/each}
	{/snippet}
</RankingTable>
