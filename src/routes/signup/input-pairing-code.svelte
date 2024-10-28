<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as Card from '$lib/components/ui/card';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { ArrowRight, ClipboardPaste, Loader } from 'lucide-svelte';
	import { PairingCodeFieldName } from './shared';
	import { applyAction, enhance } from '$app/forms';
	import { goto } from '$app/navigation';

	// Pairing code
	let pairingCode: string = $state('');

	// Whether the code is currently being submitted
	let submittingCode = $state(false);
</script>

<Card.Root class="w-72 self-center">
	<Card.Header>
		<Card.Title>Enter a Pairing Code</Card.Title>
		<Card.Description>Enter a Pairing Code your partner has already sent you</Card.Description>
	</Card.Header>
	<form
		method="POST"
		use:enhance={async () => {
			submittingCode = true; // Enable loading UI

			// Manually clear the form submission state, this is important
			await applyAction({ status: 200, type: 'success' });

			return async ({ result }) => {
				submittingCode = false; // Disable loading UI

				// This replicates the default SvelteKit UI
				if (result.type === 'redirect') {
					goto(result.location, { invalidateAll: true, replaceState: true }); // Reload partner/profile data, and don't allow back to this page
				} else {
					await applyAction(result);
				}
			};
		}}
	>
		<Card.Content class="flex flex-col gap-1.5">
			<Label for="code">Pairing Code</Label>
			<div class="relative">
				<Input
					name={PairingCodeFieldName}
					type="text"
					placeholder="Enter Pairing Code"
					bind:value={pairingCode}
					class="pr-10"
				/>
				<div class="absolute right-0 top-0">
					<Tooltip.Root>
						<Tooltip.Trigger asChild let:builder>
							<Button
								builders={[builder]}
								variant="ghost"
								size="icon"
								on:click={async () => {
									pairingCode = await navigator.clipboard.readText();
								}}
							>
								<ClipboardPaste class="h-4 w-4" />
							</Button>
						</Tooltip.Trigger>
						<Tooltip.Content>
							<p>Paste from Clipboard</p>
						</Tooltip.Content>
					</Tooltip.Root>
				</div>
			</div>
		</Card.Content>
		<Card.Footer>
			<Button disabled={submittingCode} class="w-full gap-1" size="lg" type="submit"
				>Submit
				{#if submittingCode}
					<Loader class="animate-spin" />
				{:else}
					<ArrowRight />
				{/if}
			</Button>
		</Card.Footer>
	</form>
</Card.Root>
