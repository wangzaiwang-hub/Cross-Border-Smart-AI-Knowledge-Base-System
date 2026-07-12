import { defineStore } from 'pinia'
import type { SessionUser, TokenPair } from './types'

const SESSION_ACCESS_KEY = 'ygh.access-token'
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
    bearer: sessionStorage.getItem(SESSION_ACCESS_KEY) ?? '',
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
      sessionStorage.setItem(SESSION_ACCESS_KEY, tokens.accessToken)
      localStorage.setItem(SESSION_REFRESH_KEY, tokens.refreshToken)
      sessionStorage.setItem(USER_KEY, JSON.stringify(user))
    },
    updateAccessToken(accessToken: string) {
      this.bearer = accessToken
      sessionStorage.setItem(SESSION_ACCESS_KEY, accessToken)
    },
    clear() {
      this.bearer = ''
      this.renewal = ''
      this.user = null
      sessionStorage.removeItem(SESSION_ACCESS_KEY)
      sessionStorage.removeItem(USER_KEY)
      localStorage.removeItem(SESSION_REFRESH_KEY)
    },
    can(permission: string) {
      return this.isAdmin || Boolean(this.user?.permissions.includes(permission))
    },
  },
})
