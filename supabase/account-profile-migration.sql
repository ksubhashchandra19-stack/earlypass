-- Allow each signed-in Teacher or Student to update their own display name.
-- Student identity fields such as roll number, student ID, and class remain teacher-managed.
create or replace function public.update_my_account_details(p_display_name text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_name text := nullif(trim(coalesce(p_display_name, '')), '');
  v_email text;
begin
  if v_uid is null then
    raise exception 'Please sign in first.';
  end if;
  if v_name is null or length(v_name) > 120 then
    raise exception 'Enter a name up to 120 characters.';
  end if;

  select * into v_profile
  from public.profiles
  where user_id = v_uid
  for update;

  if not found or v_profile.role not in ('STUDENT', 'TEACHER') then
    raise exception 'Only your own Student or Teacher account can be updated here.';
  end if;

  update public.profiles
  set display_name = v_name
  where user_id = v_uid;

  if v_profile.role = 'STUDENT' and v_profile.student_id is not null then
    select email into v_email from auth.users where id = v_uid;
    update public.students
    set name = v_name, email = v_email
    where id = v_profile.student_id;
  end if;
end;
$$;

create or replace function public.sync_my_student_email()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_email text;
begin
  if v_uid is null then return; end if;
  select * into v_profile from public.profiles where user_id = v_uid;
  if not found or v_profile.role <> 'STUDENT' or v_profile.student_id is null then return; end if;
  select email into v_email from auth.users where id = v_uid;
  update public.students set email = v_email where id = v_profile.student_id;
end;
$$;

revoke all on function public.update_my_account_details(text) from public;
revoke all on function public.sync_my_student_email() from public;
grant execute on function public.update_my_account_details(text) to authenticated;
grant execute on function public.sync_my_student_email() to authenticated;
