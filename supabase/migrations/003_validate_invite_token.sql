-- 003_validate_invite_token.sql
-- RPC function for partner invite token validation.
-- SECURITY DEFINER bypasses RLS so the partner session can validate
-- a token in invite_links (which is otherwise restricted to the tracker).

create or replace function public.validate_invite_token(invite_token text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    result json;
begin
    select json_build_object(
        'valid', true,
        'tracker_name', u.display_name,
        'tracker_id', u.id
    ) into result
    from invite_links il
    join users u on il.tracker_user_id = u.id
    where il.token = invite_token
      and il.used = false
      and il.expires_at > now();

    if result is null then
        return json_build_object('valid', false);
    end if;

    return result;
end;
$$;
