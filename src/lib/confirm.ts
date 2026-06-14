import { writable } from 'svelte/store';

// Global confirm gate for consequential / irreversible actions. The testers
// asked (issues #35/#33/#34) that state-changing admin actions — status
// changes, role assignments, ownership/team changes, settlement — ask before
// committing rather than firing on a single click. Low-stakes, reversible edits
// (toggling a task) stay frictionless and do NOT use this.
//
// Usage:  if (!(await confirm({ title: 'Change status to Finished?', tone: 'danger' }))) return;

export type ConfirmTone = 'default' | 'danger';
export type ConfirmRequest = {
  id: number;
  title: string;
  body?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: ConfirmTone;
  resolve: (ok: boolean) => void;
};

export const confirmRequest = writable<ConfirmRequest | null>(null);
let seq = 1;

export function confirm(opts: {
  title: string; body?: string; confirmLabel?: string; cancelLabel?: string; tone?: ConfirmTone;
}): Promise<boolean> {
  // SSR / no window: don't block, treat as cancelled.
  if (typeof window === 'undefined') return Promise.resolve(false);
  return new Promise<boolean>((resolve) => {
    confirmRequest.set({ id: seq++, ...opts, resolve });
  });
}

export function resolveConfirm(ok: boolean) {
  confirmRequest.update((r) => { r?.resolve(ok); return null; });
}
