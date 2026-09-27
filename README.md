# EarlyPass

A responsive classroom attendance and early-arrival prototype. The shared classroom board is the primary experience; teacher and student views are separate previews.

## Run locally

Open `index.html` in a browser, or serve this folder with any static web server. The demo uses local browser storage and does not need a build step, account, or paid service. For offline support, open the app once from an HTTP(S) origin so the service worker can cache its assets.

## Demo credentials and flows

- Teacher workspace: default view. Select the account avatar to switch experiences.
- Student account: choose a sample student. This view is read-only and shows only that selected student's records.
- Classroom board: open **Classroom board → Launch board view** and enter the code shown in the teacher view (`8A-2026` initially).
- Demo controls: bottom-right panel can simulate arrivals, adjust the demo clock, advance periods, trigger the shared reward, and start a new day.
- Google Classroom: **DEMO / MOCK GOOGLE CLASSROOM** shows a course and roster import preview. It does not connect to Google.

## Publish with GitHub Pages

1. Create a GitHub repository and put the contents of this folder at the repository root (or configure Pages to use the `outputs/earlypass` folder through an appropriate publishing workflow).
2. In repository **Settings → Pages**, choose **Deploy from a branch**, then select the `main` branch and `/ (root)` directory.
3. Wait for the Pages deployment and open its public URL. HTTPS is needed for service worker/offline support.

The same static files can be deployed to Cloudflare Pages, Netlify, or Vercel without a build command; use this directory as the publish directory.

## Prototype boundaries and production work

The app is intentionally a static prototype. Accounts and roles are demo selectors, not authentication. Local storage is per browser/device and is not a shared classroom database. Classroom codes, attendance, and role restrictions are not secure against a user who can inspect or edit browser data. Use a trusted backend with authenticated sessions and server-side authorization before using real student records.

Real Google Classroom integration needs a Google Cloud project, Classroom API enabled, OAuth consent configuration, approved scopes, OAuth client credentials, and a secure server-side authorization-code/token exchange. Do not put a client secret or long-lived access token in static files. The demo flow is clearly marked and never claims to be connected to Google.

## Data and privacy

The initial roster has 25 fictional sample students. Attendance and settings remain in this browser until site data is cleared. Student dashboard selection is a demonstration of the intended personal view, not verified identity. The shared board displays collective counts only and does not list individual attendance.
