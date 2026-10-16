-- Add per-period check-in support without deleting existing attendance history.
-- Safe to run more than once in the Supabase SQL Editor.
alter table public.arrivals
  add column if not exists period_id uuid references public.periods(id) on delete set null;

alter table public.arrivals
  drop constraint if exists arrivals_class_day_id_student_id_key;

create unique index if not exists arrivals_class_day_student_period_key
  on public.arrivals(class_day_id, student_id, period_id);
