<script lang="ts">
	import '../app.css';
	import MenuBar from '$lib/components/menu-bar/menu-bar.svelte';
	import { ModeWatcher } from 'mode-watcher';
</script>

<div class="flex h-full w-full flex-col gap-2">
	<ModeWatcher />
	<MenuBar />
	<hr class="border-border/60" />
	<slot></slot>
</div>
