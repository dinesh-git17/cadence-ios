-- 006_add_period_late_notification.sql
-- Add period_late notification preference for trackers.
-- Existing RLS policies on notification_preferences cover all columns.

alter table public.notification_preferences
    add column period_late boolean not null default true;
