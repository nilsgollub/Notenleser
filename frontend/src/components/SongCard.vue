<template>
  <div class="song-card card" @click="$router.push(`/songs/${song.id}`)">
    <div class="thumb">
      <img v-if="song.scan_image_path" :src="`/playback/${song.id}/image`" :alt="song.title" loading="lazy" />
      <div v-else class="thumb-placeholder">
        <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
        </svg>
      </div>
    </div>
    <div class="info">
      <h3 class="title">{{ song.title }}</h3>
      <p v-if="song.composer" class="composer">{{ song.composer }}</p>
      <div class="tags">
        <span v-if="song.key_signature" class="badge">{{ song.key_signature }}</span>
        <span v-if="song.time_signature" class="badge">{{ song.time_signature }}</span>
        <span v-if="song.tempo_bpm" class="badge">♩={{ song.tempo_bpm }}</span>
      </div>
      <p class="date">{{ formatDate(song.created_at) }}</p>
    </div>
    <button class="delete-btn" @click.stop="$emit('delete', song.id)" title="Löschen">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>
      </svg>
    </button>
  </div>
</template>

<script setup>
defineProps({ song: Object })
defineEmits(['delete'])

function formatDate(iso) {
  if (!iso) return ''
  return new Date(iso).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' })
}
</script>

<style scoped>
.song-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px;
  cursor: pointer;
  transition: background var(--transition), transform var(--transition);
  position: relative;
}
.song-card:hover { background: var(--bg-card-hover); transform: translateY(-1px); }
.thumb {
  width: 68px;
  height: 68px;
  border-radius: var(--radius-sm);
  overflow: hidden;
  flex-shrink: 0;
  background: var(--bg-input);
}
.thumb img { width: 100%; height: 100%; object-fit: cover; }
.thumb-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
}
.info { flex: 1; min-width: 0; }
.title { font-size: 1rem; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.composer { font-size: 0.85rem; color: var(--text-secondary); margin-top: 2px; }
.tags { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 6px; }
.date { font-size: 0.78rem; color: var(--text-secondary); margin-top: 6px; }
.delete-btn {
  padding: 6px;
  color: var(--text-secondary);
  border-radius: var(--radius-sm);
  transition: color var(--transition), background var(--transition);
}
.delete-btn:hover { color: var(--error); background: rgba(244, 76, 111, 0.1); }
</style>
