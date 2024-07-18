<script lang="ts">
	import * as Avatar from '$lib/components/ui/avatar/index.js';
	import Button from '$lib/components/ui/button/button.svelte';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import { page } from '$app/stores';
	import { SignIn, SignOut } from '@auth/sveltekit/components';
	import { Settings, LogOut, ChevronDown, ChevronUp } from 'lucide-svelte';
	import { cubicOut } from 'svelte/easing';

	// Calculate initials to show for the user based on their name
	const usersNameSpaceSplit = $page.data.session?.user?.name?.split(' ');
	let usersInitials: string;
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

{#if $page.data.session?.user}
	<DropdownMenu.Root>
		<DropdownMenu.Trigger asChild let:builder>
			<Button builders={[builder]} variant="outline" class="px-0 rounded-full">
				<Avatar.Root class="outline outline-1 outline-border mr-2">
					<Avatar.Fallback>{usersInitials}</Avatar.Fallback>
					<Avatar.Image src={$page.data.session.user.image} alt={$page.data.session.user.name} />
				</Avatar.Root>
				{$page.data.session.user.name}
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
		</DropdownMenu.Trigger>
		<DropdownMenu.Content sameWidth>
			<DropdownMenu.Label>My Account</DropdownMenu.Label>
			<DropdownMenu.Separator />
			<DropdownMenu.Group>
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
		<div slot="submitButton" class="contents">
			<Button variant="outline">Sign In</Button>
		</div>
	</SignIn>
{/if}
