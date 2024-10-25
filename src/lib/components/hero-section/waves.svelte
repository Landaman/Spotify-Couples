<script lang="ts">
	import { tweened } from 'svelte/motion';
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

	// Dimensions of the container box, used for calculation
	let svgContainerWidth: number = $state(0);
	let svgContainerHeight: number = $state(0);

	// Calculate dimensions
	const minimumBarHeight = $derived(svgContainerHeight / 8);
	const maximumBarHeight = $derived(svgContainerHeight);

	const noise = createNoise2D(); // This will generate realistic looking noise
	let time = 0; // Time, so the wave varies

	// Generate the bars. This may crop the last bar but that's fine
	const numBars = $derived(Math.ceil(svgContainerWidth / totalBarWidth));

	// Using undefined as initial makes it immediately animate to the
	// first value (when we have no bars yet). Using NaN makes it so we
	// immediately animate to the first values
	const bars = $derived(
		tweened<number[]>(isNaN(numBars) ? undefined : new Array(numBars).fill(NaN), {
			duration: durationMs
		})
	);

	// Start running on component mount
	onMount(() => {
		// Animate
		let frame = requestAnimationFrame(async function updateBars() {
			// Await makes it wait until the animation finishes (duration)
			await bars.set(
				$bars.map(
					(_, index) =>
						((noise(
							time / millisecondsInSecond, // Time should be in seconds
							index * noiseScale // This converts to the position with scale
						) +
							1) /
							2) * // noise is [-1, 1], so this converts [0, 1]
							(maximumBarHeight - minimumBarHeight) +
						minimumBarHeight // This applies height
				)
			);
			time += durationMs; // Time is in seconds
			frame = requestAnimationFrame(updateBars); // Update again
		});

		return () => {
			cancelAnimationFrame(frame);
		}; // Cleanup the animation
	});
</script>

<div
	class="h-full w-full saturate-200"
	bind:clientWidth={svgContainerWidth}
	bind:clientHeight={svgContainerHeight}
>
	<svg class="h-full w-full">
		{#if minimumBarHeight && maximumBarHeight}
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
			{#if $bars}
				{#each $bars as height, barIndex}
					{#if height}
						<rect
							in:fade={{ duration: 250 }}
							{height}
							stroke-width={strokeWidth}
							stroke="hsl(var(--primary))"
							fill="url(#WaveGradient)"
							y={maximumBarHeight - height}
							width={barWidth}
							x={strokeWidth + barIndex * totalBarWidth}
						/>
					{/if}
				{/each}
			{/if}
		{/if}
	</svg>
</div>
