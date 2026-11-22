<script lang="ts">
	import * as Table from '#lib/components/ui/table/index.js';
	import type { Snippet } from 'svelte';

	interface Props {
		index: number;
		picture: Snippet;
		title: Snippet;
		subtitle: Snippet;
		album: Snippet;
		plays: Snippet;
	}

	let { index, picture, title, subtitle, album, plays }: Props = $props();
</script>

<Table.Row>
	<Table.Cell class="w-px px-1.5 md:px-2">{index + 1}</Table.Cell>
	<Table.Cell class="w-px pr-0 pl-1.5 md:pl-2">
		{@render picture()}
	</Table.Cell>
	<Table.Cell class="px-1.5 md:px-2">
		{@render title()}
		{@render subtitle()}
	</Table.Cell>
	<Table.Cell class="truncate px-1.5 md:px-2">
		{@render album()}
	</Table.Cell>
	<Table.Cell class="px-1.5 md:px-2">
		{@render plays()}
	</Table.Cell>
</Table.Row>
