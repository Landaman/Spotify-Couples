<script lang="ts">
	import { Button } from '#lib/components/ui/button/index.js';
	import * as Sheet from '#lib/components/ui/sheet/index.js';
	import { Menu } from '@lucide/svelte';
	import { cn } from '#lib/utils.js';
	import type { Snippet } from 'svelte';

	/** Shared page heading, optional section navigation, and content */
	interface Props {
		/** Page heading and accessible navigation name */
		title: string;
		/** Optional supporting text beneath the heading */
		description?: string;
		/** Section links, with a callback to close mobile navigation after selection */
		navigation?: Snippet<[onNavigate?: () => void]>;
		/** Main page content */
		children: Snippet;
	}

	let { title, description, navigation, children }: Props = $props();
	let menuOpen = $state(false);
</script>

<div class="flex w-full flex-col px-4 pt-4 pb-8 md:px-8 md:pt-6 md:pb-0">
	<div class="border-b pb-6">
		<div class="flex items-center gap-3">
			{#if navigation}
				<div class="md:hidden">
					<Sheet.Root bind:open={menuOpen}>
						<Sheet.Trigger>
							{#snippet child({ props })}
								<Button
									{...props}
									variant="outline"
									size="icon"
									aria-label={`Open ${title.toLowerCase()} navigation`}
								>
									<Menu />
								</Button>
							{/snippet}
						</Sheet.Trigger>
						<Sheet.Content side="left" class="w-72">
							<Sheet.Header>
								<Sheet.Title>{title}</Sheet.Title>
								<Sheet.Description>Jump to a section.</Sheet.Description>
							</Sheet.Header>
							<nav aria-label={`${title} sections`} class="px-4">
								{@render navigation(() => (menuOpen = false))}
							</nav>
						</Sheet.Content>
					</Sheet.Root>
				</div>
			{/if}
			<h1 class="text-3xl font-semibold tracking-tight">{title}</h1>
		</div>
		{#if description}
			<p class="mt-2 text-sm text-muted-foreground">{description}</p>
		{/if}
	</div>

	<div
		class={cn(
			'grid items-start gap-8 md:flex-1 md:items-stretch',
			navigation && 'md:grid-cols-[12rem_minmax(0,1fr)]'
		)}
	>
		{#if navigation}
			<aside class="hidden pt-6 md:block">
				<div class="sticky top-24">
					<p class="mb-3 px-3 text-xs font-medium tracking-wider text-muted-foreground uppercase">
						On this page
					</p>
					<nav aria-label={`${title} sections`}>
						{@render navigation()}
					</nav>
				</div>
			</aside>
		{/if}

		<main class={cn('min-w-0 pt-6 md:pb-12', navigation && 'md:border-l md:pl-8 lg:pl-12')}>
			{@render children()}
		</main>
	</div>
</div>
