<script lang="ts">
	import { fade } from 'svelte/transition';
	import Waves from './waves.svelte';
	import { onMount } from 'svelte';
	import { Button } from '$lib/components/ui/button';
	import { ArrowRight } from 'lucide-svelte';

	// This plays the fade animation on
	let isMounted = $state(false);
	onMount(() => {
		isMounted = true;

		return () => {
			isMounted = false;
		};
	});
</script>

<div class="relative flex flex-auto px-4 py-5 md:px-8">
	<div
		class="bg-background absolute bottom-0 left-0 right-0 top-0 z-10 flex items-center justify-center bg-opacity-25"
	>
		{#if isMounted}
			<div
				in:fade={{ delay: 650 }}
				class="border-border bg-card/80 flex w-3/4 flex-col items-center gap-4 rounded-lg border p-6 shadow-sm backdrop-blur-sm"
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
						class="whitespace-nowrap text-center text-3xl font-semibold tracking-tight md:text-4xl"
					>
						Spotify Couples
					</h1>
				</div>

				<p class="text-muted-foreground text-lg md:text-xl">
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
