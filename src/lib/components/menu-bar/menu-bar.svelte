<script lang="ts">
	import UserManagementDropdown from './user-management-dropdown.svelte';
	import { page } from '$app/stores';
	import { Button } from '$lib/components/ui/button';
	import { User } from 'lucide-svelte';

	/**
	 * CSS style classes to apply to the root of the menubar
	 */
	let className: string | undefined = undefined;
	export { className as class };
</script>

<header
	class={`flex w-full flex-row justify-between border-b border-border/40 bg-background/95 px-4 py-3 backdrop-blur supports-[backdrop-filter]:bg-background/60 md:px-8 ${className ?? ''}`}
>
	<a href="/">
		<div class="pointer-events-none flex flex-row items-center gap-2">
			<enhanced:img src="$lib/assets/logo.png" alt="Spotify Couples" class="h-10 w-10"
			></enhanced:img>
			<h1 class="hidden text-2xl font-semibold tracking-wide md:block">Spotify Couples</h1>
		</div>
	</a>

	{#if $page.data.user}
		<UserManagementDropdown />
	{:else}
		<form method="post" action="/signin">
			<Button variant="outline" type="submit">
				<User class="mr-2 h-4 w-4"></User>Sign In</Button
			>
		</form>
	{/if}
</header>
