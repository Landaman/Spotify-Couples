<script lang="ts">
	import * as AlertDialog from '$lib/components/ui/alert-dialog';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { page } from '$app/state';
	import { toast } from 'svelte-sonner';
	import { RedirectUrlFormField } from '../../routes/signin/shared';
	import type { ComponentProps } from 'svelte';

	// Pull this out to avoid weird null ts errors
	const {
		data: { dataRefreshPromise }
	} = $derived(page);

	let error = $state(false);
	let done = $state(false);
	let wrappedDataRefreshPromise = $state<Promise<void> | undefined>(undefined);
	$effect(() => {
		// For some reason, derived doesn't work even though it should
		if (!dataRefreshPromise) {
			return;
		}
		// SvelteKit won't let streaming promises reject, so wrap it so that the toast will do different things
		wrappedDataRefreshPromise = new Promise<void>((resolve, reject) =>
			dataRefreshPromise.then((success) => {
				done = true; // Block toast handling if it hasn't already started

				if (success) {
					resolve();
				} else {
					error = true;
					// Only actually reject if we know something will catch the rejection
					if (loading !== undefined) {
						reject();
					} else {
						resolve(); // In this case, nothing will, so have to be careful or else we get unhandled rejection
					}
				}
			})
		);
	});

	// Show the loading toast only if we need it, which can change based on navigation. But once we show it, don't rerun anything
	let loading = $state<string | number | undefined>(undefined);
	$effect(() => {
		if (
			loading !== undefined ||
			!page.data.pageInformation?.needsData ||
			wrappedDataRefreshPromise === undefined ||
			done
		) {
			return;
		}

		loading = toast.promise(wrappedDataRefreshPromise, {
			loading: 'Loading data from Spotify...',
			success: 'Succesfully retrieved data from Spotify'
		});
	});
</script>

<AlertDialog.Root open={error}>
	<AlertDialog.Content>
		<AlertDialog.Header>
			<AlertDialog.Title>Error Loading Spotify Data</AlertDialog.Title>
			<AlertDialog.Description>
				Something went wrong refreshing your data from Spotify. Please try re-authenticating.
			</AlertDialog.Description>
		</AlertDialog.Header>
		<AlertDialog.Footer>
			<Tooltip.Provider>
				<Tooltip.Root>
					<Tooltip.Trigger>
						{#snippet child({ props }: { props: ComponentProps<typeof AlertDialog.Cancel> })}
							<AlertDialog.Cancel {...props}>Continue Anyway</AlertDialog.Cancel>
						{/snippet}
					</Tooltip.Trigger>
					<Tooltip.Content>
						<p class="w-(--bits-tooltip-anchor-width) min-w-(--bits-tooltip-anchor-width)">
							We won't be able to refresh your data until you re-authenticate. <br /> <br />You can
							always re-authenticate by signing out and signing in again.
						</p>
					</Tooltip.Content>
				</Tooltip.Root>
			</Tooltip.Provider>
			<form method="POST" action="/signin">
				<input
					name={RedirectUrlFormField}
					value={`${page.url.pathname}${page.url.search}`}
					class="hidden"
				/>
				<AlertDialog.Action>Re-Authenticate</AlertDialog.Action>
			</form>
		</AlertDialog.Footer>
	</AlertDialog.Content>
</AlertDialog.Root>
