import { defineStore } from 'pinia'
import type { SessionUser, TokenPair } from './types'

const SESSION_REFRESH_KEY = 'ygh.refresh-token'
const USER_KEY = 'ygh.session-user'

function readUser(): SessionUser | null {
  try {
    const value = sessionStorage.getItem(USER_KEY)
    return value ? JSON.parse(value) as SessionUser : null
  } catch {
    return null
  }
}

export const useSessionStore = defineStore('session', {
  state: () => ({
    // Access tokens deliberately remain memory-only. A page reload must use the
    // refresh-token flow instead of restoring a bearer token from Web Storage.
    bearer: '',
    renewal: localStorage.getItem(SESSION_REFRESH_KEY) ?? '',
    user: readUser() as SessionUser | null,
  }),
  getters: {
    authenticated: (state) => Boolean(state.bearer && state.user),
    isAdmin: (state) => state.user?.roles.includes('ADMIN') ?? false,
  },
  actions: {
    establish(tokens: TokenPair, user: SessionUser) {
      this.bearer = tokens.accessToken
      this.renewal = tokens.refreshToken
      this.user = user
      localStorage.setItem(SESSION_REFRESH_KEY, tokens.refreshToken)
      sessionStorage.setItem(USER_KEY, JSON.stringify(user))
    },
    updateAccessToken(accessToken: string) {
      this.bearer = accessToken
    },
    clear() {
      this.bearer = ''
      this.renewal = ''
      this.user = null
      sessionStorage.removeItem(USER_KEY)
      localStorage.removeItem(SESSION_REFRESH_KEY)
    },
    can(permission: string) {
      return this.isAdmin || Boolean(this.user?.permissions.includes(permission))
    },
  },
})
