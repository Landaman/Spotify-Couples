<script lang="ts">
	import { Toaster as Sonner, type ToasterProps as SonnerProps } from 'svelte-sonner';
	import { mode } from 'mode-watcher';
	import Loader2Icon from '@lucide/svelte/icons/loader-2';
	import CircleCheckIcon from '@lucide/svelte/icons/circle-check';
	import OctagonXIcon from '@lucide/svelte/icons/octagon-x';
	import InfoIcon from '@lucide/svelte/icons/info';
	import TriangleAlertIcon from '@lucide/svelte/icons/triangle-alert';

	const { ...restProps }: SonnerProps = $props();
</script>

<Sonner
	theme={mode.current}
	class="toaster group"
	style="--normal-bg: var(--color-popover); --normal-text: var(--color-popover-foreground); --normal-border: var(--color-border);"
	{...restProps}
>
	<Loader2Icon slot="loading-icon" class="size-4 animate-spin" />
	<CircleCheckIcon slot="success-icon" class="size-4" />
	<OctagonXIcon slot="error-icon" class="size-4" />
	<InfoIcon slot="info-icon" class="size-4" />
	<TriangleAlertIcon slot="warning-icon" class="size-4" />
</Sonner>
