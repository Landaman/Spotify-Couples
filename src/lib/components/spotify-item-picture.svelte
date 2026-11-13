<script lang="ts">
	import { onMount } from 'svelte';
	import { cn } from '#lib/utils.js';

	let imageRotateX = $state(0);
	let imageRotateY = $state(0);

	// We want to transition on initial enter and exit
	let transitionTransform = $state(true);
	let transitionTransformTimeoutId = $state<number | undefined>();

	/** Spotify artwork presentation */
	interface Props {
		/** Artwork URL; absent artwork uses a placeholder */
		src?: string | null;
		/** Accessible image description */
		alt: string;
		/** Wrapper sizing and layout classes */
		class?: string;
		/** Compact artwork sizes, or auto sizing for existing callers */
		size?: 'auto' | 'sm' | 'md';
	}
	const { src, alt, class: className, size = 'auto' }: Props = $props();

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
	class={cn(
		'transition-all hover:scale-105',
		size === 'sm' && 'size-10 shrink-0',
		size === 'md' && 'size-11 shrink-0',
		className
	)}
	role="img"
	aria-label={alt}
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
	{#if src}<img
			{src}
			{alt}
			class={cn(
				'rounded-sm shadow-xl md:rounded-md',
				size === 'auto' ? 'size-auto' : 'size-full object-cover',
				transitionTransform && 'transition-transform duration-150 ease-linear'
			)}
			style="transform: perspective(10px) rotateX({imageRotateX}deg) rotateY({imageRotateY}deg);"
		/>{:else}<span
			class="flex size-full items-center justify-center rounded border bg-secondary text-muted-foreground"
			aria-hidden="true">♪</span
		>{/if}
</div>
