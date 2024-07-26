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
		content="Visualize you and your partners shared love of music. Track favorite songs, shared listens, shared listening time, listen together, and more. NOT AFFILIATED WITH SPOTIFY"
	/>
</svelte:head>

<div>
	<ModeWatcher />
	<MenuBar class="fixed top-0" />
	<div class="flex min-h-screen w-full flex-shrink-0 flex-grow flex-col gap-3">
		<MenuBar class="invisible" />
		<slot></slot>
		<Footer />
	</div>
</div>
