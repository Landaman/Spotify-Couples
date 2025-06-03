<script lang="ts">
	import '../app.css';
	import MenuBar from '$lib/components/menu-bar/menu-bar.svelte';
	import Footer from '$lib/components/footer.svelte';
	import { ModeWatcher } from 'mode-watcher';
	import { page } from '$app/stores';
	import { Toaster } from '$lib/components/ui/sonner';
	import type { PageData } from './$types';
	import { onMount } from 'svelte';
	import { invalidate } from '$app/navigation';
	import { SupabaseAuthDependency } from './shared';

	const {
		children,
		data
	}: {
		children?: import('svelte').Snippet;
		data: PageData;
	} = $props();

	const { session, supabase } = $derived(data);

	onMount(() => {
		const { data: authChangeData } = supabase.auth.onAuthStateChange((_, newSession) => {
			if (newSession?.expires_at !== session?.expires_at) {
				// What does this actually do? This reruns the layout loader (obviously),
				// which means that anyone who uses the session on the client will see the new one. This
				// is most important for stuff like changing a user's nickname (user still has a session, but it's different)
				// this doesn't necessarily handle redirects on logout or anything like that (that should be handled by the logic that does the logout)
				invalidate(SupabaseAuthDependency);
			}
		});
		return () => authChangeData.subscription.unsubscribe();
	});
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
			{@render children?.()}
		</div>
	</div>

	<Footer />
</div>
