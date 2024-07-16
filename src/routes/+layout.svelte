<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import { SignIn, SignOut } from '@auth/sveltekit/components';
</script>

<div class="w-full h-full flex flex-col gap-1">
	<div class="w-full flex flex-row justify-end pt-1 pr-2">
		{#if $page.data.session}
			<p>Welcome, {$page.data.session.user?.name}</p>
			<img src={$page.data.session.user?.image} alt="User icon" />
			<SignOut signOutPage="signout" />
		{:else}
			<SignIn provider="spotify" signInPage="signin" />
		{/if}
	</div>
	<hr class="mx-1" />
	<slot></slot>
</div>
