export async function streamSse(
  url: string,
  token: string,
  body: unknown,
  onDelta: (value: string) => void,
  signal?: AbortSignal,
): Promise<void> {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
      'X-Request-Id': crypto.randomUUID().replaceAll('-', ''),
    },
    body: JSON.stringify(body),
    signal,
  })
  if (!response.ok || !response.body) throw new Error(`SSE request failed: ${response.status}`)
  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buffer += decoder.decode(value, { stream: true })
    const events = buffer.split('\n\n')
    buffer = events.pop() ?? ''
    for (const event of events) {
      const data = event.split('\n').find(line => line.startsWith('data:'))?.slice(5).trim()
      if (data && data !== '[DONE]') onDelta(data)
    }
  }
}
