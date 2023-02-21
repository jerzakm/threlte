<script>
	import { onMount } from 'svelte';
	import App from './App.svelte';

	let mounted = false;
	onMount(() => {
		mounted = true;
	});
</script>

<div class="w-screen h-screen fixed" id="container">
	{#if mounted}
		<App />
	{/if}
</div>
