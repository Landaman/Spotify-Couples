<script lang="ts">
	import * as Card from '#lib/components/ui/card/index.js';
	import { page } from '$app/state';
	import PageLayout from '#lib/components/page-layout.svelte';
	import { ShowPartnerSearchParameter } from './shared';
	import { goto } from '$app/navigation';
	import PairingCompleteDialog from './pairing-complete-dialog.svelte';
	import SongTableRow from './song-table-row.svelte';
	import SpotifyItemPicture from '#lib/components/spotify-item-picture.svelte';
	import { Skeleton } from '#lib/components/ui/skeleton/index.js';
	import * as Table from '#lib/components/ui/table/index.js';
	import type { PageData } from './$types';

	// Show the dialog based on page state
	let dialogOpen = $state(page.url.searchParams.get(ShowPartnerSearchParameter) == 'true');
	$effect(() => {
		if (!dialogOpen && page.url.searchParams.has(ShowPartnerSearchParameter)) {
			// Make sure that back button doesn't go back to dialog open, that would be annoying...
			const url = new URL(page.url.href);
			url.searchParams.delete(ShowPartnerSearchParameter);
			// The resolve is pointless here
			// eslint-disable-next-line svelte/no-navigation-without-resolve
			goto(url, {
				replace: true
			});
		}
	});

	const {
		data
	}: {
		data: PageData;
	} = $props();
	const {
		session: {
			user: { profile: userProfile }
		},
		partner
	} = $derived(data);
</script>

<PairingCompleteDialog user={userProfile} {partner} bind:dialogOpen />
<PageLayout title="Dashboard">
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
					{#await data.songs}
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
					{:then songs}
						{#each songs as song, index (index)}
							<SongTableRow {index}>
								{#snippet picture()}
									<SpotifyItemPicture
										class="w-14 md:w-20"
										src={song.albumPicture}
										alt={song.album}
									/>
								{/snippet}
								{#snippet title()}
									<h4 class="truncate text-base text-primary md:text-lg">
										{song.trackName}
									</h4>
								{/snippet}
								{#snippet subtitle()}
									<h5 class="truncate">{song.artist}</h5>
								{/snippet}
								{#snippet album()}
									{song.album}
								{/snippet}
								{#snippet plays()}
									{song.plays}
								{/snippet}
							</SongTableRow>
						{/each}
					{/await}
				</Table.Body>
			</Table.Root>
		</Card.Content>
	</Card.Root>
</PageLayout>
