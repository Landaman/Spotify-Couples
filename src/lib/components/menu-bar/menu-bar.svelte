<script lang="ts">
	import UserManagementDropdown from './user-management-dropdown.svelte';
	import { page } from '$app/state';
	import { Button } from '#lib/components/ui/button/index.js';
	import { User } from '@lucide/svelte';
	import { resolve } from '$app/paths';

	/**
	 * CSS style classes to apply to the root of the menubar
	 */
	interface Props {
		class?: string | undefined;
	}

	const { class: className = undefined }: Props = $props();
</script>

<header
	class={`flex w-full flex-row justify-between border-b border-border/40 bg-background/95 px-4 py-3 backdrop-blur-sm supports-backdrop-filter:bg-background/60 md:px-8 ${className ?? ''}`}
>
	<a href={resolve('/')}>
		<div class="pointer-events-none flex flex-row items-center gap-2">
			<enhanced:img src="#lib/assets/logo.png" alt="Spotify Couples" class="size-10"></enhanced:img>
			<h1 class="hidden text-2xl font-semibold tracking-tight md:block">Spotify Couples</h1>
		</div>
	</a>

	{#if page.data.session}
		<UserManagementDropdown />
	{:else}
		<form method="post" action="/signin">
			<Button variant="outline" type="submit" class="gap-0">
				<User class="mr-2 size-4"></User>Sign In</Button
			>
		</form>
	{/if}
</header>
