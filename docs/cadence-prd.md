# Cadence — Product Requirements Document
**Version:** 1.0  
**Status:** Ready for implementation  
**Platform:** iOS only  
**Date:** March 31, 2026

---

## 1. Summary

Cadence is a cycle tracking app for couples. It lets one or both partners track their menstrual cycle — logging periods, symptoms, mood, energy, sex, sleep, and notes — and share selected data with their partner in a dedicated, consent-first partner view. The partner experience is a first-class citizen of the app, not an afterthought.

The core differentiator is the sharing model: users explicitly choose what their partner can see, the partner gets a dedicated experience with cycle phase explanations in plain language, and no health data is shared by default. Cadence is designed to be inclusive — it does not ask for gender, only whether each user tracks a cycle.

---

## 2. Background & Problem Statement

Period tracking apps like Flo and Clue are built for solo users. The sharing features they offer are minimal, buried, and not designed for a couple's dynamic. Partners — regardless of whether they track a cycle themselves — have no good tool for staying in tune with their partner's cycle in a warm, respectful, and informed way.

The result: couples either don't share this information at all, or they screenshot and text manually. Neither is a product. Cadence fills this gap with a purpose-built shared experience.

---

## 3. Goals

- Ship a polished, complete MVP for iOS with a tracker experience, a partner experience, and a working connection model
- Deliver a prediction engine that is useful from day one via onboarding seed data
- Implement a privacy-first data architecture that users can trust with sensitive health data
- Establish a brand identity that is warm, modern, and inclusive — not clinical, not gendered

---

## 4. Non-Goals (MVP)

- Android support
- Dark mode
- Medications, BBT, weight, or cervical mucus tracking
- ML-based or symptom-correlated predictions
- Fertility scoring
- Multiple partner connections
- Email notifications
- In-app notification history
- Data export
- Delete account flow
- Subscription or monetisation
- Field-level sharing granularity (only category-level for MVP)

---

## 5. Target Users

**Primary user — the tracker:** Someone who menstruates and wants to track their cycle, understand their body, and optionally share relevant data with a partner. Does not assume any gender.

**Secondary user — the partner:** Someone in a relationship with a tracker. May or may not track their own cycle. Wants to stay informed about their partner's cycle in a way that is easy to understand and feels intimate rather than clinical.

**Both-tracker scenario:** Both people in the couple track their own cycles. Each gets the full tracker experience. Each controls independently what they share with the other. Fully symmetric.

---

## 6. Brand & Design System

### 6.1 Colour Palette

| Role | Token | Hex |
|---|---|---|
| Primary | Coral Pink | `#F88379` |
| Primary dark / pressed | Watermelon Pink | `#E37383` |
| Primary light (tags, chips) | Pink Tint | `#FDDBD8` |
| Primary faint (hover states) | Pink Faint | `#FEF2F1` |
| App background | Base White | `#FFFFFF` |
| Cards, sheets | Warm White | `#FEF9F8` |
| Grouped sections | Tinted Surface | `#FEF6F5` |
| Primary text | — | `#1A0F0E` |
| Secondary text | — | `#7A5250` |
| Tertiary text / hints | — | `#B89490` |
| Default border | — | `#F2DDD8` |
| Strong border | — | `#E8C8C4` |
| Success | — | `#4CAF7D` |
| Warning | — | `#F5A623` |
| Error | — | `#E74C3C` |

No dark mode for MVP. Light mode only.

### 6.2 Typography

| Role | Font | Weight | Usage |
|---|---|---|---|
| Heading / Display | Playfair Display (Google Fonts) | 400 regular, italic | Screen titles, section headers, date displays, key callouts |
| Body / UI | DM Sans (Google Fonts) | 400 regular, 500 medium | All body copy, labels, captions, navigation, buttons, form elements |

### 6.3 Icon System

- **Library:** Phosphor Icons — PhosphorSwift Swift package
- **Weight:** Regular (2px stroke, rounded caps)
- **Active state:** Coral Pink `#F88379`
- **Inactive state:** Tertiary text `#B89490`
- **Icon background tint (list rows):** Pink Tint `#FDDBD8`, border-radius 8–10px

### 6.4 App Store

- **Category:** Health & Fitness
- **Monetisation:** Free (MVP)

---

## 7. Technical Stack

| Layer | Decision |
|---|---|
| Platform | iOS (SwiftUI) |
| Backend / Database | Supabase |
| Auth | Sign in with Apple, Email |
| Push notifications | Supabase Edge Functions + APNs |
| Encryption | AES-GCM via CryptoKit (client-side, on-device) |
| Hosting region | US (us-east-1) |

---

## 8. User Role Model

Cadence does not ask for gender. Role is determined by a single onboarding question:

> **"Will you be tracking your own cycle?"**
> - Yes, I track my cycle → Tracker experience
> - No, I'm a partner → Partner experience

| User A | User B | Result |
|---|---|---|
| Tracks cycle | Doesn't track | Classic tracker + partner view |
| Tracks cycle | Tracks cycle | Both get full tracker UX, see each other's shared data |
| Doesn't track | Doesn't track | Both get partner view (edge case, allowed) |

Gender and pronouns are optional profile fields only. Never required. Never used for access control.

---

## 9. Navigation Structure

### Tracker (3 tabs)

| Tab | Contents |
|---|---|
| Today | Cycle day, phase summary, log entry, mood + symptoms, partner card |
| Calendar | Monthly grid, phase visualisation, day detail, insights section |
| Partner | Partner's data, sharing controls, connection management |

### Partner / non-tracker (3 tabs)

| Tab | Contents |
|---|---|
| Partner | Partner's cycle day, phase explanation, shared data |
| Calendar | Upcoming phases, shared events |
| Profile | Settings, sharing preferences |

**Profile / Settings:** No dedicated tab. Accessed via avatar/initials icon in the top-right navigation bar. Modal sheet, dismissed via "Done."

---

## 10. Core Features

### 10.1 Logging

All log types available from the Today screen via a bottom sheet. Target: complete log in under 20 seconds with no typing required.

| Log Type | UI Pattern | Shareable |
|---|---|---|
| Period (flow + dates) | 5-button row: None · Spotting · Light · Medium · Heavy | Yes |
| Symptoms | Multi-select chips (preset list + "more") | Yes |
| Mood | Multi-select chips | Yes |
| Energy level | 3-button row: Low · Medium · High | Yes |
| Sex / intimacy | Toggle (protected/unprotected optional) | No — always private |
| Sleep quality | 3-button row: Poor · Okay · Good | No — always private |
| Notes | Free text input | No — always private |

**Preset symptom list:** Cramps, headache, bloating, backache, tender breasts, nausea, acne + custom entry.

**Preset mood list:** Happy, calm, anxious, irritable, sad, energetic, tired.

**Log editing:** Users may edit any previously logged day to correct errors. Accessed by tapping a past day on the Calendar screen → summary card → Edit button → full log sheet pre-populated with existing data.

**Out of scope for MVP:** Medications / supplements, weight, temperature (BBT), cervical mucus.

### 10.2 Cycle Prediction Engine

Predictions are a core MVP feature — available from day one via onboarding seed data.

**Algorithm:** Weighted rolling average. Recent cycles are weighted more heavily than older ones. Approximately 50 lines of Swift for the core algorithm; edge case handling is where the real implementation effort lives.

**What is predicted:**
- Next period start date
- Cycle phases: menstrual, follicular, ovulation window, luteal
- Fertile window

**Phase calculation defaults:**

| Phase | Calculation |
|---|---|
| Menstrual | Day 1 through end of logged period duration |
| Follicular | End of period through start of ovulation window |
| Ovulation window | Days 11–17 (adjusted by average cycle length) |
| Luteal | Ovulation end through predicted next period start |

**Cold start:** Onboarding collects last period date, estimated cycle length (default 28 days), and estimated period duration (default 5 days). Predictions are seeded from day one.

**Edge case rules:**

| Scenario | Handling |
|---|---|
| New period logged within 14 days of previous period start | Treated as spotting or continuation — not a new cycle |
| No period logged for > 60 days | Predictions flagged as low confidence, user prompted to confirm last period date |
| Seed data only (0 completed cycles) | All predictions shown with "Estimated" label |
| 1–2 completed cycles | Low-confidence indicator on predictions |
| 3+ completed cycles | Full confidence display, no indicator |

### 10.3 Partner Sharing

**Granularity:** Category-level. Users toggle entire log types on or off. No field-level granularity for MVP.

**Shareable categories (user opt-in, nothing shared by default):**

| Category | Default |
|---|---|
| Period (flow + dates) | Off |
| Symptoms | Off |
| Mood | Off |
| Energy level | Off |

**Always private — not shareable:**

| Category | Reason |
|---|---|
| Sex / intimacy | Sensitive — privacy by design |
| Sleep quality | Personal data, low partner value |
| Notes | Free text — always private, no exceptions |

**Sharing default:** Nothing shared by default. Consent is explicit, not passive. Users opt in during onboarding step 4 or at any time via Partner tab or Profile settings.

**Both-tracker scenario:** Each user manages their own sharing settings independently. A shares period with B, B shares nothing with A — fully asymmetric, fully valid.

### 10.4 Partner Connection Model

**Method:** Invite link via iOS share sheet. No custom email infrastructure required.

**Flow:**
1. Tracker taps "Invite partner" (Partner tab empty state or onboarding step 7)
2. App generates a unique single-use invite link tied to the tracker's Supabase account
3. iOS native share sheet opens — tracker sends via iMessage, WhatsApp, email, or any other app
4. Partner taps the link → deep links to Cadence (App Store if not installed, connect screen if installed)
5. Partner completes their own onboarding → connection is established

**Link behaviour:** Single-use. Expires after 7 days. Tracker can revoke or regenerate at any time from Profile settings.

**Disconnecting:** Either partner can disconnect at any time from Profile/Settings → Partner section → Disconnect. Disconnection immediately revokes all shared data visibility. The `shared_logs` rows for that connection are deleted.

### 10.5 Notifications

All notifications are individually toggleable in Profile/Settings. All are opt-in via the iOS permissions prompt at the end of onboarding.

| Notification | Recipient | Trigger |
|---|---|---|
| Period start reminder | Tracker | Day before predicted period start |
| Ovulation window alert | Tracker | When fertile window begins |
| Daily log reminder | Tracker | User-configured time (default 8:00 PM) |
| Partner activity | Tracker + Partner | When connected partner logs their day |
| Period is late | Tracker | When predicted start date passes with no period log |
| Cycle phase change | Tracker | When entering a new phase |

**Delivery:** Supabase Edge Functions + APNs.

**Out of scope for MVP:** Email notifications, notification history/inbox, partner-specific notification customisation.

### 10.6 Insights

**Location:** Inside the Calendar tab, scrollable section below the monthly grid. No dedicated tab.

| Insight | Minimum data required |
|---|---|
| Current cycle day + phase | Available immediately |
| Average cycle length | 1 completed cycle (or onboarding seed) |
| Period duration (last cycle) | 1 completed cycle |
| Average period duration | 2+ cycles |
| Cycle length trend (mini bar chart) | 2+ cycles |
| Most common symptoms per phase | 2+ cycles with symptom logs |

**Empty states:** Insight cards not yet computable show a friendly placeholder — e.g. "Log 1 more cycle to see your average length." Never a blank card.

**Out of scope for MVP:** Mood/energy patterns by phase, symptom correlations, partner insights, data export.

---

## 11. Screen Specifications

### 11.1 Welcome Screen

**Structure:** Full-screen immersive welcome. No feature list, no carousel, no screenshots. Headline straight to auth CTAs.

- **Background:** Abstract soft circle geometry in Pink Tint and Pink Faint on Base White
- **Wordmark:** "Cadence." — Playfair Display, `#1A0F0E`, coral dot
- **Eyebrow:** "Cycle tracking, together" — DM Sans, uppercase, Coral Pink
- **Headline:** "Your rhythm, *shared* with someone who cares." — Playfair Display large, italic "shared" in Coral Pink
- **Sub-copy:** "Track your cycle. Understand your body. Let your partner in — on your terms."
- **Primary CTA:** "Continue with Apple" — dark fill `#1A0F0E`, white text, Apple logo
- **Divider:** "or"
- **Secondary CTA:** "Continue with Email" — white fill, warm border
- **Footer:** Terms & Privacy Policy links in tertiary text

### 11.2 Onboarding Flow — Tracker

Progress indicator: pill-shaped dots at top of each screen. Active dot stretches into a pill shape.

| Step | Screen | Required | Key UI |
|---|---|---|---|
| 1 | Role selection | Yes | Two selection cards (radio pattern). Selected card highlighted in Coral Pink. |
| 2 | Last period date | Yes | Inline mini calendar, selected date shown as coral circle. Date display card above. |
| 3 | Cycle length + period duration | Yes | Two picker rows, default 28 days / 5 days. Helper: "Not sure? Use the defaults — they self-correct as you log." |
| 4 | Sharing preferences | Yes | Toggle list, all off by default. Sub-label per category. Copy: "All off by default. You can change this anytime." |
| 5 | Invite partner | No (skippable) | Centred layout, coral icon, share icon on primary CTA. "Skip for now" as ghost text below. Step pill changes to muted "Optional" colour. |
| 6 | Notifications | Yes | Per-notification toggle list with sensible defaults. Daily reminder shows current time. |

**Final CTA copy:** "Enter Cadence" — not "Done" or "Finish."

### 11.3 Onboarding Flow — Partner

Partner arrives via invite link deep link. Shorter flow.

| Step | Screen | Required |
|---|---|---|
| 1 | Account creation | Yes |
| 2 | Role selection | Yes |
| 3 | Accept connection (pre-filled from invite link) | Yes |
| 4 | Notification opt-in | Yes |

### 11.4 Today Screen

**Nav bar:** Playfair Display "Today" title left. Avatar/initials circle top-right (Profile entry point).

**Unlogged state:**

| Element | Detail |
|---|---|
| Hero card | Coral Pink background. Cycle day in large Playfair. Phase label + prediction pills. |
| Log CTA | Dashed border card. "How are you feeling today?" Copy. Coral "Log today" button. |
| Partner card | Always visible. Shows partner's logged data or "hasn't logged yet" state. |

**Logged state:**

| Element | Detail |
|---|---|
| Hero card | Same card — pill updates to "✓ Logged today". |
| Today's log section | Card showing logged entries (mood, energy, symptoms). "Edit" action top-right. |
| Partner card | Same position, persistent. |

**Log entry bottom sheet (slides up over Today screen):**

| Section | UI |
|---|---|
| Period flow | 5-button row: None · Spotting · Light · Medium · Heavy |
| Mood | Multi-select chips |
| Energy | 3-button row: Low · Medium · High |
| Symptoms | Multi-select chips + "more" to expand full list |
| Sleep, Sex, Notes | Further down sheet via scroll — not shown at top |
| CTA | "Save log" coral button |

**Log sheet access:** Only from the "Log today" card. No FAB.

### 11.5 Calendar Screen

**Layout:** Monthly grid → selected day summary card → insights section (single scroll, no tabs).

**Calendar grid:**

| State | Visual |
|---|---|
| Today | Coral Pink circle around date number |
| Logged day | Small coral dot inside date circle |
| Selected day | Dark `#1A0F0E` circle |
| Future / predicted | Tertiary text colour, phase strips still shown |

**Phase strips:** 3px strips below each date number — not full cell fills.

| Phase | Strip Colour |
|---|---|
| Period | `#F88379` Coral Pink |
| Ovulation | `#E37383` Watermelon Pink |
| Fertile window | `#FDDBD8` Pink Tint |
| Luteal | `#F0E8E0` warm tint |
| Follicular | No strip |

**Tapping a date:** Inline summary card appears below the grid showing phase label and logged entries for that day. Edit button opens the log sheet pre-populated. No new screen pushed.

**Insights section:** Four cards in a 2-column grid. Cycle length trend uses a wide full-width card with a mini bar chart. Most common symptoms shown as chips. Empty states use friendly placeholder copy.

**Nav bar:** "Calendar" title left. Month/year label + chevron right for month navigation.

### 11.6 Partner Tab

**Empty state (no partner connected):**
- Centred nested circle illustration with heart icon in Coral Pink
- Title: "Invite your partner" (Playfair)
- Sub-copy: "Share your cycle with someone who cares — on your terms."
- Primary CTA: "Send invite link" with share icon
- Hint below: "You can choose exactly what they see after connecting."

**Tracker's connected view:**
- Green connection dot + "Connected with [name]"
- Dark hero card (`#1A0F0E` background) — partner's cycle day, phase, shared mood/energy pills. Dark background visually distinguishes partner data from the user's own coral hero card.
- "Shared today" section: period status, symptoms
- "What [name] shares with you" section: category toggles with Edit action inline

**Partner's view (non-tracker):**
- Dark hero card with tracker's cycle day and phase
- Phase explanation card: always shown for all phases — plain language description of what the current phase typically means (e.g. "Energy is typically higher during this phase. Sarah may feel more social and confident over the next few days.")
- "Shared with you" section: only categories the tracker has enabled
- Tab bar: Partner · Calendar · Profile

**"Not logged yet" state:** Dashed border card with muted text. Never an error state.

**Both-tracker scenario:** Each user sees the other's Partner tab view when they navigate there. Fully symmetric layout, each person's sharing settings are independent.

### 11.7 Profile / Settings

Accessed via avatar in top-right nav bar. Modal sheet dismissed via "Done."

**Four sections:**

| Section | Contents |
|---|---|
| Partner | Connection status + partner name/email, Disconnect action (red text) |
| Sharing | Category toggles — mirrors Partner tab. Same underlying setting. |
| Notifications | Per-notification toggles, daily reminder shows current time |
| Account | Privacy Policy link, Terms of Service link, Sign out (red icon + label) |

**Profile header:** Avatar initials circle, name (Playfair), email (DM Sans muted), Edit link.

**Sign out:** Red icon, red label. Present in Account section — not hidden.

**Delete account:** Out of scope for MVP.

---

## 12. Data Architecture

### 12.1 Supabase Schema (Core Tables)

**`users`**
- `id` (uuid, primary key)
- `email`
- `display_name`
- `is_tracker` (boolean — role selection from onboarding)
- `created_at`

**`cycle_profiles`** (one per tracker user)
- `user_id` (FK → users)
- `last_period_date`
- `avg_cycle_length` (days, computed)
- `avg_period_duration` (days, computed)
- `seeded_cycle_length` (onboarding input)
- `seeded_period_duration` (onboarding input)

**`cycle_logs`** (one row per logged day per user)
- `id`, `user_id`, `log_date`
- `period_flow` (encrypted)
- `mood` (encrypted, array)
- `energy` (encrypted)
- `symptoms` (encrypted, array)
- `sleep_quality` (encrypted)
- `intimacy_logged` (encrypted, boolean)
- `intimacy_protected` (encrypted, boolean)
- `notes` (encrypted, text)

**`sharing_settings`** (one row per user)
- `user_id`
- `share_period` (boolean, default false)
- `share_symptoms` (boolean, default false)
- `share_mood` (boolean, default false)
- `share_energy` (boolean, default false)

**`partner_connections`**
- `id`, `tracker_user_id`, `partner_user_id`, `connected_at`, `status`

**`invite_links`**
- `id`, `tracker_user_id`, `token` (unique), `expires_at`, `used` (boolean)

**`shared_logs`** (written by the app whenever sharing settings change or a new log is saved)
- `id`, `tracker_user_id`, `partner_user_id`, `log_date`
- `period_flow` (encrypted, only if share_period = true)
- `symptoms` (encrypted, only if share_symptoms = true)
- `mood` (encrypted, only if share_mood = true)
- `energy` (encrypted, only if share_energy = true)
- `cycle_day`, `cycle_phase`, `predicted_next_period` (always written — phase info is always shared with a connected partner)

### 12.2 Encryption

**Client-side AES-GCM encryption** on all sensitive health fields before writes. Decryption on-device after reads. Supabase never holds plaintext health data.

**Implementation:** CryptoKit on iOS. Per-user symmetric key derived from a server-side secret + user UUID. Key never leaves the device in plaintext.

**Encrypted fields:** All fields in `cycle_logs` except `id`, `user_id`, `log_date`. Mirrored fields in `shared_logs`.

### 12.3 Row Level Security (Supabase RLS)

| Table | Policy |
|---|---|
| `cycle_logs` | Read/write: owning user only |
| `shared_logs` | Read: connected partner. Write: tracker only. |
| `sharing_settings` | Read: both connected users. Write: tracker only. |
| `partner_connections` | Read: both users in the connection. |
| `invite_links` | Read/write: tracker who created it. |

A partner's session is physically incapable of querying `cycle_logs`. Ever.

### 12.4 Shared Data Flow

When a tracker **saves a log** or **updates sharing settings:**
1. App writes the full log to `cycle_logs` (encrypted)
2. App checks current `sharing_settings` for this user
3. App constructs a `shared_logs` row with only the enabled categories
4. App writes (or updates) the `shared_logs` row

When a tracker **turns off a category:**
1. `sharing_settings` updated
2. The corresponding field in `shared_logs` is cleared (set to null) for all future rows
3. Existing `shared_logs` rows are retroactively updated to remove that field

When a connection is **disconnected:**
1. `partner_connections` status set to inactive
2. All `shared_logs` rows for that connection are deleted

---

## 13. Privacy & Data Policy

**Hosting:** Supabase US (us-east-1). Privacy policy must disclose US data storage explicitly.

**At-rest encryption:** Supabase default AES-256 for all data at the infrastructure level.

**Client-side encryption:** AES-GCM on all sensitive health fields (see Section 12.2). Cadence cannot provide readable health data even under legal compulsion.

**Data sold/shared with advertisers:** Never.

**App Store privacy nutrition label disclosures:**
- Health & Fitness Data (period, symptoms, mood, energy)
- Usage Data (session activity)
- No advertising data
- No third-party data sharing

**Privacy policy must cover:**
- Health data types collected
- US hosting disclosure
- No sale to third parties
- No advertiser sharing
- Right to data deletion (manual process until delete account is built in v2)
- Contact address for data requests

**Post-2022 context:** Client-side encryption means Cadence genuinely cannot produce readable health data in response to legal requests. This is a meaningful trust differentiator and should be stated plainly in the privacy policy.

---

## 14. Notification Delivery

**Infrastructure:** Supabase Edge Functions triggered by database events or scheduled crons → APNs.

| Notification | Trigger mechanism |
|---|---|
| Period reminder | Scheduled cron — day before predicted start date |
| Ovulation alert | Scheduled cron — when fertile window opens |
| Daily log reminder | Scheduled cron — user's configured time |
| Partner activity | Database trigger on `shared_logs` insert |
| Period is late | Scheduled cron — when predicted start passes with no log |
| Cycle phase change | Scheduled cron — on phase transition |

All notification preferences stored in Supabase per user. App syncs preferences on change.

---

## 15. Rollout Considerations

- **TestFlight beta** before App Store submission — test the invite link deep link flow on real devices, not simulators
- **Privacy policy** must be live at a real URL before App Store submission — not a placeholder
- **App Store review note:** Include a test account with pre-seeded cycle data and an active partner connection for reviewers. The partner sharing flow requires two accounts to demonstrate
- **Cold start UX:** Verify that onboarding seed data produces visible, correct predictions before the user has logged a single cycle — this is the first impression of the prediction engine
- **Encryption key management:** Stress-test the CryptoKit key derivation on older iOS devices before submission. AES-GCM is hardware-accelerated on A-series chips but verify behaviour on minimum supported iOS version

---

## 16. Out of Scope — Post-MVP Backlog

| Feature | Notes |
|---|---|
| Dark mode | Design system is ready; just needs a dark token set |
| Delete account | Requires shared data handling design and GDPR data export |
| Subscription / monetisation | Introduce in v2 with clear premium feature set |
| ML-based predictions | Requires significant data volume and training infrastructure |
| BBT / cervical mucus tracking | Adds data model complexity, pairs with advanced predictions |
| Medications / supplements | Separate log category with reminder scheduling |
| Multiple partner connections | Requires connection management UI overhaul |
| Android | Separate project |
| EU hosting | When user base justifies a dedicated EU Supabase instance |
| Field-level sharing granularity | V2 — category-level is right for MVP |
| Mood / energy phase patterns in insights | Requires 3+ cycles of data to be meaningful |

---

## 17. Success Metrics (Post-Launch)

- **Day 7 retention** — target 40%+ (health app benchmark is ~25%)
- **Partner connection rate** — % of tracker users who connect a partner within 7 days
- **Daily log rate** — % of days logged by active users (target: 5 of 7 days/week)
- **Prediction accuracy** — % of period start predictions within ±2 days after 3+ cycles
- **Onboarding completion rate** — % of users who reach "Enter Cadence" from welcome screen

---

*End of document. All decisions sourced from Cadence Decisions (Notion). PRD version 1.0 — ready for implementation.*
