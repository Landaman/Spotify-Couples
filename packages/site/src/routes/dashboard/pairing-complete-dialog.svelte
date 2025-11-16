<script lang="ts">
	import * as Dialog from '$lib/components/ui/dialog';
	import UserAvatar from '$lib/components/user-avatar.svelte';
	import { Heart } from '@lucide/svelte';
	import type { Profile } from '$lib/database/profiles';
	import { resolve } from '$app/paths';
	import { buttonVariants } from '$lib/components/ui/button';

	interface Props {
		user: Profile;
		partner: Profile;
		dialogOpen: boolean;
	}

	// No good way to do this here :(
	// eslint-disable-next-line prefer-const
	let { user, partner, dialogOpen = $bindable() }: Props = $props();
</script>

<Dialog.Root bind:open={dialogOpen}>
	<Dialog.Content>
		<Dialog.Header>
			<Dialog.Title>Pairing Complete</Dialog.Title>
			<Dialog.Description>
				Congratulations! You just successfully paired with
				<span class="font-semibold">
					{partner.name}
				</span>.
			</Dialog.Description>
		</Dialog.Header>
		<div class="my-4 flex flex-row items-center justify-between gap-5">
			<UserAvatar {...user} class="aspect-square h-auto grow text-2xl sm:text-4xl" />
			<Heart class="animate-heartbeat fill-destructive aspect-square  h-auto grow stroke-0" />
			<UserAvatar {...partner} class="aspect-square h-auto grow text-2xl sm:text-4xl" />
		</div>
		<Dialog.Footer class="gap-1 sm:items-center sm:justify-between">
			<Dialog.Description>
				Wrong person? You can always reset your pairing status in
				<a href={resolve('/')} class="font-semibold underline">Settings</a>.
			</Dialog.Description>
			<Dialog.Close class={buttonVariants({ variant: 'default' })}>Continue</Dialog.Close>
		</Dialog.Footer>
	</Dialog.Content>
</Dialog.Root>
