-- Atomic EarlyPass check-in.
-- Apply this migration in the Supabase SQL Editor before deploying the matching frontend.
create or replace function public.record_classroom_checkin(
  p_class_day_id uuid,
  p_student_id uuid,
  p_period_id uuid,
  p_arrival_status public.arrival_status,
  p_period_status public.attendance_status
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_classroom_id uuid;
  v_student_classroom_id uuid;
  v_period_classroom_id uuid;
  v_arrival_created boolean := false;
  v_attendance_created boolean := false;
  v_row_count bigint;
  v_target integer;
  v_early_count integer;
begin
  if p_arrival_status is null or p_period_status is null then
    raise exception 'Arrival and period statuses are required.' using errcode = '22023';
  end if;

  select classroom_id into v_classroom_id
  from public.class_days where id = p_class_day_id;

  select classroom_id into v_student_classroom_id
  from public.students where id = p_student_id and active = true;

  select classroom_id into v_period_classroom_id
  from public.periods where id = p_period_id;

  if v_classroom_id is null
     or v_student_classroom_id is null
     or v_period_classroom_id is null
     or v_classroom_id <> v_student_classroom_id
     or v_classroom_id <> v_period_classroom_id then
    raise exception 'The selected student, period, and class session must belong to the same classroom.'
      using errcode = '22023';
  end if;

  if not public.is_class_teacher(v_classroom_id) then
    raise exception 'Only an assigned teacher can record a classroom check-in.'
      using errcode = '42501';
  end if;

  -- Keep the first arrival timestamp/status; retries must not rewrite it.
  insert into public.arrivals (class_day_id, student_id, arrived_at, status, recorded_by)
  values (p_class_day_id, p_student_id, now(), p_arrival_status, auth.uid())
  on conflict (class_day_id, student_id) do nothing;
  get diagnostics v_row_count = row_count;
  v_arrival_created := v_row_count > 0;

  -- Idempotent for the same period: a retry cannot overwrite an existing mark.
  insert into public.attendance (class_day_id, student_id, period_id, status, marked_by)
  values (p_class_day_id, p_student_id, p_period_id, p_period_status, auth.uid())
  on conflict (class_day_id, student_id, period_id) do nothing;
  get diagnostics v_row_count = row_count;
  v_attendance_created := v_row_count > 0;

  select target into v_target
  from public.earlypass_rewards
  where class_day_id = p_class_day_id;

  if v_target is not null then
    select count(*) into v_early_count
    from public.arrivals
    where class_day_id = p_class_day_id and status = 'EARLY';

    if v_early_count >= v_target then
      update public.earlypass_rewards
      set unlocked_at = coalesce(unlocked_at, now())
      where class_day_id = p_class_day_id;
    end if;
  end if;

  return jsonb_build_object(
    'arrival_created', v_arrival_created,
    'attendance_created', v_attendance_created
  );
end;
$$;

revoke all on function public.record_classroom_checkin(uuid, uuid, uuid, public.arrival_status, public.attendance_status) from public;
grant execute on function public.record_classroom_checkin(uuid, uuid, uuid, public.arrival_status, public.attendance_status) to authenticated;
