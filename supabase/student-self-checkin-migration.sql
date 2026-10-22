-- Enable authenticated students to mark their own attendance once each morning
-- and submit their own check-in for a scheduled period.
create or replace function public.student_mark_present(p_class_day_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_student public.students%rowtype;
  v_day public.class_days%rowtype;
  v_weekday smallint;
  v_period_id uuid;
  v_start time;
  v_now timestamp without time zone := timezone('Asia/Kolkata', now());
begin
  if v_uid is null then raise exception 'Please sign in first.'; end if;
  select * into v_profile from public.profiles where user_id = v_uid;
  if not found or v_profile.role <> 'STUDENT' or v_profile.student_id is null then
    raise exception 'Only a Student account can record its own attendance.';
  end if;
  select * into v_student from public.students where id = v_profile.student_id and active;
  if not found then raise exception 'Your active student record was not found.'; end if;
  select * into v_day from public.class_days where id = p_class_day_id;
  if not found or v_day.classroom_id <> v_student.classroom_id or v_day.day <> v_now::date then
    raise exception 'Today’s class session is not available.';
  end if;
  v_weekday := extract(isodow from v_day.day)::smallint;
  if exists (select 1 from public.periods where classroom_id = v_student.classroom_id and weekday = v_weekday) then
    select id, starts_at into v_period_id, v_start
    from public.periods where classroom_id = v_student.classroom_id and weekday = v_weekday
    order by position limit 1;
  else
    select id, starts_at into v_period_id, v_start
    from public.periods where classroom_id = v_student.classroom_id and weekday = 0
    order by position limit 1;
  end if;
  if v_period_id is null then raise exception 'The teacher has not scheduled the first period yet.'; end if;
  if v_now::time >= v_start then raise exception 'Morning self-attendance closes when Period 1 starts. Ask your teacher to mark you.'; end if;
  if exists (select 1 from public.attendance where class_day_id = v_day.id and student_id = v_student.id) then
    raise exception 'Attendance is already recorded. Ask your teacher if it needs correction.';
  end if;
  insert into public.attendance(class_day_id, student_id, period_id, status, marked_by)
  values (v_day.id, v_student.id, v_period_id, 'PRESENT', v_uid);
end;
$$;

create or replace function public.student_checkin_period(p_class_day_id uuid, p_period_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_student public.students%rowtype;
  v_day public.class_days%rowtype;
  v_period public.periods%rowtype;
  v_weekday smallint;
  v_first_period_id uuid;
  v_daily_status public.attendance_status;
  v_now timestamp without time zone := timezone('Asia/Kolkata', now());
  v_early_minutes integer;
  v_status public.arrival_status;
begin
  if v_uid is null then raise exception 'Please sign in first.'; end if;
  select * into v_profile from public.profiles where user_id = v_uid;
  if not found or v_profile.role <> 'STUDENT' or v_profile.student_id is null then
    raise exception 'Only a Student account can record its own check-in.';
  end if;
  select * into v_student from public.students where id = v_profile.student_id and active;
  if not found then raise exception 'Your active student record was not found.'; end if;
  select * into v_day from public.class_days where id = p_class_day_id;
  if not found or v_day.classroom_id <> v_student.classroom_id or v_day.day <> v_now::date then
    raise exception 'Today’s class session is not available.';
  end if;

  v_weekday := extract(isodow from v_day.day)::smallint;
  if exists (select 1 from public.periods where classroom_id = v_student.classroom_id and weekday = v_weekday) then
    select id into v_first_period_id from public.periods
    where classroom_id = v_student.classroom_id and weekday = v_weekday
    order by position limit 1;
    select * into v_period from public.periods
    where id = p_period_id and classroom_id = v_student.classroom_id and weekday = v_weekday;
  else
    select id into v_first_period_id from public.periods
    where classroom_id = v_student.classroom_id and weekday = 0
    order by position limit 1;
    select * into v_period from public.periods
    where id = p_period_id and classroom_id = v_student.classroom_id and weekday = 0;
  end if;
  if v_first_period_id is null or v_period.id is null then raise exception 'That period is not scheduled for today.'; end if;

  select status into v_daily_status from public.attendance
  where class_day_id = v_day.id and student_id = v_student.id and period_id = v_first_period_id;
  if v_daily_status is null then raise exception 'Record your morning attendance first.'; end if;
  if v_daily_status = 'ABSENT' then raise exception 'Ask your teacher to review your attendance before checking in.'; end if;
  if exists (select 1 from public.arrivals
    where class_day_id = v_day.id and student_id = v_student.id and period_id = p_period_id) then
    raise exception 'You are already checked in for this period.';
  end if;

  select coalesce(ws.early_window_minutes, c.early_window_minutes, 15)
    into v_early_minutes
  from public.classrooms c
  left join public.weekly_settings ws on ws.classroom_id = c.id and ws.weekday = v_weekday
  where c.id = v_student.classroom_id;

  if v_now::time < v_period.starts_at - make_interval(mins => v_early_minutes) then
    v_status := 'EARLY';
  elsif v_now::time <= v_period.starts_at then
    v_status := 'ON_TIME';
  else
    v_status := 'LATE';
  end if;

  insert into public.arrivals(class_day_id, student_id, period_id, arrived_at, status, recorded_by)
  values (v_day.id, v_student.id, p_period_id, now(), v_status, v_uid);
end;
$$;

revoke all on function public.student_mark_present(uuid) from public;
revoke all on function public.student_checkin_period(uuid, uuid) from public;
grant execute on function public.student_mark_present(uuid) to authenticated;
grant execute on function public.student_checkin_period(uuid, uuid) to authenticated;
