<script lang="ts">
	import * as Table from '#lib/components/ui/table/index.js';
	import type { Snippet } from 'svelte';

	/** Cells shared by ranked entries and loading placeholders */
	interface Props {
		/** Zero-based rank */
		index: number;
		/** Artwork cell, when the category has artwork */
		picture?: Snippet;
		/** Entry title and optional subtitle */
		details: Snippet;
		/** Album cell for songs */
		album?: Snippet;
		/** Play count or breakdown */
		plays: Snippet;
	}

	let { index, picture, details, album, plays }: Props = $props();
</script>

<Table.Row>
	<Table.Cell class="w-px px-1.5 md:px-2">{index + 1}</Table.Cell>
	{#if picture}
		<Table.Cell class="w-px pr-0 pl-1.5 md:pl-2">
			{@render picture()}
		</Table.Cell>
	{/if}
	<Table.Cell class="px-1.5 md:px-2">
		{@render details()}
	</Table.Cell>
	{#if album}
		<Table.Cell class="truncate px-1.5 md:px-2">
			{@render album()}
		</Table.Cell>
	{/if}
	<Table.Cell class="px-1.5 md:px-2">
		{@render plays()}
	</Table.Cell>
</Table.Row>
