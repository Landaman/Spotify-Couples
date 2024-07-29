<script lang="ts">
	import Wave from './wave.svelte';

	// Dimensions for the bar
	const barSpacing = 5;
	const barWidth = 20;
	const duration = 500;
	const delayStagger = 50;
	const totalBarWidth = barSpacing + barWidth;

	// Dimensions of the container box, used for calculation
	let svgContainerWidth: number;
	let svgContainerHeight: number;

	// Generate the bars. This may crop the top bar but that's fine
	$: numBars = Math.floor(svgContainerWidth / totalBarWidth);
	$: bars = new Array<number>(isNaN(numBars) ? 0 : numBars);
</script>

<div
	class="h-full w-full"
	bind:clientWidth={svgContainerWidth}
	bind:clientHeight={svgContainerHeight}
>
	<svg class="h-full w-full">
		<linearGradient x1="0" x2="0" y1="1" y2="0" id="WaveGradient">
			<stop offset="0%" stop-color="red" />
			<stop offset="50%" stop-color="yellow" />
			<stop offset="100%" stop-color="green" />
		</linearGradient>
		{#each bars as _, barIndex}
			<Wave
				fill="url(#WaveGradient)"
				maxHeight={svgContainerHeight}
				width={barWidth}
				x={barIndex * totalBarWidth}
				{duration}
				delay={delayStagger * barIndex}
			/>
		{/each}
	</svg>
</div>
