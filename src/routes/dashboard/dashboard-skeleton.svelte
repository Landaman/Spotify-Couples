<script lang="ts">
	import * as Card from '#lib/components/ui/card/index.js';
	import { Skeleton } from '#lib/components/ui/skeleton/index.js';

	/** Range used to reserve the chart's bucket layout while data loads */
	interface Props {
		/** Rolling 24 hours, or 7/30 calendar days */
		days: number;
	}
	let { days }: Props = $props();
	const buckets = $derived(days === 1 ? 24 : days);
</script>

<div role="status" aria-label="Loading your dashboard">
	<span class="sr-only">Loading your dashboard…</span>
	<div aria-hidden="true">
		<div class="grid items-start gap-5 lg:grid-cols-2 lg:items-stretch">
			<Card.Root class="min-w-0 gap-4 p-4 sm:p-5">
				<Card.Header class="px-0"
					><Card.Title class="font-semibold">Top Listens</Card.Title></Card.Header
				>
				<Card.Content class="px-0">
					<div class="flex flex-col gap-2">
						<div class="flex flex-wrap items-center justify-between gap-3">
							<Skeleton class="h-9 w-49" />
							<Skeleton class="h-8 w-28" />
						</div>
						<div>
							{#each Array(5) as _, index (index)}
								<div class="flex items-center gap-3 border-b py-3 last:border-0">
									<Skeleton class="size-3 shrink-0" />
									<Skeleton class="size-10 shrink-0 rounded-sm md:rounded-md" />
									<div class="min-w-0 flex-1 space-y-2">
										<Skeleton class="h-3.5 w-3/4" />
										<Skeleton class="h-3 w-full max-w-56" />
									</div>
									<Skeleton class="h-3 w-12 shrink-0" />
								</div>
							{/each}
						</div>
					</div>
				</Card.Content>
			</Card.Root>
			<Card.Root class="min-w-0 gap-4 p-4 sm:p-5">
				<Card.Header class="px-0"
					><Card.Title class="font-semibold">Listening Time</Card.Title></Card.Header
				>
				<Card.Content class="min-h-64 flex-1 px-0">
					<div class="relative min-h-64 flex-1">
						<div class="absolute inset-0 flex flex-col pt-2 pr-2 pb-14 pl-12">
							<Skeleton class="absolute top-1/2 left-0 h-3 w-24 origin-top-left -rotate-90" />
							<div class="relative flex min-h-0 flex-1 items-end gap-1 border-b border-l px-2">
								{#each Array(buckets) as _, index (index)}
									<div class="flex h-full min-w-0 flex-1 items-end gap-0.5 pb-px">
										<Skeleton class="h-3/5 flex-1 rounded-b-none" />
										<Skeleton class="h-4/5 flex-1 rounded-b-none" />
									</div>
								{/each}
							</div>
							<div class="absolute right-2 bottom-9 left-12 flex justify-between">
								{#each Array(4) as _, index (index)}<Skeleton class="h-2.5 w-7" />{/each}
							</div>
							<Skeleton class="absolute bottom-5 left-1/2 h-3 w-8" />
							<div class="absolute inset-x-0 bottom-0 flex justify-center gap-4">
								<Skeleton class="h-3 w-10" /><Skeleton class="h-3 w-20" />
							</div>
						</div>
					</div>
				</Card.Content>
			</Card.Root>
		</div>
		<Card.Root class="mt-5 gap-0 p-4 sm:p-5">
			<Card.Header class="mb-6 flex flex-wrap items-start justify-between gap-4 px-0">
				<Card.Title class="font-semibold">Timeline</Card.Title>
				<Skeleton class="h-9 w-36 md:hidden" />
				<Skeleton class="hidden h-10 w-72 md:block" />
			</Card.Header>
			<Card.Content class="px-0">
				{#each Array(3) as _, index (index)}
					<div class="relative ml-4 pb-7 pl-7 last:pb-0">
						{#if index < 2}<span class="absolute top-5 -bottom-5 left-0 border-l border-border"
							></span>{/if}
						<span class="absolute top-1 -left-5 flex size-10 justify-center">
							{#if index === 1}
								<Skeleton class="absolute top-0 left-0 size-7 rounded-full border-2 border-card" />
								<Skeleton class="absolute top-3 left-3 size-7 rounded-full border-2 border-card" />
							{:else}<Skeleton class="size-8 rounded-full" />{/if}
						</span>
						<div class="mb-1 flex h-4 items-center"><Skeleton class="h-3 w-28" /></div>
						<div class="flex h-5 items-center"><Skeleton class="h-3.5 w-full max-w-96" /></div>
						<div class="my-3 flex items-center gap-3">
							<Skeleton class="size-11 shrink-0 rounded-sm md:rounded-md" />
							<div class="min-w-0 flex-1 space-y-2">
								<Skeleton class="h-3.5 w-3/5 max-w-56" />
								<Skeleton class="h-3 w-4/5 max-w-72" />
							</div>
						</div>
						<div class="flex h-4 items-center"><Skeleton class="h-3 w-3/4 max-w-72" /></div>
					</div>
				{/each}
			</Card.Content>
		</Card.Root>
	</div>
</div>
