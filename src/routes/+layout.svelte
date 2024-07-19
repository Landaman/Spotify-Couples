<script lang="ts">
	import '../app.css';
	import MenuBar from '$lib/components/menu-bar.svelte';
</script>

<div class="w-full h-full flex flex-col gap-2">
	<MenuBar />
	<hr class="border-border/60" />
	<slot></slot>
</div>
