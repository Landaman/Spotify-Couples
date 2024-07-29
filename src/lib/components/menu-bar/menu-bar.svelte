<script lang="ts">
	import UserManagementDropdown from './user-management-dropdown.svelte';
	import { Separator } from '$lib/components/ui/separator';
	import { page } from '$app/stores';
	import { SignIn } from '@auth/sveltekit/components';
	import { Button } from '$lib/components/ui/button';
	import { User } from 'lucide-svelte';

	/**
	 * CSS style classes to apply to the root of the menubar
	 */
	let className: string | undefined = undefined;
	export { className as class };
</script>

<div
	class={`backdrop-saturate flex w-full flex-col gap-3 bg-background bg-opacity-80 pt-3 backdrop-blur-sm backdrop-saturate-150 ${className ?? ''}`}
>
	<header class="flex w-full flex-row justify-between px-4 md:px-8">
		<a href="/">
			<div class="pointer-events-none flex flex-row items-center gap-2">
				<enhanced:img
					src="$lib/assets/logo.png"
					alt="Spotify Couples"
					sizes="40px,40px"
					class="h-10 w-10"
				/>
				<h1 class="hidden text-2xl font-semibold tracking-wide md:block">Spotify Couples</h1>
			</div>
		</a>

		{#if $page.data.session?.user}
			<UserManagementDropdown />
		{:else}
			<SignIn provider="spotify" signInPage="signin" className="contents [&>button]:contents">
				<svelte:fragment slot="submitButton">
					<Button variant="outline" type="submit"><User class="mr-2 h-4 w-4" />Sign In</Button>
				</svelte:fragment>
			</SignIn>
		{/if}
	</header>

	<Separator />
</div>
