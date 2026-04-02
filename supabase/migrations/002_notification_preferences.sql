-- 002_notification_preferences.sql
-- Stores per-user notification toggle states set during onboarding.

create table public.notification_preferences (
    user_id uuid primary key references public.users(id) on delete cascade,
    period_reminder boolean not null default true,
    ovulation_alert boolean not null default true,
    daily_log_reminder boolean not null default true,
    partner_activity boolean not null default true,
    phase_change boolean not null default true
);

alter table public.notification_preferences enable row level security;

create policy "notification_preferences_select_own"
    on public.notification_preferences
    for select using (auth.uid() = user_id);

create policy "notification_preferences_insert_own"
    on public.notification_preferences
    for insert with check (auth.uid() = user_id);

create policy "notification_preferences_update_own"
    on public.notification_preferences
    for update using (auth.uid() = user_id);
