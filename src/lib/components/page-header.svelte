<script lang="ts">
	import type { Snippet } from 'svelte';

	/** Shared page title styling with optional navigation and actions */
	interface Props {
		/** Page title */
		title: string;
		/** Optional supporting description */
		description?: string;
		/** Optional control before the title, such as mobile navigation */
		leading?: Snippet;
		/** Optional controls beside the title */
		actions?: Snippet;
	}
	let { title, description, leading, actions }: Props = $props();
</script>

<header class="border-b pb-6">
	<div class="flex flex-wrap items-center gap-3">
		{@render leading?.()}
		<h1 class="text-3xl font-semibold tracking-tight">{title}</h1>
		{#if actions}<div class="ml-auto flex flex-wrap items-center gap-2">
				{@render actions()}
			</div>{/if}
	</div>
	{#if description}<p class="mt-2 text-sm text-muted-foreground">{description}</p>{/if}
</header>
