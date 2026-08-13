<script lang="ts">
	import * as Table from '$lib/components/ui/table';
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
	<Table.Cell class="w-px">{index + 1}</Table.Cell>
	<Table.Cell class="w-px pr-0">
		{@render picture()}
	</Table.Cell>
	<Table.Cell class="max-w-24 sm:max-w-full">
		{@render title()}
		{@render subtitle()}
	</Table.Cell>
	<Table.Cell>
		{@render album()}
	</Table.Cell>
	<Table.Cell>
		{@render plays()}
	</Table.Cell>
</Table.Row>
