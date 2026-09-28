-- EarlyPass weekly timetable migration.
-- Run once in Supabase SQL Editor after the main schema is installed.
alter table public.periods add column if not exists weekday smallint not null default 0;
alter table public.periods drop constraint if exists periods_classroom_id_position_key;
alter table public.periods drop constraint if exists periods_weekday_check;
alter table public.periods add constraint periods_weekday_check check (weekday between 0 and 7);
drop index if exists public.periods_classroom_id_position_key;
create unique index if not exists periods_classroom_weekday_position_key
  on public.periods(classroom_id, weekday, position);

-- Copy the existing shared schedule onto each weekday so edits stay day-specific.
insert into public.periods(classroom_id, position, weekday, name, subject, teacher_name, room, starts_at, ends_at)
select p.classroom_id, p.position, days.weekday, p.name, p.subject, p.teacher_name, p.room, p.starts_at, p.ends_at
from public.periods p
cross join generate_series(1,7) as days(weekday)
where p.weekday=0
on conflict (classroom_id, weekday, position) do nothing;

create table if not exists public.weekly_settings (
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  class_start time not null,
  early_window_minutes int not null default 15 check (early_window_minutes between 1 and 180),
  earlypass_target int not null check (earlypass_target > 0),
  updated_at timestamptz not null default now(),
  primary key (classroom_id, weekday)
);
alter table public.weekly_settings enable row level security;
drop policy if exists "members read weekly settings" on public.weekly_settings;
create policy "members read weekly settings" on public.weekly_settings for select using (
  exists (select 1 from public.classrooms c where c.id=classroom_id and public.is_school_member(c.school_id))
);
drop policy if exists "teachers manage weekly settings" on public.weekly_settings;
create policy "teachers manage weekly settings" on public.weekly_settings for all using (
  public.is_class_teacher(classroom_id)
) with check (public.is_class_teacher(classroom_id));
grant select, insert, update, delete on public.weekly_settings to authenticated;
