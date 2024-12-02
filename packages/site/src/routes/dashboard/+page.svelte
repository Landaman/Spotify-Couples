<script lang="ts">
	import { page } from '$app/stores';
	import { ShowPartnerSearchParameter } from './shared';
	import { goto } from '$app/navigation';
	import PairingCompleteDialog from './pairing-complete-dialog.svelte';

	// Show the dialog based on page state
	let dialogOpen = $state($page.url.searchParams.get(ShowPartnerSearchParameter) == 'true');
	$effect(() => {
		if (!dialogOpen) {
			// Make sure that back button doesn't go back to dialog open, that would be annoying...
			goto('/dashboard', {
				replaceState: true
			});
		}
	});
</script>

{#if $page.data.user && $page.data.partner}
	<PairingCompleteDialog user={$page.data.user} partner={$page.data.partner} bind:dialogOpen />
	<div class="px-4 pt-2 md:px-8">
		<h1 class="text-3xl font-semibold md:text-4xl">Dashboard</h1>
	</div>
{/if}
