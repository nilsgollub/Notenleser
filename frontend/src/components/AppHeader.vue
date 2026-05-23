<template>
  <header class="header">
    <router-link to="/" class="logo">
      <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
        <rect width="28" height="28" rx="8" fill="var(--primary)" />
        <path d="M8 20V10l12-3v10" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
        <circle cx="8" cy="20" r="2.5" fill="#fff"/>
        <circle cx="20" cy="17" r="2.5" fill="#fff"/>
      </svg>
      <span class="logo-text">Notenleser</span>
    </router-link>
  </header>
</template>

<style scoped>
.header {
  display: flex;
  align-items: center;
  padding: 12px 20px;
  border-bottom: 1px solid var(--border);
  background: var(--bg);
  z-index: 10;
  padding-top: calc(12px + env(safe-area-inset-top));
}
.logo {
  display: flex;
  align-items: center;
  gap: 10px;
}
.logo-text {
  font-size: 1.1rem;
  font-weight: 700;
  letter-spacing: -0.3px;
}
</style>
