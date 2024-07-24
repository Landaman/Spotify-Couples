<script lang="ts">
	import UserManagementDropdown from './user-management-dropdown.svelte';
</script>

<header class="flex w-full flex-row justify-between px-4 pt-2 md:px-8">
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
