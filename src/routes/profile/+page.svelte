<script lang="ts">
  import { goto } from '$app/navigation';
  import { member, authReady, session } from '$lib/session';
  import { t } from '$lib/i18n';

  // Profile is now your own member page — one canonical self-view (identity +
  // badges + resources), the same body the community drawer and /members/[id]
  // use. Redirect there once we know who you are.
  $effect(() => {
    if ($member) goto(`/members/${$member.id}`, { replaceState: true });
  });
</script>

<div class="stack" style="padding:2rem 0;">
  {#if $member}
    <p class="muted">{$t('Taking you to your profile…')}</p>
  {:else if $authReady && $session}
    <p class="muted">
      {$t("You're signed in but not linked to a membership yet.")}
      <a href="/guide">{$t('read how the community works →')}</a>
    </p>
  {:else}
    <p class="muted">{$t('Loading…')}</p>
  {/if}
</div>
