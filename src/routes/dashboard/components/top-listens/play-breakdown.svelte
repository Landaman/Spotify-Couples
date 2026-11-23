<script lang="ts">
	import { Button } from '#lib/components/ui/button/index.js';
	import * as HoverCard from '#lib/components/ui/hover-card/index.js';
	import type { TopListen } from '../../shared';

	/** Data shown in a combined play count breakdown */
	interface Props {
		/** Ranked entry and its play counts */
		listen: Pick<TopListen, 'plays' | 'user_plays' | 'partner_plays'>;
		/** Name of the ranked entry */
		name: string;
		/** Name of the other listener */
		partnerName: string;
	}

	const { listen, name, partnerName }: Props = $props();
	const breakdownId = $props.id();
	let open = $state(false);
</script>

<HoverCard.Root bind:open>
	<HoverCard.Trigger>
		{#snippet child({ props })}
			<Button
				{...props}
				type="button"
				variant="link"
				class="h-auto border-0 p-0 font-normal text-inherit decoration-dotted"
				aria-label={`${listen.plays} plays, show breakdown for ${name}`}
				aria-describedby={open ? breakdownId : undefined}
				onclick={() => (open = true)}
			>
				{listen.plays}
			</Button>
		{/snippet}
	</HoverCard.Trigger>
	<HoverCard.Content class="w-56" align="end">
		<dl id={breakdownId} class="space-y-2 text-sm font-normal">
			<div class="flex justify-between gap-4">
				<dt class="font-bold">You:</dt>
				<dd class="shrink-0">{listen.user_plays} Plays</dd>
			</div>
			<div class="flex justify-between gap-4">
				<dt class="truncate font-bold">{partnerName}:</dt>
				<dd class="shrink-0">{listen.partner_plays} Plays</dd>
			</div>
		</dl>
	</HoverCard.Content>
</HoverCard.Root>
