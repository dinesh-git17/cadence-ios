-- 001_initial_schema.sql
-- Cadence initial schema: seven tables with row level security

-- ============================================================
-- Tables
-- ============================================================

create table public.users (
    id uuid primary key references auth.users(id) on delete cascade,
    email text not null,
    display_name text not null,
    is_tracker boolean not null default false,
    created_at timestamptz not null default now()
);

create table public.cycle_profiles (
    user_id uuid primary key references public.users(id) on delete cascade,
    last_period_date date not null,
    avg_cycle_length integer,
    avg_period_duration integer,
    seeded_cycle_length integer not null,
    seeded_period_duration integer not null
);

create table public.cycle_logs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    log_date date not null,
    period_flow text,
    mood text,
    energy text,
    symptoms text,
    sleep_quality text,
    intimacy_logged text,
    intimacy_protected text,
    notes text
);

create table public.partner_connections (
    id uuid primary key default gen_random_uuid(),
    tracker_user_id uuid not null references public.users(id) on delete cascade,
    partner_user_id uuid not null references public.users(id) on delete cascade,
    connected_at timestamptz not null default now(),
    status text not null default 'active' check (status in ('active', 'inactive'))
);

create table public.sharing_settings (
    user_id uuid primary key references public.users(id) on delete cascade,
    share_period boolean not null default false,
    share_symptoms boolean not null default false,
    share_mood boolean not null default false,
    share_energy boolean not null default false
);

create table public.invite_links (
    id uuid primary key default gen_random_uuid(),
    tracker_user_id uuid not null references public.users(id) on delete cascade,
    token text not null unique,
    expires_at timestamptz not null,
    used boolean not null default false
);

create table public.shared_logs (
    id uuid primary key default gen_random_uuid(),
    tracker_user_id uuid not null references public.users(id) on delete cascade,
    partner_user_id uuid not null references public.users(id) on delete cascade,
    log_date date not null,
    period_flow text,
    symptoms text,
    mood text,
    energy text,
    cycle_day integer not null,
    cycle_phase text not null check (cycle_phase in ('menstrual', 'follicular', 'ovulation', 'luteal')),
    predicted_next_period date,
    unique (tracker_user_id, log_date)
);

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.users enable row level security;
alter table public.cycle_profiles enable row level security;
alter table public.cycle_logs enable row level security;
alter table public.partner_connections enable row level security;
alter table public.sharing_settings enable row level security;
alter table public.invite_links enable row level security;
alter table public.shared_logs enable row level security;

-- users: owner only
create policy "users_select_own" on public.users
    for select using (auth.uid() = id);
create policy "users_insert_own" on public.users
    for insert with check (auth.uid() = id);
create policy "users_update_own" on public.users
    for update using (auth.uid() = id);

-- cycle_profiles: owner only
create policy "cycle_profiles_select_own" on public.cycle_profiles
    for select using (auth.uid() = user_id);
create policy "cycle_profiles_insert_own" on public.cycle_profiles
    for insert with check (auth.uid() = user_id);
create policy "cycle_profiles_update_own" on public.cycle_profiles
    for update using (auth.uid() = user_id);

-- cycle_logs: owner only (partners NEVER access this table)
create policy "cycle_logs_select_own" on public.cycle_logs
    for select using (auth.uid() = user_id);
create policy "cycle_logs_insert_own" on public.cycle_logs
    for insert with check (auth.uid() = user_id);
create policy "cycle_logs_update_own" on public.cycle_logs
    for update using (auth.uid() = user_id);
create policy "cycle_logs_delete_own" on public.cycle_logs
    for delete using (auth.uid() = user_id);

-- partner_connections: both users in the connection can read
create policy "partner_connections_select" on public.partner_connections
    for select using (
        auth.uid() = tracker_user_id or auth.uid() = partner_user_id
    );
create policy "partner_connections_insert" on public.partner_connections
    for insert with check (
        auth.uid() = tracker_user_id or auth.uid() = partner_user_id
    );
create policy "partner_connections_update" on public.partner_connections
    for update using (
        auth.uid() = tracker_user_id or auth.uid() = partner_user_id
    );

-- sharing_settings: tracker writes, both connected users read
create policy "sharing_settings_select_own" on public.sharing_settings
    for select using (auth.uid() = user_id);
create policy "sharing_settings_select_partner" on public.sharing_settings
    for select using (
        exists (
            select 1 from public.partner_connections
            where status = 'active'
              and tracker_user_id = sharing_settings.user_id
              and partner_user_id = auth.uid()
        )
    );
create policy "sharing_settings_insert_own" on public.sharing_settings
    for insert with check (auth.uid() = user_id);
create policy "sharing_settings_update_own" on public.sharing_settings
    for update using (auth.uid() = user_id);

-- invite_links: tracker who created it only
create policy "invite_links_select_own" on public.invite_links
    for select using (auth.uid() = tracker_user_id);
create policy "invite_links_insert_own" on public.invite_links
    for insert with check (auth.uid() = tracker_user_id);
create policy "invite_links_update_own" on public.invite_links
    for update using (auth.uid() = tracker_user_id);

-- shared_logs: partner reads, tracker writes
-- Tracker also needs select for PostgREST upsert (ON CONFLICT requires visibility)
create policy "shared_logs_select_tracker" on public.shared_logs
    for select using (auth.uid() = tracker_user_id);
create policy "shared_logs_select_partner" on public.shared_logs
    for select using (auth.uid() = partner_user_id);
create policy "shared_logs_insert_tracker" on public.shared_logs
    for insert with check (auth.uid() = tracker_user_id);
create policy "shared_logs_update_tracker" on public.shared_logs
    for update using (auth.uid() = tracker_user_id);
