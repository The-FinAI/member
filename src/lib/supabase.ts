import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/public';

const url = env.PUBLIC_SUPABASE_URL ?? '';
const anon = env.PUBLIC_SUPABASE_ANON_KEY ?? '';

// True only when real (non-placeholder) credentials are configured.
export const supabaseConfigured =
  !!url && !!anon && !url.includes('placeholder') && !anon.includes('placeholder');

export const supabase = createClient(
  url || 'https://placeholder.supabase.co',
  anon || 'placeholder-anon-key'
);
