<script lang="ts">
	import { applyAction, enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import UserAvatar from '#lib/components/user-avatar.svelte';
	import * as AlertDialog from '#lib/components/ui/alert-dialog/index.js';
	import * as Avatar from '#lib/components/ui/avatar/index.js';
	import { Button } from '#lib/components/ui/button/index.js';
	import * as Card from '#lib/components/ui/card/index.js';
	import type { Profile } from '#lib/database/profiles.js';
	import { ArrowUpRight, Unlink, UserRoundPlus } from '@lucide/svelte';

	let { partner, message }: { partner: Profile | null; message?: string } = $props();
	let confirmOpen = $state(false);
</script>

<section id="partner" aria-labelledby="partner-heading" class="scroll-mt-24">
	<div class="mb-6">
		<h2 id="partner-heading" class="text-xl font-semibold tracking-tight">Partner</h2>
		<p class="mt-2 text-sm text-muted-foreground">
			Good music is better together. Manage who you share it with.
		</p>
	</div>

	<AlertDialog.Root open={!!message}>
		<AlertDialog.Content>
			<AlertDialog.Header>
				<AlertDialog.Title>Unable to unpair</AlertDialog.Title>
				<AlertDialog.Description>{message}</AlertDialog.Description>
			</AlertDialog.Header>
			<AlertDialog.Footer>
				<AlertDialog.Action
					onclick={() => applyAction({ type: 'success', status: 200, location: page.url.href })}
				>
					Dismiss
				</AlertDialog.Action>
			</AlertDialog.Footer>
		</AlertDialog.Content>
	</AlertDialog.Root>

	<Card.Root size="sm" class="bg-muted/30">
		<Card.Content>
			<div class="flex items-center gap-4">
				{#if partner}
					<UserAvatar {...partner} class="size-14 shrink-0 text-lg" />
				{:else}
					<Avatar.Root class="size-14 shrink-0">
						<Avatar.Fallback><UserRoundPlus class="size-6" /></Avatar.Fallback>
					</Avatar.Root>
				{/if}
				<div class="min-w-0">
					<p class="font-semibold wrap-anywhere">{partner?.name ?? 'No partner yet'}</p>
					{#if partner}
						<a
							class="mt-1 inline-flex items-center gap-1 text-sm text-muted-foreground underline underline-offset-4 hover:text-foreground"
							href={`https://open.spotify.com/user/${encodeURIComponent(partner.spotify_id)}`}
							target="_blank"
							rel="noreferrer"
						>
							Spotify profile <ArrowUpRight class="size-3.5" />
							<span class="sr-only">(opens in a new tab)</span>
						</a>
					{/if}
				</div>
			</div>
		</Card.Content>
	</Card.Root>
	<div class="mt-6 flex flex-col items-start gap-4">
		{#if partner}
			<p class="w-full text-sm text-muted-foreground">
				Unpairing keeps your individual listening history. You can re-pair at any time.
			</p>
			<AlertDialog.Root bind:open={confirmOpen}>
				<AlertDialog.Trigger>
					{#snippet child({ props })}
						<Button {...props} variant="destructive"><Unlink />Unpair</Button>
					{/snippet}
				</AlertDialog.Trigger>
				<AlertDialog.Content>
					<AlertDialog.Header>
						<AlertDialog.Title>Unpair from {partner.name}?</AlertDialog.Title>
						<AlertDialog.Description
							>This ends your pairing for both of you. Your listening history won't be deleted. You
							can re-pair at any time.</AlertDialog.Description
						>
					</AlertDialog.Header>
					<AlertDialog.Footer>
						<AlertDialog.Cancel>Stay paired</AlertDialog.Cancel>
						<form
							method="post"
							action="?/unpair"
							use:enhance={() =>
								async ({ update }) => {
									await update();
									confirmOpen = false;
								}}
						>
							<input type="hidden" name="partnerId" value={partner.id} />
							<Button type="submit" variant="destructive" class="w-full">Unpair</Button>
						</form>
					</AlertDialog.Footer>
				</AlertDialog.Content>
			</AlertDialog.Root>
		{:else}
			<Button href={resolve('/signup')}><UserRoundPlus />Pair with a partner</Button>
		{/if}
	</div>
</section>
