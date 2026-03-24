# IRON LOG — Supabase Setup Guide (v2 — Social Features)

## Step 1: Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in (or create an account)
2. Click **New Project**
3. Choose your organization, give it a name (e.g., "Iron Log"), set a database password, and pick a region close to you
4. Click **Create new project** — wait ~2 minutes for it to spin up

## Step 2: Run the SQL Schema

1. In your Supabase dashboard, go to **SQL Editor** (left sidebar)
2. Click **New query**
3. Open `supabase_schema.sql` from this project and copy the entire contents
4. Paste it into the SQL Editor
5. Click **Run** — you should see "Success. No rows returned" for each statement
6. Verify: go to **Table Editor** in the sidebar — you should see these tables:
   - `profiles`, `body_metrics`, `exercises`, `workout_templates`, `workout_logs`
   - `workout_plans`, `plan_adoptions`, `progress_photos`
   - `workout_posts`, `post_likes`, `post_comments`, `notifications`

## Step 3: Create Storage Buckets

1. Go to **Storage** in the Supabase sidebar
2. Create 4 buckets with these exact names and settings:

| Bucket Name | Public | File Size Limit | Allowed MIME Types |
|---|---|---|---|
| `avatars` | Yes (public) | 2MB | `image/*` |
| `progress-photos` | Yes (public) | 5MB | `image/*` |
| `post-photos` | Yes (public) | 5MB | `image/*` |
| `exercise-photos` | Yes (public) | 5MB | `image/*` |

3. For each bucket, add a storage policy to allow authenticated uploads:
   - Click the bucket → **Policies** tab → **New Policy**
   - Choose "For full customization"
   - Policy name: `Allow authenticated uploads`
   - Allowed operation: `INSERT`
   - Target roles: `authenticated`
   - Policy definition: `true`
   - Click **Review** → **Save policy**

4. Add a SELECT policy for each public bucket:
   - Policy name: `Allow public reads`
   - Allowed operation: `SELECT`
   - Target roles: `public`
   - Policy definition: `true`

## Step 4: Configure Storage CORS

1. Go to **Storage** → **Settings** (gear icon)
2. Under **CORS Configuration**, add your GitHub Pages domain:
   ```json
   [
     {
       "origin": ["https://yourusername.github.io"],
       "methods": ["GET", "POST", "PUT", "DELETE"],
       "headers": ["*"],
       "maxAge": 3600
     }
   ]
   ```
3. Replace `yourusername` with your actual GitHub username
4. For local development, also add `http://localhost:*` as an origin

## Step 5: Configure Authentication

1. Go to **Authentication** → **Providers** in the Supabase dashboard
2. Make sure **Email** provider is enabled (it is by default)
3. (Optional) Under **Authentication** → **Settings**:
   - Disable "Confirm email" for faster testing (users can sign up without email verification)
   - Set the **Site URL** to your GitHub Pages URL

## Step 6: Get Your Supabase Credentials

1. Go to **Settings** → **API** in the Supabase dashboard
2. Copy the **Project URL** — it looks like `https://abcdefghijk.supabase.co`
3. Copy the **anon / public** key (under "Project API keys")

## Step 7: Add Credentials to the App

Open `index.html` and find these two lines near the top of the `<script>` section:

```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

Replace them with your actual values:

```javascript
const SUPABASE_URL = 'https://abcdefghijk.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

## Step 8: Deploy to GitHub Pages

1. Commit and push your changes:
   ```bash
   git add index.html supabase_schema.sql SETUP.md
   git commit -m "Add social features with Supabase storage"
   git push
   ```

2. If GitHub Pages isn't already enabled:
   - Go to your repo on GitHub → **Settings** → **Pages**
   - Under "Source", select your branch (usually `main`) and root `/`
   - Click **Save**
   - Your site will be live at `https://yourusername.github.io/workout-tracker/`

3. Go back to Supabase **Authentication** → **URL Configuration** and set:
   - **Site URL** to your GitHub Pages URL
   - Add it to **Redirect URLs** as well

## How It Works

### Core Features (unchanged)
- **First user to log in** automatically seeds the exercise database (~250 exercises)
- Each user gets their own workout templates, workout logs, and custom exercises
- Active workouts stored locally (localStorage) to survive page refreshes
- kg/lbs unit preference stored locally per browser

### Social Features (new)
- **Feed**: Public workout posts from all users with likes and comments
- **Search/Discover**: Find other athletes by name or username
- **Public Profiles**: View other users' public workout history, body metrics, progress photos, and plans
- **Workout Plans**: Create multi-week/day plans, share them publicly, others can adopt them
- **Progress Photos**: Upload progress photos with optional captions, control visibility via privacy settings
- **Avatar Upload**: Tap your profile avatar to upload a profile picture
- **Privacy Toggles**: Control what others can see (workout history, weight, body fat, progress photos)
- **Notifications**: Bell icon shows unread count; triggered by likes, comments, and plan adoptions (via database triggers)
- **Post-Workout Sharing**: After completing a workout, optionally share it to the feed with a caption and photos

### Storage Buckets
- `avatars` — Profile pictures (public, max 2MB)
- `progress-photos` — User progress photos (public if user's privacy allows)
- `post-photos` — Photos attached to workout posts (public)
- `exercise-photos` — Custom exercise demo photos (public)

## Troubleshooting

- **"Invalid API key"** — double-check you copied the `anon` key, not the `service_role` key
- **Can't sign up** — if email confirmation is enabled, check your inbox/spam for the confirmation link
- **File uploads failing** — check that storage CORS is configured for your domain and bucket policies allow authenticated uploads
- **Exercises not loading** — check the browser console for errors; ensure RLS policies were created correctly
- **Profile not created on signup** — the trigger may not have fired; re-run the trigger section of the SQL schema
- **Notifications not appearing** — ensure the notification triggers were created successfully in the SQL schema
- **Photos not displaying** — verify the storage bucket is set to public and the SELECT policy exists
