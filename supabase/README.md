# Supabase setup (EarlyPass backend foundation)

The public GitHub Pages site is still the local-only prototype until its UI is connected to Supabase. This directory prepares the database access model; do not enter real student records in the current demo UI.

## Configure the database

1. In your Supabase project, open **SQL Editor → New query**.
2. Copy and run [schema.sql](./schema.sql).
3. Create your first teacher account in **Authentication → Users** (invite the account or enable the sign-in method you intend to use).
4. Using the SQL Editor, create the school, classroom, and teacher profile, then assign that teacher to the classroom in `classroom_teachers`. The teacher profile's `user_id` must match the Auth user's ID. Never expose a service-role key in the website.
5. Add classes, periods, and students after the teacher/class assignment exists.

The schema keeps role assignment out of public signup and applies Row Level Security to student, period, arrival, attendance, and reward data. Students can read only the student record linked to their profile and its attendance; assigned teachers manage their classes. School administrators provision accounts and assignments through trusted tooling.

## Still required before production use

The current frontend has not yet been migrated from browser-local demo state to Supabase Auth and database queries. The shared board PIN also requires a server-side validation/session flow before it can authorize writes. Do not treat the presence of these tables as completed authentication or as production approval for student data.

To finish the live application, the frontend needs Supabase sign-in, profile/role loading, teacher CRUD and attendance persistence, student self-only views, plus a protected board session. Verify each RLS policy with separate student, teacher, and admin test accounts before using real records.

## Browser credentials

A Supabase project URL and publishable (or legacy anon) key may be used by a browser only after policies are in place and tested. Never put a service-role/secret key in static files. Google Classroom sync remains a separately configured server-side OAuth integration; Demo Sync is not a real Google connection.
