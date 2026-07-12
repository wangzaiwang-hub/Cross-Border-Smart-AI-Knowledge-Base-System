import { createHttpClient, useSessionStore } from '@ygh/web-shared'

export function useHttp() {
  const session = useSessionStore()
  return createHttpClient(import.meta.env.VITE_GATEWAY_URL || '', {
    accessToken: () => session.bearer,
    refreshToken: () => session.renewal,
    updateAccessToken: token => session.updateAccessToken(token),
    clearSession: () => session.clear(),
  })
}
