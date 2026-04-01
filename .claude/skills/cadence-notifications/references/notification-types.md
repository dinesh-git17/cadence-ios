# Cadence — Notification Types Reference

All six notification types, their payloads, trigger mechanisms, and Edge Function
patterns. Read this before writing any Supabase Edge Function for Cadence notifications.

---

## Supabase `notification_preferences` Query Pattern

Every cron Edge Function must check preferences before sending. The standard
join pattern (used by all cron functions):

```sql
-- Pseudocode for all cron functions
SELECT
  u.id,
  u.display_name,
  dt.token,
  np.{relevant_pref}
FROM users u
JOIN device_tokens dt ON dt.user_id = u.id
JOIN notification_preferences np ON np.user_id = u.id
WHERE u.is_tracker = true
  AND np.{relevant_pref} = true
  AND dt.token IS NOT NULL
```

Never send to a user whose preference is false. Never send to a user with no device token.

---

## APNs Payload Structure

All notifications follow this shape. The `data` dict is always present for deep linking.

```typescript
interface APNsPayload {
  aps: {
    alert: {
      title: string;
      body: string;
    };
    sound: "default";
    "content-available"?: 1;  // only for silent background updates
  };
  data: {
    destination: string;      // routing key — see SKILL.md §4
    notification_type: string; // for analytics/debugging
    [key: string]: string;    // type-specific extras
  };
}
```

---

## Notification Type Specifications

### 1. Period Start Reminder

**Trigger:** Cron, runs daily at 09:00 UTC. Fires the day before predicted period start.
**Recipient:** Tracker only.
**Preference key:** `period_reminder`

```typescript
// Payload
{
  aps: {
    alert: {
      title: "Your period is coming tomorrow",
      body: "Heads up — be kind to yourself today."
    },
    sound: "default"
  },
  data: {
    destination: "today",
    notification_type: "period_reminder"
  }
}
```

```typescript
// Edge Function query logic (Supabase SQL via supabase-js)
const tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
const tomorrowStr = tomorrow.toISOString().split("T")[0]; // YYYY-MM-DD

const { data: users } = await supabase
  .from("cycle_profiles")
  .select(`
    user_id,
    users!inner(display_name),
    device_tokens!inner(token),
    notification_preferences!inner(period_reminder)
  `)
  .eq("notification_preferences.period_reminder", true)
  .not("device_tokens.token", "is", null);

// Filter in JS: only users whose predicted_next_period == tomorrowStr
// predicted_next_period is computed, not stored — recompute from cycle_profiles
// or store a denormalised `predicted_next_period` column updated on each log save
```

**Implementation note:** Store a denormalised `predicted_next_period` date on `cycle_profiles`, updated every time a new log is saved. This makes cron queries trivial. Recomputing on every cron run is expensive and fragile.

---

### 2. Ovulation Window Alert

**Trigger:** Cron, runs daily at 09:00 UTC. Fires when today is the first day of the fertile window.
**Recipient:** Tracker only.
**Preference key:** `ovulation_alert`

```typescript
// Payload
{
  aps: {
    alert: {
      title: "Your fertile window is open",
      body: "You're entering your most fertile days."
    },
    sound: "default"
  },
  data: {
    destination: "today",
    notification_type: "ovulation_alert"
  }
}
```

**Query logic:** Same join pattern as period reminder. Filter where `fertile_window_start` on `cycle_profiles` equals today. Store `fertile_window_start` as a denormalised column, same reasoning as above.

---

### 3. Daily Log Reminder

**Trigger:** Cron, per-user scheduled time. Runs every hour on the :00 mark, queries users whose `daily_reminder_time` matches the current hour in their timezone.
**Recipient:** Tracker only.
**Preference key:** `daily_log_reminder`, `daily_reminder_time`

```typescript
// Payload
{
  aps: {
    alert: {
      title: "How are you feeling today?",
      body: "Take 20 seconds to log your day."
    },
    sound: "default"
  },
  data: {
    destination: "today_log_open",
    notification_type: "daily_log_reminder"
  }
}
```

```typescript
// Edge Function query — called every hour
const nowUTC = new Date();
const currentHourUTC = nowUTC.getUTCHours();
const currentMinuteUTC = nowUTC.getUTCMinutes();

// daily_reminder_time is stored as "HH:mm" in the user's LOCAL time.
// For MVP: store it as UTC offset time and send at the correct UTC hour.
// The iOS app converts the user's local picker time to UTC before saving.
// Filter: np.daily_reminder_time matches current UTC HH:mm window.

const timeWindow = `${String(currentHourUTC).padStart(2,"0")}:00`;

const { data: users } = await supabase
  .from("notification_preferences")
  .select(`
    user_id,
    daily_reminder_time,
    device_tokens!inner(token),
    users!inner(is_tracker)
  `)
  .eq("daily_log_reminder", true)
  .eq("daily_reminder_time", timeWindow)  // UTC HH:00
  .eq("users.is_tracker", true)
  .not("device_tokens.token", "is", null);

// Additionally filter: skip users who have already logged today
// by left-joining cycle_logs and excluding rows with log_date = today
```

**iOS note:** When the user selects a reminder time in Profile/Settings, convert
to UTC before saving: `dailyReminderTime = convertLocalTimeToUTC(pickerTime)`.
Display the local time back from UTC when rendering the setting.

---

### 4. Partner Activity

**Trigger:** Database trigger on `shared_logs` INSERT. Not a cron.
**Recipient:** Both the tracker (when partner logs) and the partner (when tracker logs).
**Preference key:** `partner_activity`

```typescript
// Payload sent to tracker (partner has logged)
{
  aps: {
    alert: {
      title: "[Partner name] logged their day",
      body: "Tap to see what they shared with you."
    },
    sound: "default"
  },
  data: {
    destination: "partner",
    notification_type: "partner_activity"
  }
}

// Payload sent to partner (tracker has logged)
{
  aps: {
    alert: {
      title: "[Tracker name] logged their day",
      body: "See what's been shared with you."
    },
    sound: "default"
  },
  data: {
    destination: "partner",
    notification_type: "partner_activity"
  }
}
```

```typescript
// Database webhook setup (Supabase Dashboard → Database → Webhooks)
// Table: shared_logs | Event: INSERT | Method: POST to Edge Function URL
// The webhook body contains the new row as `record`

// Edge Function receives:
interface WebhookPayload {
  type: "INSERT";
  table: "shared_logs";
  record: {
    tracker_user_id: string;
    partner_user_id: string;
    log_date: string;
  };
}

// Lookup both users' tokens + names + preferences, send to each
// if their partner_activity preference is true
```

**Important:** The partner activity function fires on every `shared_logs` insert.
Add deduplication: do not fire if another notification for the same user + date
was sent within the last 30 minutes. Use a simple `notification_log` table with
`(user_id, notification_type, sent_at)` to check recency.

---

### 5. Period Is Late

**Trigger:** Cron, runs daily at 09:00 UTC. Fires when predicted period start date has passed with no period log.
**Recipient:** Tracker only.
**Preference key:** `period_late`
**Frequency guard:** Fire once, then suppress until user logs a period. Do not re-fire daily.

```typescript
// Payload
{
  aps: {
    alert: {
      title: "Your period hasn't started yet",
      body: "Cycles vary — log when it arrives and we'll adjust."
    },
    sound: "default"
  },
  data: {
    destination: "today",
    notification_type: "period_late"
  }
}
```

```typescript
// Query logic
// Find trackers where:
//   predicted_next_period < today (it was due in the past)
//   AND no cycle_log row with period_flow != 'none' exists for any date >= predicted_next_period
//   AND no period_late notification was already sent for this predicted date
//      (check notification_log table)
```

---

### 6. Cycle Phase Change

**Trigger:** Cron, runs daily at 08:00 UTC. Fires when today is the first day of a new phase.
**Recipient:** Tracker only.
**Preference key:** `phase_change`
**Default:** `false` — off by default, opt-in only (high frequency, can feel spammy).

```typescript
// Payload — body varies by phase
const phaseMessages: Record<string, { title: string; body: string }> = {
  menstrual:   { title: "Your period has started",         body: "Day 1. Rest up — you've got this." },
  follicular:  { title: "You're in your follicular phase", body: "Energy tends to build during this phase." },
  ovulation:   { title: "You're entering your fertile window", body: "Your most energetic days are ahead." },
  luteal:      { title: "You're in your luteal phase",     body: "Energy may shift — be patient with yourself." },
};

{
  aps: {
    alert: {
      title: phaseMessages[phase].title,
      body: phaseMessages[phase].body
    },
    sound: "default"
  },
  data: {
    destination: "today",
    notification_type: "phase_change",
    phase: phase  // "menstrual" | "follicular" | "ovulation" | "luteal"
  }
}
```

---

## Cron Schedule Summary (pg_cron)

Configure in Supabase Dashboard → Database → Extensions → pg_cron,
or via `supabase/config.toml` in the local dev setup.

```sql
-- Period reminder: daily at 09:00 UTC
select cron.schedule('period-reminder', '0 9 * * *',
  $$select net.http_post(url:='https://<project>.supabase.co/functions/v1/period-reminder',
    headers:='{"Authorization": "Bearer <service_role_key>"}'::jsonb) as request_id$$);

-- Ovulation alert: daily at 09:00 UTC
select cron.schedule('ovulation-alert', '0 9 * * *',
  $$select net.http_post(url:='https://<project>.supabase.co/functions/v1/ovulation-alert',
    headers:='{"Authorization": "Bearer <service_role_key>"}'::jsonb) as request_id$$);

-- Daily log reminder: every hour
select cron.schedule('daily-log-reminder', '0 * * * *',
  $$select net.http_post(url:='https://<project>.supabase.co/functions/v1/daily-log-reminder',
    headers:='{"Authorization": "Bearer <service_role_key>"}'::jsonb) as request_id$$);

-- Period late: daily at 09:00 UTC
select cron.schedule('period-late', '0 9 * * *',
  $$select net.http_post(url:='https://<project>.supabase.co/functions/v1/period-late',
    headers:='{"Authorization": "Bearer <service_role_key>"}'::jsonb) as request_id$$);

-- Phase change: daily at 08:00 UTC (slightly before others)
select cron.schedule('phase-change', '0 8 * * *',
  $$select net.http_post(url:='https://<project>.supabase.co/functions/v1/phase-change',
    headers:='{"Authorization": "Bearer <service_role_key>"}'::jsonb) as request_id$$);
```

Partner activity uses a database webhook trigger, not pg_cron. Configure in
Supabase Dashboard → Database → Webhooks → Create webhook →
Table: `shared_logs`, Events: `INSERT`, Target: Edge Function URL.

---

## `notification_log` Table (Deduplication)

```sql
create table notification_log (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references users(id) on delete cascade,
  notification_type text not null,
  reference_date    date,       -- the cycle date this notification is about
  sent_at           timestamptz not null default now()
);
create index on notification_log (user_id, notification_type, reference_date);
-- No RLS needed — Edge Functions use service_role key
```

Before sending any notification, check this table. Insert a row after a successful send.
For `period_late`: check if a row exists with `notification_type = 'period_late'` and
`reference_date = predicted_next_period`. If yes, skip.

---

## Token Cleanup

Invalid/expired tokens return HTTP 410 (Gone) from APNs. On 410, delete the token from `device_tokens`:

```typescript
if (apnsResponse.status === 410) {
  await supabase.from("device_tokens").delete().eq("token", token);
}
// 400 = bad token format → also delete
// 429 = rate limited → back off, retry next cron run
// 5xx = APNs error → log, do not delete token
```
