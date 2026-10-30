<script lang="ts">
	import PageLayout from '#lib/components/page-layout.svelte';
	import { Button } from '#lib/components/ui/button/index.js';
	import { Heart } from '@lucide/svelte';
	import type { PageProps } from './$types';
	import PartnerSettings from './partner-settings.svelte';

	let { data, form }: PageProps = $props();
</script>

<PageLayout title="Settings" description="A little housekeeping for your shared listening">
	{#snippet navigation(onNavigate?: () => void)}
		<Button
			href="#partner"
			variant="secondary"
			class="w-full justify-start gap-3"
			aria-current="location"
			onclick={onNavigate}
		>
			<Heart />Partner
		</Button>
	{/snippet}

	<PartnerSettings partner={data.partner} message={form?.message} />
</PageLayout>
