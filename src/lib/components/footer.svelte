<script>
	import { Separator } from '$lib/components/ui/separator';
	import GitHub from '$lib/assets/github.svelte';

	const date = new Date(); // Date to get year from
</script>

<div class="flex flex-col gap-2 pb-5">
	<Separator />

	<footer class="flex w-full flex-col gap-2 px-4 text-xs opacity-60 md:px-8">
		<div class="flex w-full flex-row justify-between">
			<p>&copy; {date.getFullYear()} Ian Wright</p>

			<div class="flex flex-row items-center">
				<a href="https://github.com"><GitHub class="mr-2 h-4 w-4 dark:invert" /></a>View Source
				on&nbsp;
				<a href="https://github.com/landaman/spotify-couples" class="font-semibold underline"
					>GitHub</a
				>
			</div>
		</div>

		<div class="flex flex-col">
			<p class="font-bold">Disclaimer:</p>
			<p>
				&emsp;&emsp;This website is <span class="font-extrabold"
					>not affiliated with or endorsed by Spotify</span
				>
				in any way. The Spotify logo and all Spotify content is copyright and owned by Spotify. This
				is simply a gift for my very special girlfriend. In fact, you can't log in unless you're her
				or me. If you want to use this for yourself, follow the instructions in the
				<a
					href="https://github.com/Landaman/Spotify-Couples/blob/main/README.md"
					class="font-semibold underline">readme</a
				>.
			</p>
		</div>
	</footer>
</div>
