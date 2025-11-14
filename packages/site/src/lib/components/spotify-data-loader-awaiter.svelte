<script lang="ts">
	import * as AlertDialog from '$lib/components/ui/alert-dialog';
	import * as Tooltip from '$lib/components/ui/tooltip';
	import { page } from '$app/stores';
	import { toast } from 'svelte-sonner';

	// Pull this out to avoid weird null ts errors
	const {
		data: { dataRefreshPromise }
	} = $derived($page);

	let error = $state(false);
	let wrappedDataRefreshPromise = $state<Promise<void> | undefined>(undefined);
	$effect(() => {
		// For some reason, derived doesn't work even though it should
		if (!dataRefreshPromise) {
			return;
		}
		// SvelteKit won't let streaming promises reject, so wrap it so that the toast will do different things
		wrappedDataRefreshPromise = new Promise<void>((resolve, reject) =>
			dataRefreshPromise.then((success) => {
				if (success) {
					resolve();
				} else {
					error = true;
					reject();
				}
			})
		);
	});

	// Show the loading toast only if we need it, which can change based on navigation. But once we show it, don't rerun anything
	let loading = $state<string | number | undefined>(undefined);
	$effect(() => {
		if (
			loading !== undefined ||
			!$page.data.pageInformation?.needsData ||
			wrappedDataRefreshPromise === undefined
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
			<Tooltip.Root>
				<Tooltip.Trigger asChild>
					<AlertDialog.Cancel>Continue Anyway</AlertDialog.Cancel>
				</Tooltip.Trigger>
				<Tooltip.Content>
					<p>
						We won't be able to refresh your data until you re-authenticate. You can always
						re-authenticate by signing out and signing in again
					</p>
				</Tooltip.Content>
			</Tooltip.Root>
			<AlertDialog.Action>Re-Authenticate</AlertDialog.Action>
		</AlertDialog.Footer>
	</AlertDialog.Content>
</AlertDialog.Root>
