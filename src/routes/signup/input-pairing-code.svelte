<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as Card from '$lib/components/ui/card';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { ArrowRight, ClipboardPaste } from 'lucide-svelte';

	// Pairing code
	let pairingCode: string;
</script>

<Card.Root class="w-72 self-center">
	<Card.Header>
		<Card.Title>Enter a Pairing Code</Card.Title>
		<Card.Description>Enter a Pairing Code your partner has already sent you</Card.Description>
	</Card.Header>
	<form>
		<Card.Content class="flex flex-col gap-1.5">
			<Label for="code">Pairing Code</Label>
			<div class="relative">
				<Input
					id="code"
					type="text"
					placeholder="Enter Pairing Code"
					bind:value={pairingCode}
					class="pr-10"
				/>
				<div class="absolute right-0 top-0">
					<Tooltip.Root>
						<Tooltip.Trigger>
							<Button
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
			<Button class="w-full gap-1" size="lg" type="submit">Submit <ArrowRight /></Button>
		</Card.Footer>
	</form>
</Card.Root>
