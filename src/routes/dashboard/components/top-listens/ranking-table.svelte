<script lang="ts" generics="Row">
	import type { RemoteQuery } from '$app/server';
	import { Skeleton } from '#lib/components/ui/skeleton/index.js';
	import * as Table from '#lib/components/ui/table/index.js';
	import type { Snippet } from 'svelte';
	import ListenTableRow from './listen-table-row.svelte';

	/** Layout and status rendering shared by the ranking tables */
	interface Props {
		/** Category query whose data is rendered by the caller */
		query: RemoteQuery<Row[] | null>;
		/** Singular label of the ranked entry */
		name: string;
		/** Whether the table has artwork */
		artwork?: boolean;
		/** Whether the table has the song-specific album column and artist subtitle */
		song?: boolean;
		/** Message shown when the query returns no rows */
		emptyMessage?: string;
		/** Rows for the category's typed query result */
		rows: Snippet<[Row[]]>;
	}

	const {
		query,
		name,
		artwork = false,
		song = false,
		emptyMessage = 'No plays for this listener in the selected date range.',
		rows
	}: Props = $props();
	const columnCount = $derived(3 + Number(artwork) + Number(song));
</script>

{#snippet status(message: string)}
	<Table.Row>
		<Table.Cell colspan={columnCount} role="status" class="whitespace-normal">
			{message}
		</Table.Cell>
	</Table.Row>
{/snippet}

<Table.Root class="table-fixed">
	<Table.Header>
		<Table.Row>
			<Table.Head scope="col" class="w-8 px-1.5 md:px-2">#</Table.Head>
			{#if artwork}
				<Table.Head scope="col" class="w-17 px-1.5 md:w-24 md:px-2">
					<span class="sr-only">Artwork</span>
				</Table.Head>
			{/if}
			<Table.Head scope="col" class="px-1.5 md:px-2">{name}</Table.Head>
			{#if song}
				<Table.Head scope="col" class="w-[20%] px-1.5 md:w-[30%] md:px-2">Album</Table.Head>
			{/if}
			<Table.Head scope="col" class="w-14 px-1.5 md:px-2">Plays</Table.Head>
		</Table.Row>
	</Table.Header>
	<Table.Body class="text-xs text-muted-foreground md:text-sm">
		{#if query.loading || (!query.ready && !query.error)}
			{#each Array(5) as _, index (index)}
				{#snippet picture()}
					<Skeleton class="aspect-square w-14 md:w-20" />
				{/snippet}
				{#snippet album()}
					<Skeleton class="h-4 w-24 max-w-full" />
				{/snippet}
				<ListenTableRow
					{index}
					picture={artwork ? picture : undefined}
					album={song ? album : undefined}
				>
					{#snippet details()}
						<Skeleton class="h-5 w-32 max-w-full" />
						{#if song}
							<Skeleton class="mt-2 h-3 w-20 max-w-full" />
						{/if}
					{/snippet}
					{#snippet plays()}
						<Skeleton class="h-4 w-8" />
					{/snippet}
				</ListenTableRow>
			{/each}
		{:else if query.error || !query.current}
			{@render status(
				`An unexpected error occurred loading your top ${name.toLowerCase()}s. Please try again later.`
			)}
		{:else if query.current.length === 0}
			{@render status(emptyMessage)}
		{:else}
			{@render rows(query.current)}
		{/if}
	</Table.Body>
</Table.Root>
