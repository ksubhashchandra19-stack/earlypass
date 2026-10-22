# EarlyPass class account setup

The published app is a class-focused product. It has no school-administrator approval step and no administrator signup option.

## One-time database setup

The existing database should have **schema.sql** applied. Run [class-first-signup-migration.sql](./class-first-signup-migration.sql) once in **Supabase → SQL Editor** after the schema. It adds the secure account-setup function and daily goal fields needed by the published app. You do not need paid Google Cloud or a paid database for this flow.

After the migration:

1. Open EarlyPass and choose **Create account**.
2. Choose **Teacher / classroom** to create a class and share a join code, or **Student** to join with the code from the teacher.
3. Confirm email if Supabase has email confirmation enabled, then sign in. There is no administrator approval.
4. A teacher from an older signup can sign in and complete the one-time setup form. Existing teachers can set or change their student join code in **Settings**.

Supabase email confirmation may still be enabled. If it is, signup confirmation messages require working email delivery/SMTP. This is separate from classroom approval.

## Self-service account details

Students and teachers can open **My account** to change their own name, sign-in email, and password at any time. Email changes may require confirmation. Student ID, roll number, and class membership remain teacher-managed. Run [account-profile-migration.sql](./account-profile-migration.sql) once in **Supabase → SQL Editor** to enable safe name updates and keep a student roster email in sync after email confirmation.

## Attendance, daily goals, and board mode

Teachers mark attendance for every period in **Attendance**. The default daily EarlyPass target follows the number of students marked Present or Late in Period 1; before attendance has been marked, it falls back to the active class roster. The teacher can override the minimum for that day. Each new day gets its own target and a rotating class activity.

From the teacher account, open **Classroom board** and choose **Board display** for a large full-screen view. **Record arrivals** allows the teacher to select multiple students at once. Only arrivals before the configured early cutoff increase the EarlyPass count.

If the minimum is missed after class start, the teacher can open a private follow-up review. It lists only students marked Present or Late in Period 1 who did not check in early; absent and excused students are excluded. The review is private to the teacher and does not put individual records on the board.

Student accounts have a separate, read-only dashboard with their attendance and early-arrival streak. Students cannot edit attendance or see another student's private records.

## Student login accounts for teacher-added and Google Classroom students

Teacher-added students need an email address. When the teacher adds a student or syncs a Google Classroom roster, EarlyPass can create a separate Student login using the student's email as the username. Students who joined the class themselves keep their existing account and password; provisioning checks for an already-linked student account and never resets it.

Student logins use the initial password chosen in Supabase Edge Function Secrets under `STUDENT_DEFAULT_PASSWORD`. Keep that value private. The app requires provisioned students to change it at their first sign-in. The service-role key is never placed in the browser or this repository.

### One-time Supabase function setup

1. In the Supabase Dashboard for project `wnhuzltyhfnmxanawown`, open **Edge Functions → Secrets** and add `STUDENT_DEFAULT_PASSWORD` with the requested first-password value. Do not commit it to GitHub.
2. Install the Supabase CLI and open a terminal in a local copy of this repository. Run:

   ```text
   npx supabase login
   npx supabase link --project-ref wnhuzltyhfnmxanawown
   npx supabase functions deploy provision-student --project-ref wnhuzltyhfnmxanawown
   ```

   The function source is [here](./functions/provision-student/index.ts), and `supabase/config.toml` enables JWT verification.
3. GitHub Pages and the Supabase Edge Function deploy separately. Student logins work after both deployments and after the private secret is saved.

The Edge Function checks that the caller is the assigned teacher, creates an email-confirmed Student Auth account, and links its profile to the class roster record. If the email already belongs to another unlinked account, EarlyPass leaves it unchanged and reports the conflict.

## Weekly timetable and Google Classroom

The teacher **Weekly timetable** page supports day-specific goals and period schedules. If the timetable migration is not already installed, run [weekly-timetable-migration.sql](./weekly-timetable-migration.sql).

The teacher Settings page can connect a real Google Classroom OAuth Web Client ID and preview/sync a roster when Google OAuth and Classroom API are configured. Without those credentials, the app must not claim a real Google connection. Google Classroom remains optional and does not replace EarlyPass.

## Legacy manual setup

[First teacher setup](./first-teacher-setup.sql) is a legacy manual provisioning script for an existing Supabase Auth user. New classes should use the free in-app teacher signup. If you already used the legacy script, open teacher Settings and set a class join code before students try to join.

The database still keeps school/class ids internally for data isolation and Row Level Security, but teachers manage their own class. Do not expose a service-role key in the browser.
