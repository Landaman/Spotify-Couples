<script lang="ts">
	import { createNoise2D } from 'simplex-noise';
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';

	// Dimensions for the bar and animation
	const barSpacing = 5;
	const barWidth = 10;
	const totalBarWidth = barSpacing + barWidth;
	const noiseScale = 0.05; // Scale of the noise (lower values = smoother noise)
	const durationMs = 100; // Duration of each animation frame. Lower is better (but more CPU)
	const millisecondsInSecond = 1000;
	const strokeWidth = 1; // Stroke width in px

	let mounted = $state(false); // Used to ensure the bars only render on component mount

	// Dimensions of the container box, used for calculation
	let svgContainerWidth: number = $state(0);
	let svgContainerHeight: number = $state(0);

	// Calculate dimensions
	const minimumBarHeight = $derived(svgContainerHeight / 8);
	const maximumBarHeight = $derived(svgContainerHeight);

	const noise = createNoise2D(); // This will generate realistic looking noise
	const startTime = new Date().getTime(); // Start time of the animation

	// Generate the bars. This may crop the last bar but that's fine
	const numBars = $derived(Math.ceil(svgContainerWidth / totalBarWidth));

	// Bars, so it is intrinsically reactive
	let bars = $state(new Array<number>(0).fill(0));
	$effect(() => {
		if (numBars == bars.length) {
			return; // If we don't manually cancel this, we will loop forever updating bars since we read bars at some leve
		}

		bars = new Array<number>(numBars).fill(0); // Re-create bars
		reAnimate(); // Make sure all the bars have a reasonable height
	});

	let animationFrame = 0; // Animation frame, so we can cancel on close
	let nextAnimationTimer = 0; // Animation timer, so we can cancel on close
	/**
	 * Triggers an immediate re-animation of the bars, canceling any change in place and then re-scheduling the next change.
	 * Accounts for the fact that a variable amount of time may have passed
	 */
	function reAnimate() {
		cancelAnimationFrame(animationFrame); // In case we're already animating, cancel that because this will run on resize
		clearTimeout(nextAnimationTimer); // Cancel the next timeout, as we will reset that because we will run on resize
		// Update every bar
		for (let index = 0; index < bars.length; index++) {
			bars[index] =
				((noise(
					(new Date().getTime() - startTime) / millisecondsInSecond, // Time should be in seconds
					index * noiseScale // This converts to the position with scale
				) +
					1) /
					2) * // noise is [-1, 1], so this converts [0, 1]
					(maximumBarHeight - minimumBarHeight) +
				minimumBarHeight; // This applies height
		}
		nextAnimationTimer = window.setTimeout(
			() => (animationFrame = requestAnimationFrame(reAnimate)),
			durationMs
		); // Update again. Call window to avoid weird bun issues
	}

	// Start running on component mount
	onMount(() => {
		mounted = true;

		// Animate
		animationFrame = requestAnimationFrame(reAnimate);

		return () => {
			mounted = false;

			cancelAnimationFrame(animationFrame);
			clearTimeout(nextAnimationTimer);
		}; // Cleanup the animation
	});
</script>

<div
	class="h-full w-full saturate-200"
	bind:clientWidth={svgContainerWidth}
	bind:clientHeight={svgContainerHeight}
>
	{#if mounted}
		<svg class="h-full w-full" in:fade={{ duration: 250 }}>
			<linearGradient
				x1="0"
				x2="0"
				y1={`${maximumBarHeight}px`}
				y2={`${minimumBarHeight}px`}
				gradientUnits="userSpaceOnUse"
				id="WaveGradient"
			>
				<stop offset="0%" stop-color="red" />
				<stop offset="50%" stop-color="yellow" />
				<stop offset="100%" stop-color="green" />
			</linearGradient>
			{#each bars as height, barIndex}
				<rect
					{height}
					stroke-width={strokeWidth}
					stroke="hsl(var(--primary))"
					fill="url(#WaveGradient)"
					y={maximumBarHeight - height}
					width={barWidth}
					x={strokeWidth + barIndex * totalBarWidth}
					class="transition-[height,y] duration-100 ease-linear"
				/>
			{/each}
		</svg>
	{/if}
</div>
