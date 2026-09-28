# EarlyPass account app and Supabase setup

The published root app now uses Supabase Auth and the database for teacher/student views. The local-only walkthrough is preserved at [demo.html](../demo.html). Demo data is not shared with authenticated accounts.

## Database setup

You said you ran [schema.sql](./schema.sql). That creates the tables and Row Level Security policies. It does not create user accounts or assign roles.

## Add the first teacher and class

1. In Supabase, open **Authentication → Users** and invite or create the teacher using the email they will use to sign in.
2. Copy the exact email address. In **SQL Editor → New query**, open [first-teacher-setup.sql](./first-teacher-setup.sql), replace `TEACHER_EMAIL`, `SCHOOL_NAME`, and `TEACHER_NAME`, then run it once.
3. The setup script creates a starter Class 8A schedule. Add real students from the authenticated app after signing in.
4. Set **Authentication → URL Configuration → Site URL** to `https://ksubhashchandra19-stack.github.io/earlypass/`. Add that URL and the exact `/earlypass/index.html` URL to the allowed redirect URLs for password reset.
5. Sign in at [EarlyPass](https://ksubhashchandra19-stack.github.io/earlypass/index.html). Use the invited teacher account and its password.

For additional classes, student accounts, or administrator accounts, a trusted school administrator must create their Auth user, matching profile row, and class assignment. Public self-signup is not used to choose roles. Students can read only the student record linked to their profile; they cannot mark or correct attendance.

## Weekly timetable and daily goals

The app includes a teacher **Weekly timetable** page for weekday-specific class start times, early-arrival windows, EarlyPass targets, and period schedules. To enable persistent weekly settings on an existing Supabase project, run [weekly-timetable-migration.sql](./weekly-timetable-migration.sql) once in **Supabase → SQL Editor** after the main schema. The migration copies your existing periods into each weekday so you can adjust days independently while keeping historical attendance intact. Then reload EarlyPass and open **Weekly timetable**.

## Account model and limitations

The browser uses the project's publishable key. The key is intentionally public; Row Level Security is the protection boundary. Never put a service-role or secret key in a static website.

The shared board can be opened from an authorized school account. A teacher uses the shared display to record a student's check-in for a period. Student views are read-only. The current board session uses teacher sign-in; classroom PIN-only guest access is not enabled yet.

Google Classroom remains a clearly labelled mock preview in the demo. Real OAuth/API sync requires a server-side token exchange and configured Google Cloud OAuth credentials. This static app does not claim a real Google connection.

The prototype does not include a dedicated backend service for rate-limited PIN sessions or Google OAuth. Do not use real student data until the school validates the account provisioning, access rules, privacy requirements, and actual deployed flow with separate student and teacher accounts.
