# EarlyPass

A class-focused attendance app built around a shared classroom board, with separate teacher and student accounts.

- Teacher accounts create a class, choose its join code, manage students and periods, mark attendance, and open the board in full-screen display mode.
- Student accounts use that code to join and see only their own attendance and early-arrival streaks.
- Account creation is free and does not require school-administrator approval. Supabase email confirmation may still be enabled for sign-in.
- The board shows collective progress and the class activity, never individual attendance or rankings.

## Publish

The project is a static web app and is published with GitHub Pages. It has no build command. Open [EarlyPass](https://ksubhashchandra19-stack.github.io/earlypass/).

## Supabase setup

The production account app uses Supabase Auth and the database. For a fresh project, run **supabase/schema.sql** and then **supabase/class-first-signup-migration.sql** in Supabase SQL Editor. Existing installations should run the class-first migration once after the schema. The weekly timetable migration is optional unless weekly timetable settings are needed.

The class-first migration adds self-service teacher class creation and student joining by class code. Existing signed-in accounts without a class profile can complete the one-time setup form after the migration is applied. Teachers can set or change their class join code in Settings.

Never put a Supabase service-role key in the static site. The browser uses only the publishable key configured in **supabase/config.js**. Email confirmation and email delivery depend on the Supabase Auth email settings.

See [Supabase setup notes](supabase/README.md) for account setup, daily goals, classroom-board check-ins, privacy, and optional Google Classroom integration. The separate [demo walkthrough](demo.html) uses local browser data and is not the production account app.
