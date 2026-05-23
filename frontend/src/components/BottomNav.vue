<template>
  <nav class="bottom-nav">
    <router-link to="/" class="nav-item" :class="{ active: route.path === '/' }">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
        <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
      </svg>
      <span>Bibliothek</span>
    </router-link>
    <router-link to="/scan" class="nav-item scan-btn">
      <div class="scan-circle">
        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
          <circle cx="12" cy="13" r="4"/>
        </svg>
      </div>
      <span>Scan</span>
    </router-link>
  </nav>
</template>

<script setup>
import { useRoute } from 'vue-router'
const route = useRoute()
</script>

<style scoped>
.bottom-nav {
  display: flex;
  justify-content: space-around;
  align-items: center;
  border-top: 1px solid var(--border);
  background: var(--bg);
  padding: 8px 0;
  padding-bottom: calc(8px + env(safe-area-inset-bottom));
}
.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 6px 20px;
  font-size: 0.72rem;
  font-weight: 500;
  color: var(--text-secondary);
  transition: color var(--transition);
}
.nav-item.active, .nav-item:hover { color: var(--primary); }
.scan-btn { color: var(--text-secondary); }
.scan-circle {
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: var(--primary);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  margin-top: -28px;
  box-shadow: 0 4px 16px rgba(124, 111, 247, 0.5);
  transition: transform var(--transition);
}
.scan-btn:hover .scan-circle { transform: scale(1.06); }
</style>
