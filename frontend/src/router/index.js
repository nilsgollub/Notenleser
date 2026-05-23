import { createRouter, createWebHistory } from 'vue-router'
import LibraryView from '../views/LibraryView.vue'
import ScanView from '../views/ScanView.vue'
import PlayerView from '../views/PlayerView.vue'

export default createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: LibraryView },
    { path: '/scan', component: ScanView },
    { path: '/songs/:id', component: PlayerView, props: true },
  ],
})
