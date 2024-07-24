<script lang="ts">
	import '../app.css';
	import MenuBar from '$lib/components/menu-bar/menu-bar.svelte';
	import Footer from '$lib/components/footer.svelte';
	import { ModeWatcher } from 'mode-watcher';
	import { page } from '$app/stores';
</script>

<svelte:head>
	<title>{$page.data.pageTitle ? `${$page.data.pageTitle} | ` : ''}Spotify Couples</title>
	<meta
		name="description"
		content="Spotify Couples, a website where couples can visualize their shared love of music. Bringing people together, one listen at a time. NOT AFFILIATED WITH SPOTIFY"
	/>
</svelte:head>

<div class="flex h-screen w-full flex-col gap-2">
	<ModeWatcher />
	<MenuBar class="fixed top-0" />
	<MenuBar class="invisible" />
	<div class="flex-shrink-0 flex-grow">
		<slot></slot>
	</div>
	<Footer />
</div>
