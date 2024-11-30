<script lang="ts">
	import { page } from '$app/stores';
	import * as Dialog from '$lib/components/ui/dialog';
	import { ShowPartnerSearchParameter } from './shared';
	import UserAvatar from '$lib/components/user-avatar.svelte';
	import { Heart } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { Button } from '$lib/components/ui/button';

	let dialogOpen = $state($page.url.searchParams.get(ShowPartnerSearchParameter) == 'true');

	$effect(() => {
		if (!dialogOpen) {
			goto('/dashboard', {
				replaceState: true
			});
		}
	});
</script>

<div>
	<Dialog.Root bind:open={dialogOpen}>
		<Dialog.Content>
			<Dialog.Header>
				<Dialog.Title>Pairing Complete</Dialog.Title>
				<Dialog.Description>
					Congratulations! You just successfully paired with
					<span class="font-semibold">
						{$page.data.partner?.displayName}
					</span>.
				</Dialog.Description>
			</Dialog.Header>
			<div class="my-4 flex flex-row items-center justify-between gap-5">
				{#if $page.data.user && $page.data.partner}
					<UserAvatar
						user={$page.data.user}
						class="aspect-square h-auto flex-grow text-2xl sm:text-4xl"
					/>
					<Heart
						class="animate-heartbeat fill-destructive aspect-square  h-auto flex-grow stroke-0"
					/>
					<UserAvatar
						user={$page.data.partner}
						class="aspect-square h-auto flex-grow text-2xl sm:text-4xl"
					/>
				{/if}
			</div>
			<Dialog.Footer class="gap-1 sm:items-center sm:justify-between">
				<Dialog.Description>
					Wrong person? You can always reset your pairing status in
					<a href="/settings" class="font-semibold underline">Settings</a>.
				</Dialog.Description>
				<Dialog.Close asChild let:builder
					><Button builders={[builder]}>Continue</Button></Dialog.Close
				>
			</Dialog.Footer>
		</Dialog.Content>
	</Dialog.Root>
</div>
