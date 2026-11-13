<script lang="ts">
	import * as Chart from '#lib/components/ui/chart/index.js';
	import { BarChart } from 'layerchart';
	import { duration, type JournalDay } from './journal';

	/** Pair listening buckets and series labels */
	interface Props {
		/** Range-filtered listening durations */
		daily: JournalDay[];
		/** Partner's legend label */
		partnerName: string;
	}
	let { daily, partnerName }: Props = $props();
	const hourly = $derived(daily.some((bucket) => bucket.day.includes('T')));
	const data = $derived(
		daily.map((bucket, index) => ({
			bucket: String(index),
			you: bucket.you / 3600,
			partner: bucket.partner / 3600
		}))
	);
	const config = $derived({
		you: { label: 'You', color: 'var(--foreground)' },
		partner: { label: partnerName, color: 'var(--muted-foreground)' }
	} satisfies Chart.ChartConfig);
	const series = $derived(Object.entries(config).map(([key, value]) => ({ key, ...value })));
	const ticks = $derived(
		data
			.filter((_, index) => index % Math.ceil(Math.max(data.length, 1) / 6) === 0)
			.map((bucket) => bucket.bucket)
	);
</script>

<div
	class="relative min-h-64 flex-1"
	role="figure"
	aria-label="Estimated listening hours for you and your partner by date or time"
>
	<Chart.Container {config} class="absolute inset-0 aspect-auto size-full">
		<BarChart
			{data}
			x="bucket"
			{series}
			seriesLayout="group"
			padding={{ left: 48, bottom: 56, top: 8, right: 8 }}
			legend
			yDomain={[0, Math.max(1, ...data.flatMap((bucket) => [bucket.you, bucket.partner]))]}
			props={{
				xAxis: {
					label: hourly ? 'Time' : 'Date',
					labelProps: { dy: -24 },
					ticks,
					format: (value) =>
						hourly
							? (daily[Number(value)]?.day.slice(11) ?? '')
							: (daily[Number(value)]?.day.slice(5) ?? '')
				},
				yAxis: { label: 'Estimated Hours', format: (value) => Number(value).toFixed(1) }
			}}
		>
			{#snippet tooltip()}
				<Chart.Tooltip labelFormatter={(value) => daily[Number(value)]?.day ?? String(value)}>
					{#snippet formatter({ value, name })}<span>{name}</span><span class="ml-auto font-mono"
							>{duration(Number(value) * 3600)}</span
						>{/snippet}
				</Chart.Tooltip>
			{/snippet}
		</BarChart>
	</Chart.Container>
</div>
