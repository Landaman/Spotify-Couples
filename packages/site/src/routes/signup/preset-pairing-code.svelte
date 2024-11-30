<script lang="ts">
	import { goto } from '$app/navigation';
	import { Button } from '$lib/components/ui/button';
	import * as Card from '$lib/components/ui/card';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { onSnapshot, doc, getFirestore } from 'firebase/firestore';
	import { Check, ClipboardCopy, Loader, Share } from 'lucide-svelte';
	import { onMount } from 'svelte';
	import { toast } from 'svelte-sonner';
	import { fade } from 'svelte/transition';
	import { ShowPartnerSearchParameter } from '../dashboard/shared';
	import type { Unsubscribe } from 'firebase/database';

	const millisecondsInSecond = 1000; // MS in seconds

	/**
	 * Calculates the number of seconds until the pairing code expires
	 */
	function calculatePairingCodeSecondsToExpiry() {
		return Math.round(
			(presetPairingCodeExpiry.getTime() - new Date().getTime()) / millisecondsInSecond
		);
	}

	/**
	 * Creates a redirect listener for the current preset pairing code, which will redirect the user to the dashboard when
	 * the pairing code doc is deleted
	 * @returns the listener unsubscribe function
	 */
	function createPairedRedirectListener(): Unsubscribe {
		return onSnapshot(
			doc(getFirestore(), pairingCodeCollectionName, presetPairingCode),
			async (changedDocument) => {
				if (!changedDocument.exists()) {
					await goto(`/dashboard?${ShowPartnerSearchParameter}=true`, {
						replaceState: true, // Don't allow navigation back to this page
						invalidateAll: true // Need to completely recalculate dashboard's dependencies (e.g., show the new partner)
					});
				}
			}
		);
	}

	interface Props {
		// Pairing code
		pairingCodeCollectionName: string;
		// Preset pairing code info
		presetPairingCode: string;
		presetPairingCodeExpiry: Date;
	}

	let {
		// No way to really avoid this...
		// eslint-disable-next-line prefer-const
		pairingCodeCollectionName,
		presetPairingCode = $bindable(),
		presetPairingCodeExpiry = $bindable()
	}: Props = $props();
	let secondsLeftToCodeExpiry: number = $state(calculatePairingCodeSecondsToExpiry());

	let copied = $state(false); // If the code has been copied

	onMount(() => {
		let unsubscribe = createPairedRedirectListener();

		const interval = setInterval(async () => {
			secondsLeftToCodeExpiry = calculatePairingCodeSecondsToExpiry(); // This is more accurate than strict decrementing

			// If the code expired, then we can go ahead
			if (secondsLeftToCodeExpiry <= 0) {
				const newPairingCodeResponse: Response = await fetch('/signup/pairing-code'); // Get a new pairing code
				const newPairingCode: {
					code: string;
					expiry: string;
				} = await newPairingCodeResponse.json();

				presetPairingCode = newPairingCode.code;
				presetPairingCodeExpiry = new Date(newPairingCode.expiry);
				secondsLeftToCodeExpiry = calculatePairingCodeSecondsToExpiry();

				// Cleanup and then setup a new listener for the new code
				unsubscribe();
				unsubscribe = createPairedRedirectListener();
			}
		}, millisecondsInSecond);

		return () => {
			unsubscribe(); // Cleanup the firestore listener
			clearInterval(interval); // Ensure the countdown is cleaned up
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
