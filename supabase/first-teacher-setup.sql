-- Bootstrap one teacher and one classroom for the EarlyPass prototype.
-- Before running, create/invite the teacher in Supabase Authentication → Users.
-- Replace the three ALL-CAPS values below. Run only once for this school/class.
do $$
declare
  v_user_id uuid;
  v_school_id uuid;
  v_classroom_id uuid;
begin
  select id into v_user_id from auth.users where email = 'TEACHER_EMAIL';
  if v_user_id is null then
    raise exception 'No Auth user found for TEACHER_EMAIL. Create/invite that user first.';
  end if;

  insert into public.schools(name) values ('SCHOOL_NAME')
    returning id into v_school_id;

  insert into public.classrooms(
    school_id, class_name, section, room, class_start,
    early_window_minutes, earlypass_target
  ) values (
    v_school_id, '8', 'A', 'Classroom 3', '08:30', 15, 25
  ) returning id into v_classroom_id;

  insert into public.profiles(user_id, school_id, role, display_name)
  values (v_user_id, v_school_id, 'TEACHER', 'TEACHER_NAME');

  insert into public.classroom_teachers(classroom_id, user_id)
  values (v_classroom_id, v_user_id);

  insert into public.periods(classroom_id, position, name, subject, starts_at, ends_at, teacher_name, room)
  values
    (v_classroom_id, 1, 'Period 1', 'Mathematics', '08:30', '09:15', 'TEACHER_NAME', 'Classroom 3'),
    (v_classroom_id, 2, 'Period 2', 'English', '09:15', '10:00', 'TEACHER_NAME', 'Classroom 3'),
    (v_classroom_id, 3, 'Period 3', 'Science', '10:00', '10:45', 'TEACHER_NAME', 'Classroom 3'),
    (v_classroom_id, 4, 'Period 4', 'Social Studies', '11:00', '11:45', 'TEACHER_NAME', 'Classroom 3');
end $$;
