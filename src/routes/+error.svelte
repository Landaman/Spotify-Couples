<script lang="ts">
	import { page } from '$app/state';
	import { resolve } from '$app/paths';
	import BrokenBeat from '#lib/components/broken-beat.svelte';
	import { Button } from '#lib/components/ui/button/index.js';
	import { House } from '@lucide/svelte';

	const copy = $derived(
		page.status === 404
			? {
					title: 'This track is missing',
					description:
						'We couldn’t find that page. The link may be out of date, or the page may have moved.'
				}
			: {
					title: 'Something went wrong',
					description: 'This request couldn’t be completed. Head home to try another page.'
				}
	);
</script>

<svelte:head>
	<title>{page.status} · {copy.title} | Spotify Couples</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<main class="flex w-full items-center justify-center px-4 py-16 md:px-8">
	<section
		class="w-full max-w-xl rounded-2xl border bg-card p-8 text-center shadow-sm sm:p-12 md:grid md:max-w-5xl md:grid-cols-[14rem_minmax(0,1fr)] md:items-center md:gap-12 md:rounded-none md:border-0 md:bg-transparent md:p-0 md:text-left md:shadow-none lg:grid-cols-[18rem_minmax(0,1fr)] lg:gap-20"
		aria-labelledby="error-title"
	>
		<div class="hidden aspect-square md:block" aria-hidden="true">
			<BrokenBeat />
		</div>
		<div>
			<p class="text-8xl font-bold tracking-tighter text-rose-600 dark:text-rose-400">
				{page.status}
			</p>
			<h1 id="error-title" class="text-3xl font-semibold tracking-tight">{copy.title}</h1>
			<p class="text-base leading-relaxed text-muted-foreground">{copy.description}</p>
			<div
				class="mt-8 flex flex-col gap-3 md:flex-row md:flex-wrap md:items-center md:justify-start"
			>
				<Button size="default" class="md:h-11 md:gap-2 md:px-5 md:text-base" href={resolve('/')}
					><House class="size-4 md:size-5" />Home</Button
				>
			</div>
		</div>
	</section>
</main>
