<script lang="ts">
	import { page } from '$app/state';
	import { ShowPartnerSearchParameter } from './shared';
	import { goto } from '$app/navigation';
	import PairingCompleteDialog from './pairing-complete-dialog.svelte';
	import SongTableRow from './song-table-row.svelte';
	import SpotifyItemPicture from '$lib/components/spotify-item-picture.svelte';
	import { Skeleton } from '$lib/components/ui/skeleton';
	import * as Table from '$lib/components/ui/table';
	import type { PageData } from './$types';

	// Show the dialog based on page state
	let dialogOpen = $state(page.url.searchParams.get(ShowPartnerSearchParameter) == 'true');
	$effect(() => {
		if (!dialogOpen && page.url.searchParams.has(ShowPartnerSearchParameter)) {
			// Make sure that back button doesn't go back to dialog open, that would be annoying...
			page.url.searchParams.delete(ShowPartnerSearchParameter);
			// The resolve is pointless here
			// eslint-disable-next-line svelte/no-navigation-without-resolve
			goto(page.url, {
				replaceState: true
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
<div class="flex w-full flex-col gap-5 px-4 pt-2 md:px-8">
	<h1 class="text-3xl font-extrabold tracking-tight sm:text-4xl lg:text-5xl">My Top Songs</h1>
	<div class="border-border w-full rounded-lg border">
		<Table.Root>
			<Table.Header>
				<Table.Row>
					<Table.Head>#</Table.Head>
					<Table.Head>Song</Table.Head>
					<Table.Head></Table.Head>
					<Table.Head>Album</Table.Head>
					<Table.Head>Plays</Table.Head>
				</Table.Row>
			</Table.Header>
			<Table.Body class="text-muted-foreground text-xs md:text-sm">
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
								<Skeleton class="h-4 w-24" />
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
								<SpotifyItemPicture class="w-14 md:w-20" src={song.albumPicture} alt={song.album} />
							{/snippet}
							{#snippet title()}
								<h4 class="text-primary min-w-20 truncate text-base md:text-lg">
									{song.trackName}
								</h4>
							{/snippet}
							{#snippet subtitle()}
								<h5>{song.artist}</h5>
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
	</div>
</div>
