<script lang="ts">
	import '../app.css';
	import UserManagement from '$lib/components/user-management-dropdown.svelte';
</script>

<div class="w-full h-full flex flex-col gap-3">
	<div class="w-full flex flex-row justify-end pt-2 pr-2">
		<UserManagement />
	</div>
	<hr class="text-border" />
	<slot></slot>
</div>
