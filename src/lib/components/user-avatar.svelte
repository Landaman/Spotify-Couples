<script lang="ts">
	import * as Avatar from '$lib/components/ui/avatar';

	const {
		name,
		picture_url,
		class: className = undefined
	}: { name: string; picture_url: string | null; class?: string | undefined } = $props();

	// Calculate initials to show for the user based on their name
	const usersInitials = $derived.by(() => {
		const usersNameSpaceSplit = name.split(' ');
		if (usersNameSpaceSplit.length == 1) {
			// This can happen if they only have a username e.g., ianwright123
			return (usersNameSpaceSplit[0].charAt(0) + usersNameSpaceSplit[0].charAt(1)).toUpperCase();
		} else {
			return (usersNameSpaceSplit[0].charAt(0) + usersNameSpaceSplit[1].charAt(0)).toUpperCase();
		}
	});
</script>

<Avatar.Root class={className}>
	<Avatar.Fallback>{usersInitials}</Avatar.Fallback>
	<Avatar.Image src={picture_url} alt={name} />
</Avatar.Root>
