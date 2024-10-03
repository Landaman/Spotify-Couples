<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as Card from '$lib/components/ui/card';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { Check, ClipboardCopy, Loader, Share } from 'lucide-svelte';
	import { onMount } from 'svelte';
	import { toast } from 'svelte-sonner';
	import { fade } from 'svelte/transition';

	const millisecondsInSecond = 1000; // MS in seconds

	/**
	 * Calculates the number of seconds until the pairing code expires
	 */
	function calculatePairingCodeSecondsToExpiry() {
		return Math.round(
			(presetPairingCodeExpiry.getTime() - new Date().getTime()) / millisecondsInSecond
		);
	}

	// Preset pairing code info
	export let presetPairingCode: string; // The code
	export let presetPairingCodeExpiry: Date; // Codes expiry
	let secondsLeftToCodeExpiry: number = calculatePairingCodeSecondsToExpiry();

	let copied = false; // If the code has been copied

	onMount(() => {
		const interval = setInterval(async () => {
			secondsLeftToCodeExpiry = calculatePairingCodeSecondsToExpiry(); // This is more accurate than strict decrementing

			// If the code expired, then we can go ahead
			if (secondsLeftToCodeExpiry < 0) {
				const newPairingCodeResponse: Response = await fetch('/signup/pairing-code'); // Get a new pairing code
				const newPairingCode: {
					code: string;
					expiry: string;
				} = await newPairingCodeResponse.json();

				presetPairingCode = newPairingCode.code;
				presetPairingCodeExpiry = new Date(newPairingCode.expiry);
				console.log(newPairingCode.expiry);
				secondsLeftToCodeExpiry = calculatePairingCodeSecondsToExpiry();
			}
		}, millisecondsInSecond);

		return () => {
			// Ensure the countdown is cleaned up
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
			<div class="relative w-full">
				<Input id="presetCode" type="text" value={presetPairingCode} readonly />
				<div class="absolute right-0 top-0">
					<Tooltip.Root>
						<Tooltip.Trigger>
							<Button
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
					<Tooltip.Trigger>
						<Button
							variant="default"
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

				<p class="text-xs text-muted-foreground">
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
