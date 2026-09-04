import { createClient } from 'npm:@supabase/supabase-js@2.57.4'

type NotificationJob = {
  id: number
  ticket_id: string
  kind: 'table_ready' | 'grace_warning'
  state: string
}

type WebhookPayload = {
  type: 'INSERT'
  table: 'notification_jobs'
  schema: 'public'
  record: NotificationJob
}

type ServiceAccount = {
  client_email: string
  private_key: string
  project_id: string
  token_uri?: string
}

Deno.serve(async (request) => {
  if (request.method === 'GET') {
    return Response.json({ ok: true, service: 'dispatch-notification' })
  }
  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405 })
  }

  const expectedSecret = Deno.env.get('QUEUELESS_WEBHOOK_SECRET')
  if (!expectedSecret || request.headers.get('x-queueless-secret') !== expectedSecret) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 })
  }

  let jobId: number | null = null
  try {
    const payload = await request.json() as WebhookPayload
    const job = payload.record
    jobId = job?.id ?? null
    if (!job?.id || !job.ticket_id || job.state !== 'pending') {
      return Response.json({ error: 'Invalid notification job' }, { status: 400 })
    }

    const supabaseUrl = requiredEnv('SUPABASE_URL')
    const secretKey = supabaseSecretKey()
    const supabase = createClient(supabaseUrl, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const { data: claimed, error: claimError } = await supabase
      .from('notification_jobs')
      .update({ state: 'sending', attempts: job.id ? 1 : 0 })
      .eq('id', job.id)
      .eq('state', 'pending')
      .select('id')
      .maybeSingle()
    if (claimError) throw claimError
    if (!claimed) return Response.json({ ok: true, duplicate: true })

    const { data: ticket, error: ticketError } = await supabase
      .from('tickets')
      .select('id,owner_id,guest_name,status')
      .eq('id', job.ticket_id)
      .single()
    if (ticketError) throw ticketError

    const { data: installations, error: installationError } = await supabase
      .from('device_installations')
      .select('id,fcm_token')
      .eq('owner_id', ticket.owner_id)
    if (installationError) throw installationError
    if (!installations?.length) {
      throw new Error('No notification-enabled device for this customer')
    }

    const serviceAccount = JSON.parse(
      requiredEnv('FIREBASE_SERVICE_ACCOUNT_JSON'),
    ) as ServiceAccount
    const accessToken = await createGoogleAccessToken(serviceAccount)
    const copy = notificationCopy(job.kind, ticket.guest_name)

    const deliveries = await Promise.all(installations.map(async (installation) => {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${accessToken}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: installation.fcm_token,
              notification: copy,
              data: {
                kind: job.kind,
                ticket_id: ticket.id,
                status: ticket.status,
              },
              android: { priority: 'high' },
            },
          }),
        },
      )
      const body = await response.text()
      return { ok: response.ok, status: response.status, body }
    }))

    const successes = deliveries.filter((delivery) => delivery.ok).length
    if (successes === 0) {
      throw new Error(`FCM rejected every delivery: ${JSON.stringify(deliveries)}`)
    }

    await supabase
      .from('notification_jobs')
      .update({ state: 'sent', sent_at: new Date().toISOString(), error_message: null })
      .eq('id', job.id)
    return Response.json({ ok: true, delivered: successes })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    try {
      const supabase = createClient(requiredEnv('SUPABASE_URL'), supabaseSecretKey())
      if (jobId) {
        await supabase
          .from('notification_jobs')
          .update({ state: 'failed', error_message: message.slice(0, 1000) })
          .eq('id', jobId)
      }
    } catch (_) {
      // Preserve the original failure when error reporting is unavailable.
    }
    return Response.json({ error: message }, { status: 500 })
  }
})

function notificationCopy(kind: NotificationJob['kind'], guestName: string) {
  if (kind === 'grace_warning') {
    return {
      title: 'Your table is waiting',
      body: `${guestName}, please check in soon to keep your table.`,
    }
  }
  return {
    title: 'Your table is ready',
    body: `${guestName}, open QueueLess and show your arrival QR.`,
  }
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`Missing ${name}`)
  return value
}

function supabaseSecretKey(): string {
  const current = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (current) return JSON.parse(current).default
  return requiredEnv('SUPABASE_SERVICE_ROLE_KEY')
}

async function createGoogleAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = encodeJson({ alg: 'RS256', typ: 'JWT' })
  const claims = encodeJson({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: account.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })
  const unsigned = `${header}.${claims}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`
  const response = await fetch(account.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })
  const body = await response.json()
  if (!response.ok || !body.access_token) {
    throw new Error(`Google OAuth failed: ${JSON.stringify(body)}`)
  }
  return body.access_token
}

function encodeJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)))
}

function base64Url(bytes: Uint8Array): string {
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '')
}

function pemToBytes(pem: string): Uint8Array {
  const encoded = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replaceAll(/\s/g, '')
  return Uint8Array.from(atob(encoded), (character) => character.charCodeAt(0))
}
