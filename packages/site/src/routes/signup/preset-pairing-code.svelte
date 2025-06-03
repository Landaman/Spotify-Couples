<script lang="ts">
	import { goto, invalidate } from '$app/navigation';
	import { Button } from '$lib/components/ui/button';
	import * as Card from '$lib/components/ui/card';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { Check, ClipboardCopy, Loader, Share } from 'lucide-svelte';
	import { toast } from 'svelte-sonner';
	import { fade } from 'svelte/transition';
	import { ShowPartnerSearchParameter } from '../dashboard/shared';
	import { PairingCodeDependency } from './shared';
	import { page } from '$app/stores';

	const millisecondsInSecond = 1000; // MS in seconds

	/**
	 * Calculates the number of seconds until the pairing code expires
	 */
	function calculatePairingCodeSecondsToExpiry() {
		return Math.round(
			(presetPairingCodeExpiry.getTime() - new Date().getTime()) / millisecondsInSecond
		);
	}

	const {
		presetPairingCode,
		presetPairingCodeExpiry
	}: {
		presetPairingCode: string;
		presetPairingCodeExpiry: Date;
	} = $props();

	const supabase = $page.data.supabase;

	let secondsLeftToCodeExpiry = $state(calculatePairingCodeSecondsToExpiry());
	let copied = $state(false); // If the code has been copied

	$effect(() => {
		// Listen to notifications about the pairing code
		const codeChannel = supabase.channel(`pairing_codes:${presetPairingCode}`);
		codeChannel
			.on('broadcast', { event: 'paired' }, () =>
				// On pair, go to the dashboard
				goto(`/dashboard?${ShowPartnerSearchParameter}=true`, {
					replaceState: true, // Don't allow navigation back to this page
					invalidateAll: true // Need to completely recalculate dashboard's dependencies (e.g., show the new partner)
				})
			)
			.subscribe();

		const interval = setInterval(async () => {
			// This is more accurate than strict decrementing
			secondsLeftToCodeExpiry = calculatePairingCodeSecondsToExpiry();

			// If the code expired, then we can go ahead
			if (secondsLeftToCodeExpiry <= 0) {
				// This triggers the pairing code to refresh on this end
				invalidate(PairingCodeDependency);
			}
		}, millisecondsInSecond);

		return () => {
			// On cleanup, or preset code change, cleanup the subscription
			codeChannel.unsubscribe();

			clearInterval(interval);
		};
	});
</script>

<Card.Root class="w-72 self-center">
	<Card.Header>
		<Card.Title>Create a new Pairing Code</Card.Title>
		<Card.Description>Create a new Pairing Code to send to your partner</Card.Description>
	</Card.Header>
	<Card.Content class="flex flex-col gap-1.5">
		<Label for="presetCode">Pairing Code</Label>
		<div class="flex items-center gap-2">
			<div class="relative flex-shrink flex-grow">
				<Input id="presetCode" type="text" value={presetPairingCode} readonly />
				<div class="absolute right-0 top-0">
					<Tooltip.Root>
						<Tooltip.Trigger asChild let:builder>
							<Button
								builders={[builder]}
								variant="ghost"
								size="icon"
								on:click={async () => {
									await navigator.clipboard.writeText(presetPairingCode.toString());
									toast.success('Code copied to clipboard');
									copied = true;

									setTimeout(() => {
										copied = false;
									}, 1000);
								}}
							>
								{#if copied}
									<div in:fade>
										<Check class="h-4 w-4" />
									</div>
								{:else}
									<div in:fade>
										<ClipboardCopy class="h-4 w-4" />
									</div>
								{/if}
							</Button>
						</Tooltip.Trigger>
						<Tooltip.Content>
							<p>Copy to Clipboard</p>
						</Tooltip.Content>
					</Tooltip.Root>
				</div>
			</div>
			{#if typeof navigator !== 'undefined' && navigator.share}
				<Tooltip.Root>
					<Tooltip.Trigger asChild let:builder>
						<Button
							builders={[builder]}
							variant="default"
							class="flex-shrink-0"
							size="icon"
							on:click={async () => {
								await navigator.share({
									title: 'Pairing Code',
									text: `Join me on Spotify Couples using the pairing code ${presetPairingCode}`,
									url: new URL(
										`/signup/pairing-code/${presetPairingCode}`,
										location.origin
									).toString()
								});
							}}
						>
							<Share class="h-4 w-4" />
						</Button>
					</Tooltip.Trigger>
					<Tooltip.Content>Share Pairing Code</Tooltip.Content>
				</Tooltip.Root>
			{/if}
		</div>
	</Card.Content>
	<Card.Footer>
		<div class="flex flex-row items-center gap-2">
			<Loader class="animate-spin" />

			<div class="flex flex-col gap-1">
				<p>Waiting for your partner...</p>

				<p class="text-muted-foreground text-xs">
					Code expires in <span class="font-bold">
						{Math.floor(secondsLeftToCodeExpiry / 60)
							.toString()
							.padStart(2, '0')}:{(secondsLeftToCodeExpiry % 60).toString().padStart(2, '0')}
					</span>
				</p>
			</div>
		</div>
	</Card.Footer>
</Card.Root>
