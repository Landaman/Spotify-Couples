<script lang="ts">
	import * as Avatar from '$lib/components/ui/avatar';
	import { Button } from '$lib/components/ui/button';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import { page } from '$app/stores';
	import { SignIn, SignOut } from '@auth/sveltekit/components';
	import { Settings, LogOut, ChevronDown, ChevronUp, User } from 'lucide-svelte';
	import { cubicOut } from 'svelte/easing';
	import { userPrefersMode, mode } from 'mode-watcher';
	import { MonitorCog, Sun, Moon } from 'lucide-svelte';

	// Calculate initials to show for the user based on their name
	let usersInitials: string;
	$: {
		const usersNameSpaceSplit = $page.data.session?.user?.name?.split(' ');
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

{#if $page.data.session?.user}
	<DropdownMenu.Root>
		<DropdownMenu.Trigger asChild let:builder>
			<div bind:clientWidth={triggerButtonWidth} class="h-10">
				<Button builders={[builder]} variant="outline" class="rounded-full px-0">
					<Avatar.Root class="mr-0 outline outline-1 outline-border md:mr-2">
						<Avatar.Fallback>{usersInitials}</Avatar.Fallback>
						<Avatar.Image src={$page.data.session.user.image} alt={$page.data.session.user.name} />
					</Avatar.Root>
					<p class="hidden md:inline">{$page.data.session.user.name}</p>
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
				<DropdownMenu.Item>
					<SignOut
						signOutPage="signout"
						className="contents [&>button]:contents [&>button]:cursor-default"
					>
						<div slot="submitButton" class="contents">
							<LogOut class="mr-2 h-4 w-4 text-destructive" /><span class="text-destructive"
								>Log Out</span
							>
						</div>
					</SignOut>
				</DropdownMenu.Item>
			</DropdownMenu.Group>
		</DropdownMenu.Content>
	</DropdownMenu.Root>
{:else}
	<SignIn provider="spotify" signInPage="signin" className="contents [&>button]:contents">
		<svelte:fragment slot="submitButton">
			<Button variant="outline"><User class="mr-2 h-4 w-4" />Sign In</Button>
		</svelte:fragment>
	</SignIn>
{/if}
