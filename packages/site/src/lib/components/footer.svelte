<script>
	import { Separator } from '$lib/components/ui/separator';
	import GitHub from '$lib/assets/github.svelte';

	const date = new Date(); // Date to get year from
</script>

<div class="bg-background flex flex-col">
	<Separator />

	<footer class="flex w-full flex-col gap-5 px-4 py-5 md:px-8">
		<div class="flex flex-row items-center gap-2">
			<enhanced:img
				src="$lib/assets/logo.png"
				alt="Spotify Couples"
				sizes="32px,32px"
				class="h-8 w-8"
			/>
			<h1 class="text-lg font-semibold tracking-wide">Spotify Couples</h1>
		</div>

		<div class="flex flex-col text-sm">
			<p class="font-semibold opacity-65">Disclaimer</p>
			<p class="opacity-50">
				This website is <span class="font-extrabold"
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

		<div class="flex flex-col gap-2">
			<p class="text-xs opacity-50">&copy; {date.getFullYear()} Ian Wright</p>
			<a href="https://github.com/Landaman/Spotify-Couples" class="w-min">
				<GitHub class="pointer-events-none h-6 w-6 opacity-65 md:h-6 md:w-6 dark:invert" />
			</a>
		</div>
	</footer>
</div>
