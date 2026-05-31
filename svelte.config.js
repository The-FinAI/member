import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    // Static SPA for GitHub Pages: every route falls back to index.html
    // and is rendered client-side. Supabase (auth + RLS) is the backend.
    adapter: adapter({ fallback: 'index.html' })
  }
};

export default config;
