import axios, { AxiosError, type AxiosInstance, type InternalAxiosRequestConfig } from 'axios'
import type { ApiResponse } from './types'

export interface HttpHooks {
  accessToken: () => string
  refreshToken: () => string
  updateAccessToken: (token: string) => void
  clearSession: () => void
  onForbidden?: () => void
}

function requestId(): string {
  return crypto.randomUUID().replaceAll('-', '')
}

export function createHttpClient(baseURL: string, hooks: HttpHooks): AxiosInstance {
  const client = axios.create({ baseURL, timeout: 15_000 })
  let refreshing: Promise<string> | null = null

  client.interceptors.request.use((config: InternalAxiosRequestConfig) => {
    config.headers.set('X-Request-Id', requestId())
    const token = hooks.accessToken()
    if (token) config.headers.set('Authorization', `Bearer ${token}`)
    return config
  })

  client.interceptors.response.use(
    response => response,
    async (error: AxiosError<ApiResponse<unknown>>) => {
      const status = error.response?.status
      const original = error.config as (InternalAxiosRequestConfig & { _retried?: boolean }) | undefined
      if (status === 401 && original && !original._retried && hooks.refreshToken()) {
        original._retried = true
        refreshing ??= axios.post<ApiResponse<{ accessToken: string }>>(
          `${baseURL}/api/v1/auth/refresh`,
          { refreshToken: hooks.refreshToken(), deviceId: browserDeviceId() },
          { headers: { 'X-Request-Id': requestId() } },
        ).then(response => {
          hooks.updateAccessToken(response.data.data.accessToken)
          return response.data.data.accessToken
        }).finally(() => { refreshing = null })
        try {
          const token = await refreshing
          original.headers.set('Authorization', `Bearer ${token}`)
          return client(original)
        } catch {
          hooks.clearSession()
        }
      }
      if (status === 401) hooks.clearSession()
      if (status === 403) hooks.onForbidden?.()
      return Promise.reject(error)
    },
  )
  return client
}

export function browserDeviceId(): string {
  const key = 'ygh.device-id'
  const existing = localStorage.getItem(key)
  if (existing) return existing
  const created = crypto.randomUUID()
  localStorage.setItem(key, created)
  return created
}

export function apiData<T>(response: { data: ApiResponse<T> }): T {
  return response.data.data
}
