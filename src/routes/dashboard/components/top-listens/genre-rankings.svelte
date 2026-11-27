<script lang="ts">
	import type { getTopGenres } from '../../rankings.remote';
	import type { TopListensListener } from '../../shared';
	import ListenTableRow from './listen-table-row.svelte';
	import PlayBreakdown from './play-breakdown.svelte';
	import RankingTable from './ranking-table.svelte';

	/** Genre ranking data and listener context */
	interface Props {
		/** Query returning genre names and counts */
		query: ReturnType<typeof getTopGenres>;
		/** Listener whose counts are ranked */
		listener: TopListensListener;
		/** Name of the other listener for Combined breakdowns */
		partnerName: string;
	}
	const { query, listener, partnerName }: Props = $props();
</script>

<RankingTable
	{query}
	name="Genre"
	emptyMessage="No genre data for this listener in the selected date range."
>
	{#snippet rows(entries)}
		{#each entries as listen, index (listen.name)}
			<ListenTableRow {index}>
				{#snippet details()}
					<h4 class="truncate text-base text-primary capitalize md:text-lg">{listen.name}</h4>
				{/snippet}
				{#snippet plays()}
					<PlayBreakdown {listen} name={listen.name} {listener} {partnerName} />
				{/snippet}
			</ListenTableRow>
		{/each}
	{/snippet}
</RankingTable>
