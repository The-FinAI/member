import { writable } from 'svelte/store';

// One global write-feedback channel. Every successful (or failed) write should
// say so — the testers' #1 trust gap was actions that succeeded silently.
export type Toast = {
  id: number;
  kind: 'success' | 'error' | 'info';
  text: string;
  undo?: () => void | Promise<void>;
};

export const toasts = writable<Toast[]>([]);
let seq = 1;

function push(kind: Toast['kind'], text: string, opts?: { undo?: () => void | Promise<void>; ms?: number }) {
  const id = seq++;
  toasts.update((t) => [...t, { id, kind, text, undo: opts?.undo }]);
  const ms = opts?.ms ?? (opts?.undo ? 6000 : kind === 'error' ? 5000 : 3000);
  if (typeof window !== 'undefined') setTimeout(() => dismiss(id), ms);
  return id;
}

export function dismiss(id: number) {
  toasts.update((t) => t.filter((x) => x.id !== id));
}

export const toast = {
  success: (text: string, opts?: { undo?: () => void | Promise<void>; ms?: number }) => push('success', text, opts),
  error: (text: string, opts?: { ms?: number }) => push('error', text, opts),
  info: (text: string, opts?: { ms?: number }) => push('info', text, opts)
};
