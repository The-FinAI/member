import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/public';
import { mockSupabase } from './mock-supabase';

const url = env.PUBLIC_SUPABASE_URL ?? '';
const anon = env.PUBLIC_SUPABASE_ANON_KEY ?? '';

// DEV-ONLY: PUBLIC_MOCK=1 serves a seeded in-memory world for local UI review.
const MOCK = env.PUBLIC_MOCK === '1';

// True only when real (non-placeholder) credentials are configured (or mock on).
export const supabaseConfigured =
  MOCK || (!!url && !!anon && !url.includes('placeholder') && !anon.includes('placeholder'));

export const supabase = MOCK
  ? (mockSupabase as ReturnType<typeof createClient>)
  : createClient(url || 'https://placeholder.supabase.co', anon || 'placeholder-anon-key');
