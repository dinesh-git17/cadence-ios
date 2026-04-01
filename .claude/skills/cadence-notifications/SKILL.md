---
name: cadence-notifications
description: >
  Complete implementation guide for the Cadence iOS push notification stack.
  Use this skill whenever implementing, modifying, or debugging any notification
  feature in Cadence — including APNs setup, permission flow, device token
  registration, Supabase Edge Function cron/trigger logic, deep link routing,
  notification preferences, or local notification fallback. Trigger on any
  mention of: push notifications, APNs, UNUserNotificationCenter, Edge Functions
  for notifications, notification preferences, daily reminder, period reminder,
  ovulation alert, partner activity notification, phase change alert, or
  deep linking from a notification tap.
---

# Cadence — Notification Stack Implementation Guide

## Read This First

Before writing any notification code:

1. Read this file completely.
2. If implementing Edge Functions, also read `references/notification-types.md`.
3. If writing the full period-reminder Edge Function as the canonical template, read `references/edge-function-template.md` — then follow the same pattern for all other cron types.

The six notification types and their triggers are defined in `references/notification-types.md`. All Edge Function logic lives there. This file covers the iOS side plus the architectural decisions that govern both sides.

---

## Architecture Overview

```
Cadence Notifications
├── iOS (Swift)
│   ├── Capability: Push Notifications + Background Modes
│   ├── UNUserNotificationCenter — permission + delegate
│   ├── APNs device token → stored in Supabase `device_tokens` table
│   ├── UNUserNotificationCenterDelegate — foreground display + tap routing
│   ├── SwiftUI deep link handler — routes notification taps to correct screen
│   ├── NotificationPreferences model — synced to Supabase on change
│   └── Local notification fallback — daily log reminder only
│
└── Supabase
    ├── Edge Functions (Deno/TypeScript)
    │   ├── 5× cron-based functions (one per scheduled notification type)
    │   └── 1× database trigger function (partner activity)
    ├── `device_tokens` table
    ├── `notification_preferences` table
    └── pg_cron schedules + database webhook trigger
```

**APNs auth method for Cadence: token-based (.p8 key), not certificate-based.**
Token auth is stateless, never expires, works across sandbox and production with a flag change. Use a single `.p8` key per Apple Developer team. Store `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY` (PEM string) as Supabase secrets.

---

## 1. APNs Xcode Setup

### Capabilities (Xcode → Target → Signing & Capabilities)

Add both capabilities. Do not skip Background Modes — silent notifications used for partner activity will not wake the app without it.

| Capability         | Settings                          |
| ------------------ | --------------------------------- |
| Push Notifications | Just add it — no sub-options      |
| Background Modes   | Check "Remote notifications" only |

### Entitlements File

Xcode generates `Cadence.entitlements` automatically. Verify it contains:

```xml
<key>aps-environment</key>
<string>development</string>   <!-- change to "production" for App Store builds -->

<key>com.apple.developer.pushkit.unrestricted-voip</key>
<!-- Do NOT add this — VoIP entitlement is not needed and triggers App Store review scrutiny -->
```

The `aps-environment` value must match your provisioning profile. Mismatch = silent push failures with no error.

### Apple Developer Portal

1. **App ID** → enable Push Notifications capability (creates two certificates in the old model — ignore, you're using token auth).
2. **Keys** → create an APNs key (.p8). Download once — it cannot be re-downloaded.
3. Record `Key ID` (10-char string shown on portal) and your `Team ID` (top-right in portal).
4. Store in Supabase: `supabase secrets set APNS_KEY_ID=... APNS_TEAM_ID=... APNS_PRIVATE_KEY="$(cat AuthKey_XXXXXX.p8)"`

**Never commit the .p8 file to source control.** Add `*.p8` to `.gitignore` immediately.

---

## 2. Permission Request & Device Token Registration

### When to request

Request notification permission at the **last onboarding step only** (Step 6 — Notifications screen), after the user has configured their preferences. Never ask earlier. The iOS permission dialog should appear only after the user has seen the in-app toggle list and opted in to at least one notification type.

### Permission Request

```swift
// NotificationService.swift
import UserNotifications
import UIKit

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAuthorizationStatus()
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            // Log but do not surface to user — they can enable in Settings later
            print("[Notifications] Authorization error: \(error)")
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
}
```

### Device Token Storage

Handle registration in `AppDelegate` (or `@UIApplicationDelegateAdaptor`):

```swift
// AppDelegate.swift
func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    Task { await DeviceTokenService.shared.upsertToken(tokenString) }
}

func application(_ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[APNs] Failed to register: \(error)") // Log only — push is non-critical
}
```

```swift
// DeviceTokenService.swift
final class DeviceTokenService {
    static let shared = DeviceTokenService()
    private let supabase = SupabaseClient.shared

    func upsertToken(_ token: String) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        try? await supabase.database
            .from("device_tokens")
            .upsert(["user_id": userId.uuidString, "token": token,
                     "platform": "ios",
                     "updated_at": ISO8601DateFormatter().string(from: Date())],
                    onConflict: "user_id")
            .execute()
    }
}
```

### Supabase `device_tokens` Table

```sql
create table device_tokens (
  user_id   uuid primary key references users(id) on delete cascade,
  token     text not null,
  platform  text not null default 'ios',
  updated_at timestamptz not null default now()
);
-- RLS: user can only read/write their own row
alter table device_tokens enable row level security;
create policy "own token only" on device_tokens
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

One row per user. On token refresh, upsert replaces the old token. Edge Functions always read the latest token at send time.

---

## 3. Notification Types

**→ See `references/notification-types.md` for the complete specification of all six types**, including payload structures, Edge Function logic, and the `notification_preferences` schema.

Summary:

| Type                   | Trigger                               | Recipient |
| ---------------------- | ------------------------------------- | --------- |
| Period start reminder  | Cron — day before predicted start     | Tracker   |
| Ovulation window alert | Cron — when fertile window opens      | Tracker   |
| Daily log reminder     | Cron — user's configured time         | Tracker   |
| Partner activity       | DB trigger on `shared_logs` INSERT    | Both      |
| Period is late         | Cron — predicted start passed, no log | Tracker   |
| Cycle phase change     | Cron — on phase transition            | Tracker   |

---

## 4. Deep Link Routing

### Notification Payload Convention

Every notification payload includes a `data` dictionary with a `destination` key. This is how the app knows where to route.

| Notification       | `destination` value |
| ------------------ | ------------------- |
| Period reminder    | `today`             |
| Ovulation alert    | `today`             |
| Daily log reminder | `today_log_open`    |
| Partner activity   | `partner`           |
| Period is late     | `today`             |
| Phase change       | `today`             |

### UNUserNotificationCenterDelegate

```swift
// AppDelegate.swift — also conforms to UNUserNotificationCenterDelegate
func application(_ application: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
}

// Show banner + sound even when app is in foreground
func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
}

// Route on tap
func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    if let destination = userInfo["destination"] as? String {
        NotificationCenter.default.post(name: .notificationTapped,
            object: nil, userInfo: ["destination": destination])
    }
    completionHandler()
}

extension Notification.Name {
    static let notificationTapped = Notification.Name("cadence.notificationTapped")
}
```

### AppRouter (SwiftUI Navigation)

```swift
// AppRouter.swift
@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var openLogSheet: Bool = false

    enum AppTab: Int { case today, calendar, partner }

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleNotificationTap(_:)),
            name: .notificationTapped, object: nil)
    }

    @objc private func handleNotificationTap(_ note: Foundation.Notification) {
        guard let destination = note.userInfo?["destination"] as? String else { return }
        route(to: destination)
    }

    func route(to destination: String) {
        switch destination {
        case "today":           selectedTab = .today
        case "today_log_open":
            selectedTab = .today
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openLogSheet = true
            }
        case "partner":         selectedTab = .partner
        default:                selectedTab = .today
        }
    }
}
```

Wire `selectedTab` to your `TabView` selection binding and `openLogSheet` to the log bottom sheet's `isPresented`.

---

## 5. Notification Preferences

### Model

```swift
// NotificationPreferences.swift
struct NotificationPreferences: Codable, Equatable {
    var periodReminder: Bool = true
    var ovulationAlert: Bool = true
    var dailyLogReminder: Bool = true
    var dailyReminderTime: String = "20:00"  // HH:mm, user's local time
    var partnerActivity: Bool = true
    var periodLate: Bool = true
    var phaseChange: Bool = false  // Off by default — high frequency

    enum CodingKeys: String, CodingKey {
        case periodReminder      = "period_reminder"
        case ovulationAlert      = "ovulation_alert"
        case dailyLogReminder    = "daily_log_reminder"
        case dailyReminderTime   = "daily_reminder_time"
        case partnerActivity     = "partner_activity"
        case periodLate          = "period_late"
        case phaseChange         = "phase_change"
    }
}
```

### Supabase Table

```sql
create table notification_preferences (
  user_id              uuid primary key references users(id) on delete cascade,
  period_reminder      boolean not null default true,
  ovulation_alert      boolean not null default true,
  daily_log_reminder   boolean not null default true,
  daily_reminder_time  text    not null default '20:00',
  partner_activity     boolean not null default true,
  period_late          boolean not null default true,
  phase_change         boolean not null default false,
  updated_at           timestamptz not null default now()
);
alter table notification_preferences enable row level security;
create policy "own prefs only" on notification_preferences
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

### Sync on Change

```swift
// NotificationPreferencesService.swift
final class NotificationPreferencesService: ObservableObject {
    static let shared = NotificationPreferencesService()
    @Published var preferences = NotificationPreferences()
    private let supabase = SupabaseClient.shared

    func load() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        if let result: NotificationPreferences = try? await supabase.database
            .from("notification_preferences")
            .select().eq("user_id", value: userId).single()
            .execute().value {
            await MainActor.run { preferences = result }
        }
    }

    func save(_ prefs: NotificationPreferences) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        if (try? await supabase.database
            .from("notification_preferences")
            .upsert(prefs, onConflict: "user_id")
            .execute()) != nil {
            await MainActor.run { preferences = prefs }
        }
    }
}
```

Call `load()` on app launch and after sign-in. Call `save()` whenever a toggle changes in Profile/Settings. The Edge Functions read `notification_preferences` at query time, so changes take effect for the next scheduled run without any additional push or webhook.

---

## 6. Local Notification Fallback (Daily Log Reminder Only)

Use local notifications as a fallback **only for the daily log reminder**, and only when remote notifications are denied but local notifications were previously granted. Check at app launch:

```swift
// LocalReminderService.swift
final class LocalReminderService {
    static let shared = LocalReminderService()
    private let center = UNUserNotificationCenter.current()

    /// Call after preferences are loaded. Schedules or cancels local reminder.
    func syncDailyReminder(prefs: NotificationPreferences) async {
        let settings = await center.notificationSettings()

        // Only use local fallback if remote push is denied
        guard settings.authorizationStatus != .authorized else {
            await cancelLocalReminder()
            return  // Remote push handles it
        }
        guard settings.authorizationStatus == .provisional ||
              settings.alertSetting == .enabled else {
            return  // No permission at all — nothing to do
        }
        guard prefs.dailyLogReminder else {
            await cancelLocalReminder()
            return
        }

        await scheduleLocalReminder(at: prefs.dailyReminderTime)
    }

    private func scheduleLocalReminder(at timeString: String) async {
        await cancelLocalReminder()

        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }

        var components = DateComponents()
        components.hour = parts[0]
        components.minute = parts[1]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        let content = UNMutableNotificationContent()
        content.title = "How are you feeling today?"
        content.body = "Take 20 seconds to log your day."
        content.sound = .default
        content.userInfo = ["destination": "today_log_open"]

        let request = UNNotificationRequest(
            identifier: "cadence.daily_reminder",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func cancelLocalReminder() async {
        center.removePendingNotificationRequests(
            withIdentifiers: ["cadence.daily_reminder"]
        )
    }
}
```

Call `syncDailyReminder(prefs:)` on app launch and whenever the daily reminder toggle or time changes.

---

## Implementation Checklist

Work through this in order — each step unblocks the next.

- [ ] Add Push Notifications capability in Xcode
- [ ] Add Background Modes → Remote notifications
- [ ] Verify `.entitlements` file has `aps-environment`
- [ ] Create APNs key in Apple Developer Portal, store in Supabase secrets
- [ ] Create `device_tokens` table + RLS policy
- [ ] Create `notification_preferences` table + RLS policy
- [ ] Implement `NotificationService.requestAuthorization()` — call from onboarding Step 6
- [ ] Implement `DeviceTokenService.upsertToken()` — call from `AppDelegate`
- [ ] Implement `UNUserNotificationCenterDelegate` in `AppDelegate`
- [ ] Implement `AppRouter` with tab routing + log sheet flag
- [ ] Implement `NotificationPreferencesService` with load/save
- [ ] Implement `LocalReminderService` for daily reminder fallback
- [ ] Deploy all 6 Edge Functions (see `references/notification-types.md`)
- [ ] Configure pg_cron schedules in Supabase Dashboard
- [ ] Configure database webhook trigger for partner activity function
- [ ] TestFlight test: send yourself all 6 notification types before App Store submission

## Reference Files

| File                                   | When to read                                                                                                   |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `references/notification-types.md`     | Before implementing any Edge Function; defines all 6 notification payloads, cron schedules, and function logic |
| `references/edge-function-template.md` | Canonical full TypeScript Edge Function for period reminder; use as the template for all other cron functions  |
