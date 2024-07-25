<script lang="ts">
	import UserManagementDropdown from './user-management-dropdown.svelte';
	import { Separator } from '$lib/components/ui/separator';

	/**
	 * CSS style classes to apply to the root of the menubar
	 */
	let className: string | undefined = undefined;
	export { className as class };
</script>

<div class={`flex w-full flex-col gap-3 bg-background pt-3 ${className ?? ''}`}>
	<header class="flex w-full flex-row justify-between px-4 md:px-8">
		<a href="/">
			<div class="pointer-events-none flex flex-row items-center gap-2">
				<enhanced:img
					src="$lib/assets/logo.png"
					alt="Spotify Couples"
					sizes="10px,10px"
					class=" h-10 w-10"
				/>
				<h1 class="hidden text-2xl font-semibold tracking-wide md:block">Spotify Couples</h1>
			</div>
		</a>

		<UserManagementDropdown />
	</header>

	<Separator />
</div>
