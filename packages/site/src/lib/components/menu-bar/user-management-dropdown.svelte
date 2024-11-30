<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import { page } from '$app/stores';
	import { Settings, LogOut, ChevronDown, ChevronUp } from 'lucide-svelte';
	import { cubicOut } from 'svelte/easing';
	import { userPrefersMode, mode } from 'mode-watcher';
	import { MonitorCog, Sun, Moon } from 'lucide-svelte';
	import { getAuth } from 'firebase/auth';
	import UserAvatar from '$lib/components/user-avatar.svelte';

	let signOutForm: HTMLFormElement | undefined = $state(); // Form element, used to programmatically submit

	// Validate we have a user
	if (!$page.data.user) {
		throw new Error('Cannot render user management dropdown when the page has no user');
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

	let triggerButtonWidth: number = $state(0);

	const MIN_DROPDOWN_WIDTH = 100;
</script>

<DropdownMenu.Root>
	<DropdownMenu.Trigger asChild let:builder>
		<div bind:clientWidth={triggerButtonWidth} class="h-10">
			<Button builders={[builder]} variant="outline" class="rounded-full px-0">
				{#if $page.data.user}
					<UserAvatar class="outline-border mr-0 outline outline-1 md:mr-2" user={$page.data.user}
					></UserAvatar>
				{/if}
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
						signOutForm?.requestSubmit(null);
					}}
				>
					<LogOut class="text-destructive mr-2 h-4 w-4" /><span class="text-destructive"
						>Log Out</span
					>
				</DropdownMenu.Item>
			</form>
		</DropdownMenu.Group>
	</DropdownMenu.Content>
</DropdownMenu.Root>
