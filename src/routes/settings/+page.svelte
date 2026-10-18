<script lang="ts">
	import { Button } from '#lib/components/ui/button/index.js';
	import * as Sheet from '#lib/components/ui/sheet/index.js';
	import { Heart, Menu } from '@lucide/svelte';
	import type { PageProps } from './$types';
	import PartnerSettings from './partner-settings.svelte';

	let { data, form }: PageProps = $props();
	let menuOpen = $state(false);
</script>

<div class="flex w-full flex-col px-4 pt-4 pb-8 md:px-8 md:pt-6 md:pb-0">
	<div class="border-b pb-6">
		<div class="flex items-center gap-3">
			<div class="md:hidden">
				<Sheet.Root bind:open={menuOpen}>
					<Sheet.Trigger>
						{#snippet child({ props })}
							<Button
								{...props}
								variant="outline"
								size="icon"
								aria-label="Open settings navigation"
							>
								<Menu />
							</Button>
						{/snippet}
					</Sheet.Trigger>
					<Sheet.Content side="left" class="w-72">
						<Sheet.Header>
							<Sheet.Title>Settings</Sheet.Title>
							<Sheet.Description>Jump to a section.</Sheet.Description>
						</Sheet.Header>
						<nav aria-label="Settings sections" class="px-4">
							<Button
								href="#partner"
								variant="secondary"
								class="w-full justify-start gap-3"
								aria-current="location"
								onclick={() => (menuOpen = false)}
							>
								<Heart />Partner
							</Button>
						</nav>
					</Sheet.Content>
				</Sheet.Root>
			</div>
			<h1 class="text-3xl font-semibold tracking-tight">Settings</h1>
		</div>
		<p class="mt-2 text-sm text-muted-foreground">
			A little housekeeping for your shared listening
		</p>
	</div>

	<div class="grid items-start gap-8 md:flex-1 md:grid-cols-[12rem_minmax(0,1fr)] md:items-stretch">
		<aside class="hidden pt-6 md:block">
			<div class="sticky top-24">
				<p class="mb-3 px-3 text-xs font-medium tracking-wider text-muted-foreground uppercase">
					On this page
				</p>
				<nav aria-label="Settings sections">
					<Button
						href="#partner"
						variant="secondary"
						class="w-full justify-start gap-3"
						aria-current="location"
					>
						<Heart />Partner
					</Button>
				</nav>
			</div>
		</aside>

		<main class="min-w-0 pt-6 md:border-l md:pb-12 md:pl-8 lg:pl-12">
			<PartnerSettings partner={data.partner} message={form?.message} />
		</main>
	</div>
</div>
