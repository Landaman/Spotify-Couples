<script lang="ts">
	import { fade } from 'svelte/transition';
	import Waves from './waves.svelte';
	import { onMount } from 'svelte';
	import { Button } from '$lib/components/ui/button';
	import { ArrowRight } from 'lucide-svelte';

	// This plays the fade animation on
	let isMounted = false;
	onMount(() => {
		isMounted = true;

		return () => {
			isMounted = false;
		};
	});
</script>

<div class="relative flex flex-auto px-10 py-5">
	<div
		class="absolute bottom-0 left-0 right-0 top-0 z-10 flex items-center justify-center bg-background bg-opacity-25"
	>
		{#if isMounted}
			<div
				in:fade={{ delay: 650 }}
				class="flex w-3/4 flex-col items-center gap-4 rounded-lg border border-border bg-card/80 p-6 shadow-sm backdrop-blur-sm"
			>
				<div class="flex w-fit flex-col items-center gap-2 md:flex-row md:gap-3">
					<div class="flex-shrink-0">
						<enhanced:img
							src="$lib/assets/logo.png"
							alt="Spotify Couples"
							class="h-14 w-14 flex-shrink-0 md:h-16 md:w-16"
						/>
					</div>

					<h1
						class="whitespace-nowrap text-center text-3xl font-semibold tracking-wide md:text-4xl"
					>
						Spotify Couples
					</h1>
				</div>

				<p class="text-lg text-muted-foreground md:text-xl">
					Visualize you and your partners shared love of music. Track favorite songs, shared
					listens, shared listening time, listen together, and more.
				</p>

				<Button class="group gap-1" href="/signup"
					>Get Started <ArrowRight
						class="animate-bounce-right group-hover:translate-x-[10%] group-hover:animate-none"
					/>
				</Button>
			</div>
		{/if}
	</div>
	<Waves />
</div>
