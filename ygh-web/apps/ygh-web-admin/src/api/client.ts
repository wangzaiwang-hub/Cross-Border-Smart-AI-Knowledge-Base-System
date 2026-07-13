import { createHttpClient, useSessionStore } from '@ygh/web-shared'
import router from '@/router'

let client: ReturnType<typeof createHttpClient> | undefined

export function useHttp() {
  const session = useSessionStore()
  client ??= createHttpClient(import.meta.env.VITE_GATEWAY_URL || '', {
    accessToken: () => session.bearer,
    refreshToken: () => session.renewal,
    updateTokens: tokens => session.rotate(tokens),
    clearSession: () => session.clear(),
    onForbidden: () => { void router.push('/403') },
  })
  return client
}
