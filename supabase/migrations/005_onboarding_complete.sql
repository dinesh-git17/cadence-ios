-- 005_onboarding_complete.sql
-- Adds onboarding_complete flag to users table so completion state
-- survives sign-out and works across devices.

alter table public.users
    add column onboarding_complete boolean not null default false;
