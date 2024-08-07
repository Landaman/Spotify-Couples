<script lang="ts">
	import '../app.css';
	import MenuBar from '$lib/components/menu-bar/menu-bar.svelte';
	import Footer from '$lib/components/footer.svelte';
	import { ModeWatcher } from 'mode-watcher';
	import { page } from '$app/stores';
	import { Toaster } from '$lib/components/ui/sonner';
</script>

<ModeWatcher themeColors={{ light: '#FFFFFF', dark: '#020817' }} />
<Toaster />

<svelte:head>
	<title>{$page.data.pageTitle ? `${$page.data.pageTitle} | ` : ''}Spotify Couples</title>
	<meta
		name="description"
		content="Visualize you and your partners shared love of music. Track favorite songs, shared listens, shared listening time, listen together, and more. NOT AFFILIATED WITH SPOTIFY"
	/>
</svelte:head>

<MenuBar class="fixed top-0 z-50 p-[inherit]" />
<div class="flex h-full w-full flex-col gap-3">
	<div class="flex min-h-screen flex-col gap-3">
		<MenuBar class="invisible" />

		<div class="flex flex-auto">
			<slot></slot>
		</div>
	</div>

	<Footer />
</div>
