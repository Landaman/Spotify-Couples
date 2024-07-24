<script lang="ts">
	import UserManagementDropdown from './user-management-dropdown.svelte';
</script>

<header class="flex w-full flex-row justify-between px-4 pt-2 md:px-8">
	<a href="/">
		<enhanced:img
			src="$lib/assets/logo.png"
			alt="Spotify Couples"
			sizes="10px,10px"
			class="pointer-events-none h-10 w-10"
		/>
	</a>

	<UserManagementDropdown />
</header>
