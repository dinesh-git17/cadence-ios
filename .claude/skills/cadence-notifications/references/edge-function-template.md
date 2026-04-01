# Cadence — Edge Function Template (Period Reminder)

This is the **canonical full implementation** of the period reminder Edge Function.
All other cron-based notification Edge Functions follow this exact structure.
Read this, understand the pattern, then adapt it for ovulation-alert, daily-log-reminder,
period-late, and phase-change. Partner-activity follows the same APNs send logic but
is triggered by a database webhook instead of cron — see the webhook section at the bottom.

---

## File: `supabase/functions/period-reminder/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";

// ─── Environment ────────────────────────────────────────────────────────────
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!; // PEM string
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;     // e.g. "com.cadence.app"
const IS_PRODUCTION = Deno.env.get("APNS_ENVIRONMENT") === "production";

const APNS_HOST = IS_PRODUCTION
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

// ─── APNs JWT (cached for up to 55 minutes) ──────────────────────────────
let cachedJWT: string | null = null;
let jwtCreatedAt = 0;

async function getApnsJWT(): Promise<string> {
  const now = Date.now();
  // APNs JWT is valid for 1 hour — refresh after 55 minutes
  if (cachedJWT && now - jwtCreatedAt < 55 * 60 * 1000) {
    return cachedJWT;
  }

  // Import the ECDSA P-256 key from PEM
  const pemBody = APNS_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const jwt = await create(
    { alg: "ES256", kid: APNS_KEY_ID },
    { iss: APNS_TEAM_ID, iat: getNumericDate(0) },
    cryptoKey
  );

  cachedJWT = jwt;
  jwtCreatedAt = now;
  return jwt;
}

// ─── Send one APNs notification ──────────────────────────────────────────
interface SendResult {
  token: string;
  success: boolean;
  status: number;
  shouldDeleteToken: boolean;
}

async function sendAPNs(
  deviceToken: string,
  payload: Record<string, unknown>
): Promise<SendResult> {
  const jwt = await getApnsJWT();
  const url = `${APNS_HOST}/3/device/${deviceToken}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const status = response.status;
  const shouldDeleteToken = status === 410 || status === 400;

  if (!response.ok && status !== 410) {
    const body = await response.text();
    console.error(`[APNs] ${status} for token ${deviceToken.slice(-8)}: ${body}`);
  }

  return {
    token: deviceToken,
    success: status === 200,
    status,
    shouldDeleteToken,
  };
}

// ─── Handler ─────────────────────────────────────────────────────────────
serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Tomorrow's date in YYYY-MM-DD
  const tomorrow = new Date();
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split("T")[0];

  // ── Query: trackers whose period is predicted to start tomorrow
  //          and who haven't already received this notification today
  const { data: targets, error: queryError } = await supabase
    .from("cycle_profiles")
    .select(`
      user_id,
      predicted_next_period,
      users!inner (
        display_name,
        is_tracker
      ),
      device_tokens!inner (
        token
      ),
      notification_preferences!inner (
        period_reminder
      )
    `)
    .eq("predicted_next_period", tomorrowStr)
    .eq("users.is_tracker", true)
    .eq("notification_preferences.period_reminder", true)
    .not("device_tokens.token", "is", null);

  if (queryError) {
    console.error("[period-reminder] Query error:", queryError);
    return new Response(JSON.stringify({ error: queryError.message }), {
      status: 500,
    });
  }

  if (!targets || targets.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  // ── Deduplication: filter out users already notified today
  const today = new Date().toISOString().split("T")[0];
  const userIds = targets.map((t: any) => t.user_id);

  const { data: alreadySent } = await supabase
    .from("notification_log")
    .select("user_id")
    .in("user_id", userIds)
    .eq("notification_type", "period_reminder")
    .eq("reference_date", tomorrowStr);

  const alreadySentIds = new Set((alreadySent ?? []).map((r: any) => r.user_id));
  const toNotify = (targets as any[]).filter(
    (t) => !alreadySentIds.has(t.user_id)
  );

  if (toNotify.length === 0) {
    return new Response(JSON.stringify({ sent: 0, reason: "all already notified" }), {
      status: 200,
    });
  }

  // ── Build payload
  const buildPayload = () => ({
    aps: {
      alert: {
        title: "Your period is coming tomorrow",
        body: "Heads up — be kind to yourself today.",
      },
      sound: "default",
    },
    data: {
      destination: "today",
      notification_type: "period_reminder",
    },
  });

  // ── Send notifications
  const results = await Promise.allSettled(
    toNotify.map((target: any) =>
      sendAPNs(target.device_tokens.token, buildPayload())
    )
  );

  // ── Post-send: log successes, clean up bad tokens
  const tokensToDelete: string[] = [];
  const logRows: any[] = [];

  results.forEach((result, i) => {
    if (result.status === "fulfilled") {
      const r = result.value;
      if (r.success) {
        logRows.push({
          user_id: toNotify[i].user_id,
          notification_type: "period_reminder",
          reference_date: tomorrowStr,
        });
      }
      if (r.shouldDeleteToken) {
        tokensToDelete.push(r.token);
      }
    }
  });

  // Insert notification log rows (fire and forget)
  if (logRows.length > 0) {
    await supabase.from("notification_log").insert(logRows);
  }

  // Delete invalid tokens (fire and forget)
  if (tokensToDelete.length > 0) {
    await supabase
      .from("device_tokens")
      .delete()
      .in("token", tokensToDelete);
  }

  const successCount = logRows.length;
  console.log(`[period-reminder] Sent ${successCount}/${toNotify.length}`);

  return new Response(
    JSON.stringify({ sent: successCount, total: toNotify.length }),
    { status: 200, headers: { "content-type": "application/json" } }
  );
});
```

---

## Adapting for Other Cron Functions

Copy this file, change:
1. The query filter (what condition selects eligible users)
2. `buildPayload()` — title, body, notification_type, destination
3. `notification_type` string in deduplication query and log insert
4. `reference_date` — what date the dedup key should be (today, predicted date, etc.)

Do **not** change:
- JWT generation logic
- `sendAPNs()` function
- Token deletion on 410/400
- `Promise.allSettled` pattern (never use `Promise.all` — one bad token shouldn't stop the batch)

---

## Partner Activity (Database Webhook Variant)

The partner activity function receives a webhook payload instead of being called on a cron.
It does NOT query a list of users — it receives the specific `shared_logs` row that was
just inserted.

```typescript
// supabase/functions/partner-activity/index.ts  (webhook variant)
serve(async (req) => {
  const body = await req.json();
  const { record } = body; // { tracker_user_id, partner_user_id, log_date }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Fetch both users' tokens, names, and preferences in one query
  const { data: users } = await supabase
    .from("users")
    .select(`
      id, display_name,
      device_tokens ( token ),
      notification_preferences ( partner_activity )
    `)
    .in("id", [record.tracker_user_id, record.partner_user_id]);

  // Dedup: skip if already sent within 30 minutes for this date
  const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000).toISOString();
  const { data: recentLogs } = await supabase
    .from("notification_log")
    .select("user_id")
    .in("user_id", [record.tracker_user_id, record.partner_user_id])
    .eq("notification_type", "partner_activity")
    .eq("reference_date", record.log_date)
    .gte("sent_at", thirtyMinutesAgo);

  const recentIds = new Set((recentLogs ?? []).map((r: any) => r.user_id));

  // Build recipient list — send to each connected user whose pref is true
  // and who wasn't the one who logged (they triggered the insert)
  // For simplicity: send to both, they'll see relevant content on the Partner tab
  const recipients = (users ?? []).filter((u: any) =>
    u.notification_preferences?.partner_activity === true &&
    u.device_tokens?.token &&
    !recentIds.has(u.id)
  );

  // Determine names for copy
  const trackerUser = users?.find((u: any) => u.id === record.tracker_user_id);
  const partnerUser = users?.find((u: any) => u.id === record.partner_user_id);

  await Promise.allSettled(
    recipients.map((u: any) => {
      const isTracker = u.id === record.tracker_user_id;
      // "Your partner logged" from the other person's perspective
      const otherName = isTracker
        ? (partnerUser?.display_name ?? "Your partner")
        : (trackerUser?.display_name ?? "Your partner");

      return sendAPNs(u.device_tokens.token, {
        aps: {
          alert: {
            title: `${otherName} logged their day`,
            body: "Tap to see what they shared with you.",
          },
          sound: "default",
        },
        data: {
          destination: "partner",
          notification_type: "partner_activity",
        },
      });
    })
  );

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
});
```

---

## Local Development

Test Edge Functions locally with the Supabase CLI:

```bash
supabase functions serve period-reminder --env-file .env.local
# In another terminal, invoke it:
curl -i --request POST \
  http://localhost:54321/functions/v1/period-reminder \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"
```

`.env.local` should contain all the `APNS_*` secrets plus `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY`. Never commit this file.

For APNs in development, use the sandbox host. The Xcode scheme (Debug) should
have `aps-environment = development` in the entitlements, and the iOS simulator
**cannot receive remote push notifications** — test on a real device.
