<script lang="ts">
	import { onMount } from 'svelte';
	import type { SVGAttributes } from 'svelte/elements';
	import { tweened } from 'svelte/motion';

	type $$Props = Omit<SVGAttributes<SVGRectElement>, 'y' & 'height'> & {
		/**
		 * Maximum height to allow on the rectangle
		 */
		maxHeight: number;
		/**
		 * Minimum height to allow on the rectangle (defaults to 0)
		 */
		minHeight?: number;
		/**
		 * Maximum animation duration
		 */
		maxDuration: number;
		/**
		 * Minimum animation duration (defaults to 0)
		 */
		minDuration?: number;
		/**
		 * Maximum animation delay
		 */
		maxDelay: number;
		/**
		 * Minimum animation delay (defaults to 0)
		 */
		minDelay?: number;
		/**
		 * Y position to draw a rectangle of 0 height at
		 */
		baseY?: number;
		/**
		 * Whether to grow the rectangle from baseY in the positive or negative direction based on the
		 * generated height
		 */
		growDirection: 'positive' | 'negative';
		/**
		 * Easing function to apply to the animation
		 */
		easing?: ((t: number) => number) | undefined;
	};
	export let maxHeight;
	export let minHeight = 0; // Default to 0
	export let maxDuration;
	export let minDuration = 0; // Default to 0
	export let maxDelay;
	export let minDelay = 0; // Default to 0
	export let baseY = 0; // Default to 0
	export let growDirection;
	export let easing: $$Props['easing'] = undefined; // This needs to be allowed to be undefined

	/**
	 * Helper function to generate a random value in the provided range
	 * @param max the max of the range
	 * @param min the min of the range
	 */
	function generateRandomValueInRange(max: number, min: number) {
		return Math.random() * (max - min) + min;
	}

	// Tween for the current height
	const currentHeight = tweened<number>(minHeight, {
		duration: generateRandomValueInRange(maxDuration, minDuration),
		delay: generateRandomValueInRange(maxDelay, minDelay),
		easing
	});

	onMount(() => {
		// Updates the height of the rectangle periodically, forever
		let frame = requestAnimationFrame(async function updateHeight() {
			await currentHeight.set(
				$currentHeight == minHeight
					? generateRandomValueInRange(maxHeight, minHeight)
					: (minHeight ?? 0),
				{
					duration: generateRandomValueInRange(maxDuration, minDuration),
					delay: generateRandomValueInRange(maxDelay, minDelay)
				}
			);
			frame = requestAnimationFrame(updateHeight);
		});

		return () => {
			cancelAnimationFrame(frame); // This cancels the animation
		};
	});
</script>

<rect
	height={$currentHeight}
	{...$$restProps}
	y={(baseY ?? 0) + (growDirection == 'positive' ? 0 : -1) * $currentHeight}
/>
