-- EarlyPass class-first signup and daily goal support.
-- Run once after schema.sql.
create extension if not exists pgcrypto;

alter table public.earlypass_rewards
  add column if not exists manual_target boolean not null default false;
alter table public.earlypass_rewards
  add column if not exists follow_up text not null default 'A brief reflection and a fresh start tomorrow.';

create or replace function public.complete_class_signup()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_meta jsonb;
  v_email text;
  v_name text;
  v_role text;
  v_join_code text;
  v_school_id uuid;
  v_classroom_id uuid;
  v_class public.classrooms%rowtype;
  v_student_id uuid;
  v_roll integer;
  v_student_code text;
  v_class_name text;
  v_section text;
  v_room text;
  v_start time;
  v_target integer;
begin
  if v_uid is null then
    raise exception 'Please sign in before completing account setup.';
  end if;

  select raw_user_meta_data, email
    into v_meta, v_email
    from auth.users
    where id = v_uid
    for update;

  if exists (select 1 from public.profiles where user_id = v_uid) then
    return jsonb_build_object('ok', true, 'already_setup', true);
  end if;

  v_name := nullif(trim(v_meta->>'display_name'), '');
  v_role := upper(coalesce(v_meta->>'requested_role', ''));
  v_join_code := upper(regexp_replace(trim(coalesce(v_meta->>'class_join_code', '')), '[[:space:]]+', '', 'g'));

  if v_name is null then
    raise exception 'Enter your name to finish account setup.';
  end if;
  if v_role not in ('TEACHER', 'STUDENT') then
    raise exception 'Choose Teacher or Student to finish account setup.';
  end if;
  if length(v_join_code) < 6 then
    raise exception 'Enter a class join code with at least 6 characters.';
  end if;

  if v_role = 'TEACHER' then
    v_class_name := nullif(trim(v_meta->>'class_name'), '');
    v_section := nullif(trim(v_meta->>'section'), '');
    v_room := coalesce(nullif(trim(v_meta->>'room'), ''), 'Classroom');
    v_start := coalesce(nullif(v_meta->>'class_start', '')::time, '08:30'::time);
    v_target := greatest(1, least(500, coalesce(nullif(v_meta->>'earlypass_target', '')::integer, 25)));

    if v_class_name is null or v_section is null then
      raise exception 'Enter your class and section to create your classroom.';
    end if;
    if exists (
      select 1 from public.classrooms
      where access_code_hash = encode(digest(v_join_code, 'sha256'), 'hex')
    ) then
      raise exception 'That class join code is already in use. Choose another code.';
    end if;

    insert into public.schools(name)
      values ('EarlyPass class ' || v_class_name || v_section)
      returning id into v_school_id;

    insert into public.classrooms(
      school_id, class_name, section, room, class_start,
      early_window_minutes, earlypass_target, access_code_hash
    ) values (
      v_school_id, v_class_name, v_section, v_room, v_start,
      15, v_target, encode(digest(v_join_code, 'sha256'), 'hex')
    ) returning id into v_classroom_id;

    insert into public.profiles(user_id, school_id, role, display_name)
      values (v_uid, v_school_id, 'TEACHER', v_name);

    insert into public.classroom_teachers(classroom_id, user_id)
      values (v_classroom_id, v_uid);

    insert into public.periods(classroom_id, position, name, subject, starts_at, ends_at, teacher_name, room)
      values
        (v_classroom_id, 1, 'Period 1', '', v_start, (v_start + interval '45 minutes')::time, v_name, v_room),
        (v_classroom_id, 2, 'Period 2', '', (v_start + interval '45 minutes')::time, (v_start + interval '90 minutes')::time, v_name, v_room),
        (v_classroom_id, 3, 'Period 3', '', (v_start + interval '90 minutes')::time, (v_start + interval '135 minutes')::time, v_name, v_room),
        (v_classroom_id, 4, 'Period 4', '', (v_start + interval '150 minutes')::time, (v_start + interval '195 minutes')::time, v_name, v_room);

    return jsonb_build_object('ok', true, 'role', 'TEACHER', 'classroom_id', v_classroom_id);
  end if;

  select c.* into v_class
    from public.classrooms c
    where c.access_code_hash = encode(digest(v_join_code, 'sha256'), 'hex')
    limit 1
    for update;

  if v_class.id is null then
    raise exception 'We could not find that class code. Check it with your teacher and try again.';
  end if;

  select coalesce(max(case when roll_number ~ '^[0-9]+$' then roll_number::integer end), 0) + 1
    into v_roll
    from public.students
    where classroom_id = v_class.id;

  v_student_code := 'EP-' ||
    left(regexp_replace(upper(v_class.class_name || v_class.section), '[^A-Z0-9]', '', 'g'), 10) ||
    '-' || lpad(v_roll::text, 3, '0');

  insert into public.students(school_id, classroom_id, name, roll_number, student_code, email)
    values (v_class.school_id, v_class.id, v_name, lpad(v_roll::text, 2, '0'), v_student_code, v_email)
    returning id into v_student_id;

  insert into public.profiles(user_id, school_id, role, display_name, student_id)
    values (v_uid, v_class.school_id, 'STUDENT', v_name, v_student_id);

  return jsonb_build_object('ok', true, 'role', 'STUDENT', 'classroom_id', v_class.id, 'student_id', v_student_id);
end;
$$;

revoke all on function public.complete_class_signup() from public;
grant execute on function public.complete_class_signup() to authenticated;

create or replace function public.set_class_join_code(p_classroom_id uuid, p_join_code text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := upper(regexp_replace(trim(coalesce(p_join_code, '')), '[[:space:]]+', '', 'g'));
  v_hash text;
begin
  if v_uid is null then raise exception 'Please sign in first.'; end if;
  if length(v_code) < 6 then raise exception 'Use a join code with at least 6 characters.'; end if;
  if not exists (select 1 from public.classroom_teachers where classroom_id = p_classroom_id and user_id = v_uid) then
    raise exception 'Only this class teacher can change its join code.';
  end if;
  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  if exists (select 1 from public.classrooms where access_code_hash = v_hash and id <> p_classroom_id) then
    raise exception 'That join code is already used by another class. Choose a different code.';
  end if;
  update public.classrooms set access_code_hash = v_hash where id = p_classroom_id;
end;
$$;

revoke all on function public.set_class_join_code(uuid, text) from public;
grant execute on function public.set_class_join_code(uuid, text) to authenticated;
