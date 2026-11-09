import type { Tooltip } from 'layerchart';
import { getContext, setContext, type Component, type Snippet } from 'svelte';

export const THEMES = { light: '', dark: '.dark' } as const;

export type ChartConfig = Record<
	string,
	{
		label?: string;
		icon?: Component;
	} & (
		| { color?: string; theme?: never }
		| { color?: never; theme: Record<keyof typeof THEMES, string> }
	)
>;

export type ExtractSnippetParams<T> = T extends Snippet<[infer P]> ? P : never;

export type TooltipPayload = Tooltip.TooltipSeries;

/**
 * Resolves display configuration for a tooltip series
 * @param config - Registered chart series
 * @param payload - Hovered series metadata
 * @param key - Series identifier
 * @param data - Optional original datum
 * @returns Matching series configuration, when available
 */
// Helper to extract item config from a payload.
export function getPayloadConfigFromPayload(
	config: ChartConfig,
	payload: TooltipPayload,
	key: string,
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	data?: Record<string, any> | null
) {
	if (typeof payload !== 'object' || payload === null) return undefined;

	const payloadConfig =
		'config' in payload && typeof payload.config === 'object' && payload.config !== null
			? payload.config
			: undefined;

	let configLabelKey: string = key;

	if (payload.key === key) {
		configLabelKey = payload.key;
	} else if (payload.label === key) {
		configLabelKey = payload.label;
	} else if (key in payload && typeof payload[key as keyof typeof payload] === 'string') {
		configLabelKey = payload[key as keyof typeof payload] as string;
	} else if (
		payloadConfig !== undefined &&
		key in payloadConfig &&
		typeof payloadConfig[key as keyof typeof payloadConfig] === 'string'
	) {
		configLabelKey = payloadConfig[key as keyof typeof payloadConfig] as string;
	} else if (data != null && key in data && typeof data[key] === 'string') {
		configLabelKey = data[key] as string;
	}

	return configLabelKey in config ? config[configLabelKey] : config[key as keyof typeof config];
}

/** Chart configuration shared with tooltip components */
interface ChartContextValue {
	/** Registered series labels and colors */
	config: ChartConfig;
}

const chartContextKey = Symbol('chart-context');

/** Shares the supplied chart configuration and returns the stored context */
export function setChartContext(value: ChartContextValue) {
	return setContext(chartContextKey, value);
}

/** Returns the nearest chart configuration context */
export function useChart() {
	return getContext<ChartContextValue>(chartContextKey);
}
