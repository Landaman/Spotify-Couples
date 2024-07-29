<script lang="ts">
	import { onMount } from 'svelte';
	import { cubicInOut } from 'svelte/easing';
	import { tweened } from 'svelte/motion';

	/**
	 * The maximum height to draw the wave at
	 */
	export let maxHeight: number;
	/**
	 * The width to draw the rectangle at
	 */
	export let width: number;
	/**
	 * The x-position to draw the wave at
	 */
	export let x: number;
	/**
	 * The duration to apply to the animation
	 */
	export let duration: number;
	/**
	 * The delay to apply to the animation
	 */
	export let delay: number | undefined = undefined;
	/**
	 * Fill to apply to the drawn rectangle
	 */
	export let fill: string | undefined = undefined;

	// Tween for the current height
	const currentHeight = tweened<number>(undefined, {
		duration,
		delay,
		easing: cubicInOut
	});

	onMount(() => {
		// Updates the height of the rectangle periodically, forever
		let frame = requestAnimationFrame(async function updateHeight() {
			await currentHeight.set($currentHeight == 0 ? Math.random() * maxHeight : 0);
			frame = requestAnimationFrame(updateHeight);
		});

		return () => {
			cancelAnimationFrame(frame); // This cancels the animation
		};
	});
</script>

<rect {fill} height={$currentHeight} {x} {width} y={maxHeight - $currentHeight} />
