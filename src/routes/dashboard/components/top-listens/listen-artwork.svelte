<script lang="ts">
	import SpotifyItemPicture from '#lib/components/spotify-item-picture.svelte';
	import { Music } from '@lucide/svelte';

	/** Artwork and accessible label for a ranking entry */
	interface Props {
		/** Cover or artist image URL, if available */
		src?: string | null;
		/** Name of the depicted artist or album */
		name: string;
	}

	const { src, name }: Props = $props();
</script>

{#if src}
	<SpotifyItemPicture class="w-14 md:w-20" {src} alt={name} />
{:else}
	<div
		class="grid aspect-square w-14 place-items-center rounded-sm bg-muted md:w-20 md:rounded-md"
		aria-hidden="true"
	>
		<Music class="size-5" />
	</div>
{/if}
