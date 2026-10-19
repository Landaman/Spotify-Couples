<script lang="ts">
	import { onMount } from 'svelte';

	let imageRotateX = $state(0);
	let imageRotateY = $state(0);

	// We want to transition on initial enter and exit
	let transitionTransform = $state(true);
	let transitionTransformTimeoutId = $state<number | undefined>();

	const { src, alt, class: className }: { src: string; alt: string; class?: string } = $props();

	onMount(() => {
		// Cleanup on exit
		return () => {
			if (transitionTransformTimeoutId) {
				clearTimeout(transitionTransformTimeoutId);
			}
		};
	});
</script>

<div
	class={`${className} transition-all hover:scale-105`}
	role="img"
	onmousemove={(event) => {
		const bounds = event.currentTarget.getBoundingClientRect();

		imageRotateX = -(event.clientY - bounds.top - bounds.height / 2) / 100;
		imageRotateY = (event.clientX - bounds.left - bounds.width / 2) / 100;

		// If we don't have a timeout and we need one, set it
		if (transitionTransformTimeoutId === undefined && transitionTransform) {
			transitionTransformTimeoutId = window.setTimeout(() => {
				transitionTransform = false;
				transitionTransformTimeoutId = undefined;
			}, 150);
		}
	}}
	onmouseleave={() => {
		// If we have a timeout on exit, clear it
		if (transitionTransformTimeoutId) {
			window.clearTimeout(transitionTransformTimeoutId);
			transitionTransformTimeoutId = undefined;
		}

		transitionTransform = true;
		imageRotateX = 0;
		imageRotateY = 0;
	}}
>
	<img
		{src}
		{alt}
		class={`size-auto rounded-sm shadow-xl md:rounded-md ${transitionTransform ? 'transition-transform duration-150 ease-linear' : ''}`}
		style="transform: perspective(10px) rotateX({imageRotateX}deg) rotateY({imageRotateY}deg);"
	/>
</div>
