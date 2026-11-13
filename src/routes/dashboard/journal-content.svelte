<script lang="ts">
	import * as Card from '#lib/components/ui/card/index.js';
	import * as Tabs from '#lib/components/ui/tabs/index.js';
	import * as NativeSelect from '#lib/components/ui/native-select/index.js';
	import * as ToggleGroup from '#lib/components/ui/toggle-group/index.js';
	import SpotifyItemPicture from '#lib/components/spotify-item-picture.svelte';
	import ListeningTimeChart from './listening-time-chart.svelte';
	import UserAvatar from '#lib/components/user-avatar.svelte';
	import { duration, type Journal, type JournalEvent } from './journal';

	/** Profile identity used for timeline avatars */
	interface AvatarProfile {
		/** Display name used for avatar initials */
		name: string;
		/** Profile picture, when available */
		picture_url: string | null;
	}
	/** Display data and current pair's profiles */
	interface Props {
		/** Database-derived aggregates */
		journal: Journal;
		/** Signed-in listener's avatar identity */
		user: AvatarProfile;
		/** Current partner's avatar identity */
		partner: AvatarProfile;
	}
	let { journal, user, partner }: Props = $props();
	const partnerName = $derived(partner.name);
	let category = $state('songs');
	let listener = $state('both');
	let filter = $state('all');
	const events = $derived(
		journal.timeline.filter(
			(event) =>
				filter === 'all' ||
				(filter === 'shared'
					? event.kind === 'shared'
					: event.kind === 'unique' && event.listener === filter)
		)
	);
	const firstPlayFormat = $derived(
		new Intl.DateTimeFormat(undefined, {
			timeZone: journal.timezone,
			month: 'short',
			day: 'numeric',
			year: 'numeric'
		})
	);
	const timeFormat = $derived(
		new Intl.DateTimeFormat(undefined, {
			timeZone: journal.timezone,
			month: 'short',
			day: 'numeric',
			hour: 'numeric',
			minute: '2-digit'
		})
	);
</script>

{#snippet eventReason(event: JournalEvent)}
	{#if event.kind === 'shared'}
		<strong>You</strong> and <strong>{partnerName}</strong> listened to the same song at the same time
	{:else if event.first_play}
		<strong>{event.listener === 'you' ? 'You' : partnerName}</strong> listened to a new song
	{:else if (event.listener === 'you' ? event.you : event.partner) > 1}
		<strong>{event.listener === 'you' ? 'You' : partnerName}</strong> kept coming back to this song
	{:else}
		Only <strong>{event.listener === 'you' ? 'you' : partnerName}</strong> played this song
	{/if}
{/snippet}

<div class="grid items-start gap-5 lg:grid-cols-2 lg:items-stretch">
	<Card.Root role="region" aria-labelledby="top-listens" class="min-w-0 gap-4 p-4 sm:p-5">
		<Card.Header class="px-0"
			><Card.Title id="top-listens" role="heading" aria-level={2} class="font-semibold"
				>Top Listens</Card.Title
			></Card.Header
		>
		<Card.Content class="px-0">
			<Tabs.Root bind:value={category}>
				<div class="flex flex-wrap items-center justify-between gap-3">
					<Tabs.List aria-label="Ranking category">
						{#each ['songs', 'artists', 'albums'] as item (item)}<Tabs.Trigger
								value={item}
								class="capitalize">{item}</Tabs.Trigger
							>{/each}
					</Tabs.List>
					<NativeSelect.Root size="sm" aria-label="Ranking listener" bind:value={listener}>
						<NativeSelect.Option value="both">Combined</NativeSelect.Option><NativeSelect.Option
							value="you">You</NativeSelect.Option
						><NativeSelect.Option value="partner">{partnerName}</NativeSelect.Option>
					</NativeSelect.Root>
				</div>
				{#each ['songs', 'artists', 'albums'] as item (item)}
					<Tabs.Content value={item}>
						<ol aria-live="polite">
							{#each journal.rankings.filter((row) => row.category === item && row.listener === listener) as row, index (`${row.category}-${row.listener}-${row.id}`)}
								<li class="flex items-center gap-3 border-b py-3 last:border-0">
									<span class="w-3 text-xs text-muted-foreground">{index + 1}</span>
									<SpotifyItemPicture src={row.picture} alt={row.name} size="sm" />
									<div class="min-w-0 flex-1">
										<p class="truncate text-sm font-medium">{row.name}</p>
										{#if item !== 'artists' && row.subtitle}<p
												class="truncate text-xs text-muted-foreground"
											>
												{row.subtitle}
											</p>{/if}
									</div>
									<span class="shrink-0 text-xs tabular-nums"
										>{row.plays} <span class="text-muted-foreground">plays</span></span
									>
								</li>
							{:else}<li class="py-8 text-sm text-muted-foreground">
									No recorded {item} for this listener in the selected period
								</li>{/each}
						</ol>
					</Tabs.Content>
				{/each}
			</Tabs.Root>
		</Card.Content>
	</Card.Root>
	<Card.Root role="region" aria-labelledby="listening-time" class="min-w-0 gap-4 p-4 sm:p-5">
		<Card.Header class="px-0"
			><Card.Title id="listening-time" role="heading" aria-level={2} class="font-semibold"
				>Listening Time</Card.Title
			></Card.Header
		>
		<Card.Content class="min-h-64 flex-1 px-0"
			><ListeningTimeChart daily={journal.daily} {partnerName} /></Card.Content
		>
	</Card.Root>
</div>
<Card.Root role="region" class="mt-5 gap-0 p-4 sm:p-5" aria-labelledby="journal-timeline">
	<Card.Header class="mb-6 flex flex-wrap items-start justify-between gap-4 px-0">
		<Card.Title id="journal-timeline" role="heading" aria-level={2} class="font-semibold"
			>Timeline</Card.Title
		>
		<NativeSelect.Root
			class="max-w-full md:hidden"
			aria-label="Timeline listeners"
			bind:value={filter}
		>
			<NativeSelect.Option value="all">All listens</NativeSelect.Option><NativeSelect.Option
				value="shared">Combined</NativeSelect.Option
			><NativeSelect.Option value="you">Only you</NativeSelect.Option><NativeSelect.Option
				value="partner">Only {partnerName}</NativeSelect.Option
			>
		</NativeSelect.Root>

		<ToggleGroup.Root
			type="single"
			bind:value={filter}
			onValueChange={(value) => {
				// Keep a listener selection when the active toggle is pressed again
				filter = value || 'all';
			}}
			size="sm"
			class="hidden max-w-full flex-wrap bg-secondary p-1 md:flex"
			aria-label="Timeline listeners"
		>
			{#each [{ value: 'all', label: 'All' }, { value: 'shared', label: 'Combined' }, { value: 'you', label: 'Only You' }, { value: 'partner', label: `Only ${partnerName}` }] as item (item.value)}
				<ToggleGroup.Item value={item.value} class="text-xs">{item.label}</ToggleGroup.Item>
			{/each}
		</ToggleGroup.Root>
	</Card.Header>
	<Card.Content class="px-0" aria-live="polite">
		{#each events as event, index (`${event.kind}-${event.listener}-${event.id}`)}
			<article class="relative ml-4 pb-7 pl-7 last:pb-0">
				{#if index < events.length - 1}<span
						class="absolute top-5 -bottom-5 left-0 border-l border-border"
						aria-hidden="true"
					></span>{/if}
				<span class="absolute top-1 -left-5 flex size-10 justify-center" aria-hidden="true">
					{#if event.listener === 'both'}
						<UserAvatar
							{...user}
							class="absolute top-0 left-0 size-7 border-2 border-card text-[10px]"
						/>
						<UserAvatar
							{...partner}
							class="absolute top-3 left-3 size-7 border-2 border-card text-[10px]"
						/>
					{:else}
						<UserAvatar
							{...event.listener === 'you' ? user : partner}
							class="size-8 border border-card text-[10px]"
						/>
					{/if}
				</span>
				<time datetime={event.occurred_at} class="mb-1 block text-xs text-muted-foreground"
					>{timeFormat.format(new Date(event.occurred_at))}</time
				>
				<h3 class="text-sm">{@render eventReason(event)}</h3>

				<div class="my-3 flex items-center gap-3">
					<SpotifyItemPicture src={event.picture} alt={event.album} size="md" />
					<div class="min-w-0">
						<p class="text-sm font-medium wrap-anywhere">{event.name}</p>
						<p class="text-xs text-muted-foreground">{event.artist} · {event.album}</p>
					</div>
				</div>
				{#if event.kind === 'shared'}
					<p class="text-xs text-muted-foreground">
						{duration(event.overlap_seconds ?? 0)} together
					</p>
				{:else if event.kind === 'unique'}
					{@const firstPlay =
						event.listener === 'you' ? event.partner_first_play : event.you_first_play}
					<p class="text-xs text-muted-foreground">
						<strong>{event.listener === 'you' ? partnerName : 'You'}</strong>
						{#if firstPlay}first listened to this song on {firstPlayFormat.format(
								new Date(firstPlay)
							)}{:else}{event.listener === 'you' ? 'has' : 'have'} not listened to this song{/if}
					</p>
				{/if}
			</article>
		{:else}<p class="py-6 text-sm text-muted-foreground">
				No matching listening moments in this period
			</p>{/each}
	</Card.Content>
</Card.Root>
