<script lang="ts">
	import { enhance } from '$app/forms';
	import { Button } from '$lib/components/ui/button';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import { page } from '$app/state';
	import { Settings, LogOut, ChevronDown, ChevronUp } from '@lucide/svelte';
	import { cubicOut } from 'svelte/easing';
	import { userPrefersMode, mode } from 'mode-watcher';
	import { MonitorCog, Sun, Moon } from '@lucide/svelte';
	import UserAvatar from '$lib/components/user-avatar.svelte';

	let signOutForm: HTMLFormElement | undefined = $state(); // Form element, used to programmatically submit

	// Validate we have a user
	if (!page.data.session) {
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
</script>

<DropdownMenu.Root>
	<DropdownMenu.Trigger>
		{#snippet child({ props })}
			{#if page.data.session}
				<!-- For some reason, this has to be inside that statement I think bc snippet -->
				<Button {...props} variant="outline" class="gap-0 rounded-full px-0">
					<UserAvatar
						class="outline-border mr-0 outline-solid outline-1 md:mr-2"
						{...page.data.session.user.profile}
					></UserAvatar>
					<p class="hidden md:inline">{page.data.session?.user.profile.name}</p>
					{#if props['data-state'] == 'open'}
						<!-- Two divs so the divs actually re-animate -->
						<div in:rotateXFromTo>
							<ChevronUp class="ml-1 size-6!" />
						</div>
					{:else}
						<div in:rotateXFromTo>
							<ChevronDown class="ml-1 size-6!" />
						</div>
					{/if}
				</Button>
			{/if}
		{/snippet}
	</DropdownMenu.Trigger>
	<DropdownMenu.Content
		class="md:w-(--bits-dropdown-menu-anchor-width) md:min-w-(--bits-dropdown-menu-anchor-width)"
	>
		<DropdownMenu.Label>My Account</DropdownMenu.Label>
		<DropdownMenu.Separator />
		<DropdownMenu.Group>
			<DropdownMenu.Sub>
				<DropdownMenu.SubTrigger>
					{#if mode.current === 'light'}
						<Sun class="mr-2 h-4 w-4" />
					{:else}
						<Moon class="mr-2 h-4 w-4" />
					{/if}
					Theme</DropdownMenu.SubTrigger
				>
				<DropdownMenu.SubContent>
					<DropdownMenu.RadioGroup bind:value={userPrefersMode.current}>
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
			<DropdownMenu.Item><Settings class="mr-2 h-4 w-4" /> <span>Settings</span></DropdownMenu.Item>
			<form method="post" action="/signout" use:enhance bind:this={signOutForm}>
				<DropdownMenu.Item
					onclick={async () => {
						signOutForm?.requestSubmit();
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
