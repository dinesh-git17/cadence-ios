-- 004_accept_invite.sql
-- RPC function to accept an invite atomically: creates partner_connections
-- row and marks the invite token as used. SECURITY DEFINER bypasses RLS
-- so the partner session can update invite_links.

create or replace function public.accept_invite(
    invite_token text,
    accepting_user_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_tracker_id uuid;
    v_connection_id uuid;
begin
    -- Validate and lock the invite row
    select tracker_user_id into v_tracker_id
    from invite_links
    where token = invite_token
      and used = false
      and expires_at > now()
    for update;

    if v_tracker_id is null then
        return json_build_object('success', false, 'error', 'Invalid or expired invite link.');
    end if;

    -- Mark token as used
    update invite_links
    set used = true
    where token = invite_token;

    -- Create partner connection
    insert into partner_connections (tracker_user_id, partner_user_id)
    values (v_tracker_id, accepting_user_id)
    returning id into v_connection_id;

    return json_build_object(
        'success', true,
        'connection_id', v_connection_id,
        'tracker_id', v_tracker_id
    );
end;
$$;
