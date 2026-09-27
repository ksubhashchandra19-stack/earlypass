-- EarlyPass production foundation for Supabase (Postgres + Auth + Row Level Security)
-- Apply in the Supabase SQL Editor after reviewing your school's privacy requirements.
create extension if not exists pgcrypto;

create type public.app_role as enum ('STUDENT','TEACHER','ADMIN');
create type public.attendance_status as enum ('PRESENT','ABSENT','LATE','EXCUSED');
create type public.arrival_status as enum ('EARLY','ON_TIME','LATE');

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.classrooms (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  class_name text not null,
  section text not null,
  room text not null default '',
  class_start time not null default '08:30',
  early_window_minutes int not null default 15 check (early_window_minutes between 1 and 180),
  earlypass_target int not null default 25 check (earlypass_target > 0),
  access_code_hash text,
  created_at timestamptz not null default now(),
  unique (school_id, class_name, section)
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  role public.app_role not null,
  display_name text not null,
  student_id uuid,
  created_at timestamptz not null default now()
);

create table public.classroom_teachers (
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  primary key (classroom_id, user_id)
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  name text not null,
  roll_number text not null,
  student_code text not null,
  email text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, student_code),
  unique (classroom_id, roll_number)
);

alter table public.profiles add constraint profiles_student_id_fkey
  foreign key (student_id) references public.students(id) on delete set null;

create table public.periods (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  position int not null,
  name text not null,
  subject text not null default '',
  teacher_name text not null default '',
  room text not null default '',
  starts_at time not null,
  ends_at time not null,
  created_at timestamptz not null default now(),
  unique (classroom_id, position),
  check (ends_at > starts_at)
);

create table public.class_days (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  day date not null,
  reward text not null default 'Mystery Puzzle',
  created_at timestamptz not null default now(),
  unique (classroom_id, day)
);

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  class_day_id uuid not null references public.class_days(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  period_id uuid not null references public.periods(id) on delete restrict,
  status public.attendance_status not null,
  marked_by uuid not null references public.profiles(user_id),
  marked_at timestamptz not null default now(),
  note text,
  unique (class_day_id, student_id, period_id)
);

create table public.arrivals (
  id uuid primary key default gen_random_uuid(),
  class_day_id uuid not null references public.class_days(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  arrived_at timestamptz not null default now(),
  status public.arrival_status not null,
  recorded_by uuid not null references public.profiles(user_id),
  unique (class_day_id, student_id)
);

create table public.earlypass_rewards (
  id uuid primary key default gen_random_uuid(),
  class_day_id uuid not null unique references public.class_days(id) on delete cascade,
  target int not null check (target > 0),
  reward text not null,
  unlocked_at timestamptz
);

create or replace function public.is_class_teacher(target_classroom uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.classroom_teachers ct
    where ct.classroom_id = target_classroom and ct.user_id = auth.uid()
  ) or exists (
    select 1 from public.profiles p
    join public.classrooms c on c.school_id = p.school_id
    where p.user_id = auth.uid() and p.role = 'ADMIN'
      and c.id = target_classroom
  );
$$;

create or replace function public.is_school_member(target_school uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.profiles p
    where p.user_id = auth.uid() and p.school_id = target_school);
$$;

create or replace function public.my_student_id()
returns uuid language sql stable security definer set search_path = public
as $$
  select p.student_id from public.profiles p where p.user_id = auth.uid();
$$;

alter table public.schools enable row level security;
alter table public.classrooms enable row level security;
alter table public.profiles enable row level security;
alter table public.classroom_teachers enable row level security;
alter table public.students enable row level security;
alter table public.periods enable row level security;
alter table public.class_days enable row level security;
alter table public.attendance enable row level security;
alter table public.arrivals enable row level security;
alter table public.earlypass_rewards enable row level security;

create policy "school members read school" on public.schools for select using (public.is_school_member(id));
create policy "school admins update school" on public.schools for update using (
  exists (select 1 from public.profiles p where p.user_id=auth.uid() and p.school_id=id and p.role='ADMIN')
) with check (
  exists (select 1 from public.profiles p where p.user_id=auth.uid() and p.school_id=id and p.role='ADMIN')
);

create policy "school members read classrooms" on public.classrooms for select using (public.is_school_member(school_id));
create policy "assigned teachers manage classrooms" on public.classrooms for all using (public.is_class_teacher(id)) with check (public.is_class_teacher(id));

create policy "users read own profile" on public.profiles for select using (user_id=auth.uid());
create policy "admins read school profiles" on public.profiles for select using (
  exists (select 1 from public.profiles me where me.user_id=auth.uid() and me.school_id=school_id and me.role='ADMIN')
);

create policy "teachers read assignments" on public.classroom_teachers for select using (user_id=auth.uid() or public.is_class_teacher(classroom_id));
create policy "admins manage assignments" on public.classroom_teachers for all using (
  exists (select 1 from public.profiles p join public.classrooms c on c.school_id=p.school_id
    where p.user_id=auth.uid() and p.role='ADMIN' and c.id=classroom_id)
) with check (
  exists (select 1 from public.profiles p join public.classrooms c on c.school_id=p.school_id
    where p.user_id=auth.uid() and p.role='ADMIN' and c.id=classroom_id)
);

create policy "students read self or teacher reads roster" on public.students for select using (
  id=public.my_student_id() or public.is_class_teacher(classroom_id)
);
create policy "teachers manage roster" on public.students for all using (public.is_class_teacher(classroom_id)) with check (public.is_class_teacher(classroom_id));

create policy "members read periods" on public.periods for select using (
  exists (select 1 from public.classrooms c where c.id=classroom_id and public.is_school_member(c.school_id))
);
create policy "teachers manage periods" on public.periods for all using (public.is_class_teacher(classroom_id)) with check (public.is_class_teacher(classroom_id));

create policy "members read class days" on public.class_days for select using (
  exists (select 1 from public.classrooms c where c.id=classroom_id and public.is_school_member(c.school_id))
);
create policy "teachers manage class days" on public.class_days for all using (public.is_class_teacher(classroom_id)) with check (public.is_class_teacher(classroom_id));

create policy "students read own attendance, teachers read class" on public.attendance for select using (
  student_id=public.my_student_id() or exists (
    select 1 from public.class_days d where d.id=class_day_id and public.is_class_teacher(d.classroom_id))
);
create policy "teachers manage attendance" on public.attendance for all using (
  exists (select 1 from public.class_days d where d.id=class_day_id and public.is_class_teacher(d.classroom_id))
) with check (
  marked_by=auth.uid() and exists (select 1 from public.class_days d where d.id=class_day_id and public.is_class_teacher(d.classroom_id))
);

create policy "students read own arrivals, teachers read class" on public.arrivals for select using (
  student_id=public.my_student_id() or exists (
    select 1 from public.class_days d where d.id=class_day_id and public.is_class_teacher(d.classroom_id))
);
create policy "teachers manage arrivals" on public.arrivals for all using (
  exists (select 1 from public.class_days d where d.id=class_day_id and public.is_class_teacher(d.classroom_id))
) with check (
  recorded_by=auth.uid() and exists (select 1 from public.class_days d where d.id=class_day_id and public.is_class_teacher(d.classroom_id))
);

create policy "members read rewards" on public.earlypass_rewards for select using (
  exists (select 1 from public.class_days d join public.classrooms c on c.id=d.classroom_id
    where d.id=class_day_id and public.is_school_member(c.school_id))
);
create policy "teachers manage rewards" on public.earlypass_rewards for all using (
  exists (select 1 from public.class_days d where d.id=class_day_id and public.is_class_teacher(d.classroom_id))
) with check (
  exists (select 1 from public.class_days d where d.id=class_day_id and public.is_class_teacher(d.classroom_id))
);

grant usage on schema public to authenticated;
grant select, update on public.schools to authenticated;
grant select, insert, update, delete on public.classrooms, public.classroom_teachers,
  public.students, public.periods, public.class_days, public.attendance,
  public.arrivals, public.earlypass_rewards to authenticated;
grant select on public.profiles to authenticated;
grant execute on function public.is_class_teacher(uuid), public.is_school_member(uuid), public.my_student_id() to authenticated;

-- Provision the first school, classroom, teacher profile, and classroom_teachers
-- assignment using the SQL Editor / trusted admin tooling. Never let public signup
-- choose its own role. Do not expose the service role key in a browser.
