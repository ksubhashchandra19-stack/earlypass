-- Permanently remove a student account and all linked class records.
-- Run once in Supabase SQL Editor before using "Delete permanently" in EarlyPass.
create or replace function public.delete_class_student(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, extensions
as $$
declare
  v_classroom_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Please sign in first.';
  end if;

  select classroom_id into v_classroom_id
  from public.students
  where id = p_student_id;

  if v_classroom_id is null then
    raise exception 'Student record not found.';
  end if;

  if not public.is_class_teacher(v_classroom_id) then
    raise exception 'Only this class teacher can permanently delete this student.';
  end if;

  -- Remove any linked student login and its profile, including stored display names.
  delete from auth.users u
  using public.profiles p
  where p.user_id = u.id
    and p.student_id = p_student_id
    and p.role = 'STUDENT';

  -- Cascades remove attendance and period check-ins for this student.
  delete from public.students
  where id = p_student_id
    and classroom_id = v_classroom_id;
end;
$$;

revoke all on function public.delete_class_student(uuid) from public;
grant execute on function public.delete_class_student(uuid) to authenticated;
