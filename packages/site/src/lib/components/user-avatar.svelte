<script lang="ts">
	import * as Avatar from '$lib/components/ui/avatar';
	import type { Database } from '$lib/database/schema';

	const {
		profile,
		class: className = undefined
	}: { profile: Database['public']['Tables']['profiles']['Row']; class?: string | undefined } =
		$props();

	// Calculate initials to show for the user based on their name
	const usersInitials = $derived.by(() => {
		const usersNameSpaceSplit = profile.name.split(' ');
		if (!usersNameSpaceSplit || usersNameSpaceSplit.length == 0) {
			return '?'; // This shouldn't really ever happen
		} else if (usersNameSpaceSplit.length == 1) {
			// This can happen if they only have a username e.g., ianwright123
			return (usersNameSpaceSplit[0].charAt(0) + usersNameSpaceSplit[0].charAt(1)).toUpperCase();
		} else {
			return (usersNameSpaceSplit[0].charAt(0) + usersNameSpaceSplit[1].charAt(0)).toUpperCase();
		}
	});
</script>

<Avatar.Root class={className}>
	<Avatar.Fallback>{usersInitials}</Avatar.Fallback>
	<Avatar.Image src={profile.picture_url} alt={profile.name} />
</Avatar.Root>
