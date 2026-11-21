<script lang="ts">
	import * as HoverCard from '#lib/components/ui/hover-card/index.js';
	import type { Database } from '#supabase/schema.js';

	/** Data shown in a combined play count breakdown */
	interface Props {
		/** Ranked track and its play counts */
		song: Database['public']['Functions']['get_top_songs']['Returns'][number];
		/** Name of the other listener */
		partnerName: string;
	}

	const { song, partnerName }: Props = $props();
	const breakdownId = $props.id();
	let open = $state(false);
</script>

<HoverCard.Root bind:open>
	<HoverCard.Trigger>
		{#snippet child({ props })}
			<button
				{...props}
				type="button"
				class="cursor-help underline decoration-dotted underline-offset-4"
				aria-label={`${song.plays} plays, show breakdown for ${song.track.name}`}
				aria-describedby={open ? breakdownId : undefined}
				onclick={() => (open = true)}
			>
				{song.plays}
			</button>
		{/snippet}
	</HoverCard.Trigger>
	<HoverCard.Content class="w-56" align="end">
		<dl id={breakdownId} class="space-y-2 text-sm font-normal">
			<div class="flex justify-between gap-4">
				<dt class="font-bold">You:</dt>
				<dd class="shrink-0">{song.user_plays} Plays</dd>
			</div>
			<div class="flex justify-between gap-4">
				<dt class="truncate font-bold">{partnerName}:</dt>
				<dd class="shrink-0">{song.partner_plays} Plays</dd>
			</div>
		</dl>
	</HoverCard.Content>
</HoverCard.Root>
