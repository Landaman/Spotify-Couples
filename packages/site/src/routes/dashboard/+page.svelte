<script lang="ts">
	import { page } from '$app/stores';
	import { ShowPartnerSearchParameter } from './shared';
	import { goto } from '$app/navigation';
	import PairingCompleteDialog from './pairing-complete-dialog.svelte';
	import SpotifyItemPicture from '$lib/components/spotify-item-picture.svelte';
	import * as Table from '$lib/components/ui/table';
	import type { PageData } from './$types';

	// Show the dialog based on page state
	let dialogOpen = $state($page.url.searchParams.get(ShowPartnerSearchParameter) == 'true');
	$effect(() => {
		if (!dialogOpen) {
			// Make sure that back button doesn't go back to dialog open, that would be annoying...
			goto('/dashboard', {
				replaceState: true
			});
		}
	});

	const {
		data
	}: {
		data: PageData;
	} = $props();
	console.log(data);
</script>

{#if $page.data.user && $page.data.partner}
	<PairingCompleteDialog user={$page.data.user} partner={$page.data.partner} bind:dialogOpen />
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
					{#each data.songs as song, index}
						<Table.Row class="group">
							<Table.Cell class="w-[1px]">{index + 1}</Table.Cell>
							<Table.Cell class="w-[1px] pr-0">
								<SpotifyItemPicture class="w-14 md:w-20" src={song.albumPicture} alt={song.album} />
							</Table.Cell>
							<Table.Cell class="max-w-24 sm:max-w-full">
								<h4 class="text-primary min-w-20 truncate text-base md:text-lg">
									{song.trackName}
								</h4>
								<h5>{song.artist}</h5>
							</Table.Cell>
							<Table.Cell>
								{song.album}
							</Table.Cell>
							<Table.Cell>{song.plays}</Table.Cell>
						</Table.Row>
					{/each}
				</Table.Body>
			</Table.Root>
		</div>
	</div>
{/if}
