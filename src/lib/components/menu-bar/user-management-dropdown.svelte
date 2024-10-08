<script lang="ts">
	import * as Avatar from '$lib/components/ui/avatar';
	import { Button } from '$lib/components/ui/button';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import { page } from '$app/stores';
	import { Settings, LogOut, ChevronDown, ChevronUp } from 'lucide-svelte';
	import { cubicOut } from 'svelte/easing';
	import { userPrefersMode, mode } from 'mode-watcher';
	import { MonitorCog, Sun, Moon } from 'lucide-svelte';
	import { getAuth } from 'firebase/auth';

	// Calculate initials to show for the user based on their name
	let usersInitials: string;
	let signOutForm: HTMLFormElement; // Form element, used to programmatically submit
	$: {
		const usersNameSpaceSplit = $page.data.user?.displayName.split(' ');
		if (!usersNameSpaceSplit || usersNameSpaceSplit.length == 0) {
			usersInitials = '?'; // This shouldn't really ever happen
		} else if (usersNameSpaceSplit.length == 1) {
			// This can happen if they only have a username e.g., ianwright123
			usersInitials = (
				usersNameSpaceSplit[0].charAt(0) + usersNameSpaceSplit[0].charAt(1)
			).toUpperCase();
		} else {
			usersInitials = (
				usersNameSpaceSplit[0].charAt(0) + usersNameSpaceSplit[1].charAt(0)
			).toUpperCase();
		}
	}

	/**
	 * Transition to rotate an element's X from a given position to a given position
	 * @param node the element to spin
	 * @param params the params on the spinning, including duration, easing function, and start and end degrees
	 */
	function rotateXFromTo(
		node: HTMLElement,
		params?: {
			duration?: number;
			easing?: (t: number) => number;
			initialDegrees?: number;
			endDegrees?: number;
		}
	) {
		const existingTransform = getComputedStyle(node).transform.replace('none', ''); // Ensure we keep other transitions

		const initialDegrees = params?.initialDegrees ?? 180;
		const endDegrees = params?.endDegrees ?? 0;
		const degreeDelta = endDegrees - initialDegrees;
		return {
			duration: params?.duration ?? 400,
			easing: params?.easing ?? cubicOut,
			css: (t: number) =>
				`transform: ${existingTransform} rotateX(${t * degreeDelta + initialDegrees}deg);`
		};
	}

	let triggerButtonWidth: number;
	const MIN_DROPDOWN_WIDTH = 100;
</script>

<DropdownMenu.Root>
	<DropdownMenu.Trigger asChild let:builder>
		<div bind:clientWidth={triggerButtonWidth} class="h-10">
			<Button builders={[builder]} variant="outline" class="rounded-full px-0">
				<Avatar.Root class="mr-0 outline outline-1 outline-border md:mr-2">
					<Avatar.Fallback>{usersInitials}</Avatar.Fallback>
					<Avatar.Image
						src={$page.data.user?.profilePictureUrl}
						alt={$page.data.user?.displayName}
					/>
				</Avatar.Root>
				<p class="hidden md:inline">{$page.data.user?.displayName}</p>
				{#if builder['data-state'] == 'open'}
					<div in:rotateXFromTo>
						<ChevronUp class="ml-1" />
					</div>
				{:else}
					<div in:rotateXFromTo>
						<ChevronDown class="ml-1" />
					</div>
				{/if}
			</Button>
		</div>
	</DropdownMenu.Trigger>
	<DropdownMenu.Content sameWidth={triggerButtonWidth > MIN_DROPDOWN_WIDTH}>
		<DropdownMenu.Label>My Account</DropdownMenu.Label>
		<DropdownMenu.Separator />
		<DropdownMenu.Group>
			<DropdownMenu.Sub>
				<DropdownMenu.SubTrigger>
					{#if $mode === 'light'}
						<Sun class="mr-2 h-4 w-4" />
					{:else}
						<Moon class="mr-2 h-4 w-4" />
					{/if}
					Theme</DropdownMenu.SubTrigger
				>
				<DropdownMenu.SubContent>
					<DropdownMenu.RadioGroup bind:value={$userPrefersMode}>
						<DropdownMenu.RadioItem value="system"
							><MonitorCog class="mr-2 h-4 w-4" />System</DropdownMenu.RadioItem
						>
						<DropdownMenu.RadioItem value="light"
							><Sun class="mr-2 h-4 w-4" />Light</DropdownMenu.RadioItem
						>
						<DropdownMenu.RadioItem value="dark"
							><Moon class="mr-2 h-4 w-4" />Dark</DropdownMenu.RadioItem
						>
					</DropdownMenu.RadioGroup>
				</DropdownMenu.SubContent>
			</DropdownMenu.Sub>
			<DropdownMenu.Item href="/settings"
				><Settings class="mr-2 h-4 w-4" /> <span>Settings</span></DropdownMenu.Item
			>
			<form method="post" action="/signout" bind:this={signOutForm}>
				<DropdownMenu.Item
					on:click={async () => {
						await getAuth().signOut(); // This will invalidate the custom token the user signed in with
						signOutForm.requestSubmit(null);
					}}
				>
					<LogOut class="mr-2 h-4 w-4 text-destructive" /><span class="text-destructive"
						>Log Out</span
					>
				</DropdownMenu.Item>
			</form>
		</DropdownMenu.Group>
	</DropdownMenu.Content>
</DropdownMenu.Root>
