# CLAUDE.md — sped-planner

> One repo, two VPS deploy directories: production at `/home/alec/docker/sped-planner/`, staging mirror at `/home/alec/docker/sped-planner-staging/`.
> Parent context: `../CLAUDE.md` (docker hub overview), `/home/alec/vps-admin/CLAUDE.md` (VPS overview).
> This file is tracked in git and lands in both directories on `git pull` — keep it environment-agnostic.

---

## Environments at a glance

| Thing | Prod | Staging |
|---|---|---|
| Dir | `/home/alec/docker/sped-planner/` | `/home/alec/docker/sped-planner-staging/` |
| Compose project | `sped-planner` | `sped-planner-staging` |
| Containers | `sped-planner-{app,db}-1` | `sped-planner-staging-{app,db}-1` |
| Public hostname | `planner.oddbox.tech` | `planner-staging.oddbox.tech` |
| DB name | `planner_production` | `planner_production_staging` |
| DB user | `rails_user` | `rails_user_staging` |
| `postgres_data/` | own, do not share | own, do not share |
| Git branch deployed | `main` (+ uncommitted working-tree edits) | `staging` |
| Monitored | yes (`../monitor.sh`) | no |
| Real user data | yes | yes — cloned from prod, treat identically |

Both `app` services are on the shared external `proxy_network`. `db` services stay on each project's private `internal` network.

---

## What the app is

A teacher's daily/weekly/monthly planner. Users log in, create **Activities** (title + date + block), assign them to a **Timeslot** (labeled block of the day), and attach free-form **Notes** to each activity. Views: month, week, day, per-activity show/edit, and a settings page for managing timeslots and theme preferences.

Identity note: the Ruby module is `MomPlanner` (`config/application.rb`), `package.json` name is `mom-planner`, `fly.toml` app name is `sped-planner` — the project was renamed over time. `fly.toml` is historical (prior Fly.io deploy); current deploy is Docker on this VPS.

---

## Stack

- **Ruby 3.2-slim** base image; Rails 7.1; Puma 6; PostgreSQL 15 Alpine.
- `config.load_defaults 6.1` despite Rails 7.1 gem — framework defaults were never bumped.
- `config.beginning_of_week = :monday`.
- **Frontend:** importmap-rails + Turbo (no Stimulus). `dartsass-rails` compiles SCSS to `app/assets/builds/`. Bootstrap 5.3.3 + Bootstrap Icons from jsDelivr CDN — not bundled.
- **Themes:** five per-user color themes (default/pink, garden, citrus, ocean, wildflower), persisted in `users.theme`, applied via `data-theme` on `<body>`. All palette values are CSS custom properties in `app/assets/stylesheets/application.scss`.
- **Auth:** hand-rolled `has_secure_password` (bcrypt) + cookie `session[:user_id]`. No Devise. No signup route — users created via the Rails console only. `ApplicationController` enforces `authenticate_user!` on every action.
- **Calendar:** `simple_calendar` gem (~> 3.0). Calendar SCSS lives in `app/assets/stylesheets/simple_calendar.scss`.
- **Legacy / unused:** `webpacker.yml`, `babel.config.js`, `postcss.config.js`, `@rails/webpacker`, `app/javascript/packs/`, `bin/webpack*`, `fly.toml` — vestiges of an older pipeline. Don't add to them.
- **Source baked into the image** — no code bind-mount. Any code change requires `docker compose up -d --build`. `docker compose restart app` does **not** pick up code changes.
- **Assets precompile at image build** with `SECRET_KEY_BASE_DUMMY=1`. A broken asset reference will fail the build, not boot.

---

## Domain model

| Table | Key fields | Notes |
|---|---|---|
| `activities` | `title`, `date`, `block:integer` | `block` matches `Timeslot#position` — **not** a FK to `timeslots.id` |
| `timeslots` | `label`, `position:integer` | `position` is unique; used as the join key |
| `notes` | `body`, `activity_id` | `belongs_to :activity`, `dependent: :destroy` |
| `users` | `email`, `password_digest`, `theme:string` | `has_secure_password`; `theme` defaults to `"default"` |

Non-standard association worth remembering:
```ruby
# app/models/activity.rb
belongs_to :timeslot, foreign_key: :block, primary_key: :position, optional: true
```

Deleting a `Timeslot` is blocked in the controller when `Activity.where(block: timeslot.position)` exists — application-level only, no DB FK.

---

## Routes

```
GET  /login, POST /login, DELETE /logout   → sessions
PATCH /theme                               → users#update_theme
GET  /                                     → activities#week (root)
GET  /activities/{day,week,month}          → named ..._view_path
     resources :activities do
       resources :notes, shallow: true
     end
     resources :timeslots, only: [index, create, update, destroy]
```

`ActivitiesController#{day,week,month}` default `start_date` to the next weekday (skipping Sat/Sun) when absent.

---

## Session hygiene — synthesize at natural break points

At the end of a completed task, when work pauses, or when the user signals session close, review recent context for anything worth memorializing. Default toward more-frequent-but-filtered updates rather than waiting until session end — pruning stale memories later is cheaper than failing to re-learn a lesson in a future session.

**Worth saving:** a rule emerged or was refined, a non-obvious gotcha was uncovered, a workflow became crystallized, an error pattern was named.

**Skip saving:** recap of work visible in git history, minutiae obvious from reading the code, one-off debugging notes that won't generalize.

Update target: memory file if cross-session/behavioral, this CLAUDE.md if project-specific state or workflow.

---

## Sharing images from a local machine to the VPS

MobaXterm's left-pane SFTP browser is the reliable channel: drag the image from Windows Explorer into `/home/alec/claude-inbox/`. Tell Claude the filename; Claude reads it directly from that path.

Over SSH from Windows, the Claude Code prompt gets the *local* Windows path (`C:\Users\...`), which doesn't resolve on the VPS. Snipping Tool output sits only on the Windows clipboard until the SFTP transfer moves the file.

Periodically clear out `~/claude-inbox/` — no auto-prune.

---

## Prod access policy — tiered

The risk that matters is *which action* runs against prod, not *which directory* Claude is in.

### Tier 1 — free, no confirmation (inspection only)

- Read-only ops in either directory: `git status`, `git diff`, `git log`, file reads, `docker compose logs`, `tail /home/alec/docker/monitor.log`
- Any action in the staging directory that doesn't restart containers or write to `postgres_data/` / `storage/`

### Tier 2 — confirm once per plan (write, but reversible)

- `git add` / `git commit` in `/home/alec/docker/sped-planner/`
- `git push origin <feature-branch>` from any directory
- Local branch rebases anywhere

Expected flow: Claude lays out the plan in full, user approves once, Claude executes the sequence without re-prompting per command.

### Tier 3 — always confirm, every single time (hard-to-reverse or takes prod down)

- `docker compose up -d --build` or any container start/restart/stop in `/home/alec/docker/sped-planner/`
- Any op touching `postgres_data/`, `storage/`, `.env`, or running DB commands against prod (`psql`, `pg_dump`, migrations, `db:reset`, `db:schema:load`)
- Destructive git: `git reset --hard`, `git clean -f`, `git checkout --`, `git branch -D`, `git push --force`
- **Any push to `main`** (including non-force pushes via admin bypass, `gh pr merge`, and `git push origin <any-branch>:main`) — the normal flow is PR + merge via the GitHub UI
- In-place edits to files in the prod directory (changes funnel through staging → PR → `git pull`)
- Any `rm` or `mv` in the prod directory

Each tier-3 action is a separate confirmation even within one plan. When in doubt, up-tier.

---

## Git layout

- Origin remote: `https://github.com/adeschene/sped-planner.git` — same repo, two local checkouts on the VPS.
- **`CLAUDE.md` is tracked in git** — `git pull` in prod updates it cleanly. Do not keep a hand-edited untracked `CLAUDE.md` in either directory; edit this file on a branch and let the PR flow carry it.
- `staging` branch carries two commits on top of `main`:
  1. **Baseline: snapshot of prod working tree** — captures prod's uncommitted-but-deployed state so the staging image builds identically.
  2. **Allow planner-staging.oddbox.tech host in production env** — `config.hosts` entry in `config/environments/production.rb`. This is a working-tree-only change when working off a branch cut from `main` rather than `staging`; it must **not** travel into PRs.
- Cross-directory access from a staging session into `/home/alec/docker/sped-planner/` is allowed — see the prod access policy above.

---

## Deployment workflow — staging → main → prod

General shape: branch off `staging` → implement + validate here → rebase onto `main` → PR → merge → pull to prod → deploy.

### 1. Branch off `staging`

```bash
cd /home/alec/docker/sped-planner-staging
git checkout staging && git fetch origin
git checkout -b <feature-branch>
# small commits, one concern each — makes the rebase in step 3 easier
```

### 2. Validate on staging

```bash
docker compose up -d --build
# host-aware curl — bare localhost returns 403 (expected, host auth layer)
docker compose exec -T app curl -sI \
  -H "Host: planner-staging.oddbox.tech" \
  -H "X-Forwarded-Proto: https" \
  http://localhost:3000
docker compose logs app --since 5m | grep -iE "error|warn|fatal"
```

If the branch was cut from `main` rather than `staging`, the `planner-staging.oddbox.tech` host entry won't be present in `production.rb`. Add it as an **uncommitted** working-tree change so it doesn't travel into the PR.

**Never run `bin/rails test` inside the staging container.** The container runs `RAILS_ENV=production`; the `POSTGRES_*` env vars point at `planner_production_staging`. Rails falls back to that connection when setting up the test DB, loads fixtures into it, and wipes all real data. Recovery requires a full prod DB restore. Tests belong in CI only.

### 3. Rebase feature commits onto `main` before the PR

If cut from `staging`: strip the two staging-only commits before opening the PR:
```bash
git fetch origin
git rebase --onto origin/main staging <feature-branch>
git log --oneline origin/main..<feature-branch>   # sanity check
```

If cut from `main`: a normal rebase suffices:
```bash
git fetch origin && git rebase origin/main
```

After either rebase, a force-push is needed since SHAs change:
```bash
git push --force-with-lease origin <feature-branch>
```

### 4. Open and merge the PR

```bash
git push -u origin <feature-branch>
gh pr create --base main --title "..." --body "..."
```

Review + merge on GitHub. Do **not** merge via `gh pr merge` from the command line — that uses admin bypass and skips the protection flow.

### 5. Deploy to prod

```bash
cd /home/alec/docker/sped-planner
git pull                          # CLAUDE.md is tracked; pulls cleanly
docker compose up -d --build      # db:prepare runs on boot, applies migrations
tail -30 /home/alec/docker/monitor.log
```

Watch the monitor for 5–10 min. A broken migration will cause the container to restart-loop; the monitor will flap within 5 min.

### 6. Resync `staging` to the new `main`

```bash
cd /home/alec/docker/sped-planner-staging
git checkout staging && git fetch origin
git rebase origin/main
# baseline-snapshot commit may drop out if prod's tree now matches main (good)
# host-config commit stays
docker compose up -d --build    # rebuild staging from the new main baseline
```

### Exceptions

- **Prod hotfixes:** branch directly off `main`, fix, merge, deploy, then backport to `staging`. Not worth staging ceremony for active fires.
- **Docs/comment-only changes:** skip the staging rebuild; rebase + PR + prod pull still applies.
- **Dockerfile or dependency changes:** always rebuild staging (step 2) even if the change looks trivial — highest blast radius.
- **CI-only changes** (`.github/workflows/`, test files, test fixtures): validation is the PR's CI run, not the staging container. Skip step 2.

---

## Docker / host file sync for dependency changes

Code is **not** volume-mounted — only `./storage` is. `docker compose exec app bundle install` mutates the *container's* filesystem; the host `Gemfile.lock` stays untouched. To update dependencies and persist on the host:

```bash
# 1. Edit Gemfile on the host
# 2. Copy into the container
docker compose cp Gemfile app:/app/Gemfile
# 3. Install in the container
docker compose exec -T app bundle install    # or: bundle update <gem>
# 4. Copy regenerated lock back to the host
docker compose cp app:/app/Gemfile.lock Gemfile.lock
# 5. Verify and commit
git diff Gemfile.lock
git add Gemfile Gemfile.lock && git commit
```

---

## CI and branch protection

- **Workflow:** `.github/workflows/test.yml` — Minitest on PRs targeting `main`, pushes to `main`, and manual dispatch. Postgres 15 service container, Ruby from `.ruby-version` (3.2.11), Bundler from `BUNDLED WITH` in `Gemfile.lock`.
- **DB setup:** `bin/rails db:test:prepare && bin/rails db:migrate` — schema load gives the base, migrate applies anything newer than the schema version. Any new migration file must be committed before CI will pass.
- **Branch protection on `main`:** PR required, `test` check required, force-push and deletion disabled, admin bypass enabled (`enforce_admins: false`). Regular `git push` to `main` from the command line *will land* despite the protection — the remote only emits a warning. Don't test this.
- **Load-bearing boot invariant:** `config/boot.rb` must have `require "bundler/setup"` *before* `require "logger"` / `require "yaml"` / `require "psych"`. Moving these requires causes "already activated logger X.Y.Z" on CI (the Docker image hides it). Don't tidy up `boot.rb`.

---

## Test coverage policy

Every PR that adds a feature or restructures an existing one must include an explicit test plan.

**Requires a test plan:**
- New controller actions or routes → controller integration tests
- New model validations, associations, scopes, or methods → model unit tests
- Changes to an existing action's behavior (redirect target, status code, guard logic) → update the relevant test
- New user-facing flows → system test or integration test covering the golden path and key failure cases

**How to scope it:** state which test files are affected and what new cases are needed before writing code. Bug fixes and their tests travel in the same commit. Update stale tests that no longer reflect new behavior.

**Doesn't require a test:** pure copy/wording changes, CSS/layout-only changes, config or CI-only changes (watch the CI run instead).

---

## Schema & migrations

- `db/schema.rb` is at version `20260331202702`. `config.active_record.dump_schema_after_migration = false` in `production.rb` prevents auto-updates — the file won't advance on its own.
- Any migration newer than the schema version is pending after a `db:schema:load` and needs `db:migrate`.
- **Do not run `db:schema:load` directly** — use `db:prepare` (compose boot command) or `db:migrate`. On staging, `db:prepare` on boot reapplies any pending migrations.
- To advance `schema.rb`: run `bin/rails db:schema:dump` against an up-to-date DB and commit the result.

---

## Container quirks

- **Storage bind-mount path mismatch (latent bug):** `docker-compose.yml` mounts `./storage:/rails/storage`, but `Dockerfile` sets `WORKDIR /app`. Active Storage writes to `/app/storage` — not the bind-mounted path. No data loss today (no `has_one_attached` in use), but **fix the mount to `./storage:/app/storage` before wiring up attachments**.
- **`bin/docker-entrypoint`** references `/rails/tmp/pids/server.pid` — unused in practice (compose `command:` overrides CMD). Harmless but misleading.
- **No `USER` directive** — app container runs as root. `postgres_data/` is owned by the postgres container UID (70 in Alpine); don't `chown` it from the host.
- **Vestigial `nginx-proxy-manager_default` network** in `docker-compose.yml` — inherited from prod, kept to stay a mirror. Safe to remove when prod removes it.

---

## Production config

- `config.force_ssl = true` + `config.assume_ssl = true` — Rails trusts NPM-terminated TLS. Accessing the container directly over plain HTTP without the `X-Forwarded-Proto: https` header triggers redirect loops.
- `config.hosts`: `planner.oddbox.tech` + `/\A172\.19\.\d+\.\d+\z/` (subnet regex covering `proxy_network`). Staging adds `planner-staging.oddbox.tech`. The subnet regex avoids the fragility of a hardcoded IP.
- `RAILS_MASTER_KEY` commented out in `.env`; `config.require_master_key` off. `credentials.yml.enc` exists but is unused — keep secrets in `.env`, not in encrypted credentials.
- Persistent state: `./postgres_data/` and `./storage/` — bind-mounted, survive image rebuilds.
- Secrets: `.env` (gitignored) holds `POSTGRES_USER/PASSWORD/DB`, `SECRET_KEY_BASE`, `DATABASE_URL`. Never commit; never echo.
- Logs go to STDOUT: `docker compose logs -f app`.

---

## Refresh workflow — re-clone prod DB into staging

When staging data drifts too far from prod:

```bash
cd /home/alec/docker/sped-planner
docker compose exec -T db pg_dump --clean --if-exists --no-owner --no-privileges \
  -U rails_user -d planner_production \
  > /tmp/prod_dump.sql

cd /home/alec/docker/sped-planner-staging
docker compose stop app
docker compose exec -T db psql -U rails_user_staging \
  -d planner_production_staging < /tmp/prod_dump.sql
docker compose start app    # db:prepare reapplies any pending migrations
rm /tmp/prod_dump.sql
```

`-T` avoids TTY corruption on binary output. `--no-owner --no-privileges` strips `OWNER TO rails_user` statements that would error in staging (user doesn't exist there).

---

## Refresh workflow — resync prod working-tree changes

If prod's working tree drifts from `main` (e.g., uncommitted `Dockerfile` edits), rebuild the staging baseline:

```bash
cd /home/alec/docker/sped-planner-staging
git checkout staging
git reset --hard main
rsync -a --exclude='.git/' --exclude='.env' --exclude='postgres_data/' \
      --exclude='node_modules/' --exclude='log/*' --exclude='tmp/*' \
      --exclude='storage/*' --exclude='CLAUDE.md' --exclude='.claude/' \
      /home/alec/docker/sped-planner/ /home/alec/docker/sped-planner-staging/
git add -A && git commit -m "Baseline: refresh snapshot of prod working tree"
# then re-apply the host-config commit
```

---

## Common tasks

```bash
# Tail app logs
docker compose logs -f app

# Shell in the app container
docker compose exec app bash

# Rails console
docker compose exec app bin/rails console

# Create a user (no signup flow)
docker compose exec app bin/rails runner \
  "User.create!(email: 'someone@example.com', password: '...')"

# DB console
docker compose exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

# Apply code changes (rebuild required — no code bind-mount)
docker compose up -d --build

# One-off migration (also runs on every boot via db:prepare)
docker compose exec app bin/rails db:migrate

# Check data counts
docker compose exec -T app bin/rails runner \
  'puts "a=#{Activity.count} u=#{User.count} t=#{Timeslot.count} n=#{Note.count}"'

# Staging: verify host responds (expect 302, not 403)
docker compose exec -T app curl -sI \
  -H "Host: planner-staging.oddbox.tech" \
  -H "X-Forwarded-Proto: https" \
  http://localhost:3000
```

---

## Known bugs

### Active (fix on next relevant PR)

**`sessions_controller.rb:14` — `:unreadble_entity` typo.** Failed logins render with `status: :unreadble_entity`, which Rails doesn't recognize, raising `ArgumentError`. Users who fat-finger their password see a 500 page instead of "Invalid email or password." Fix: `status: :unprocessable_entity`.

### Latent / low-priority backlog

| # | Issue | Notes |
|---|---|---|
| b | **Storage bind-mount path mismatch** (`./storage:/rails/storage` should be `./storage:/app/storage`) | Safe to fix now; no attachment data at risk |
| c | **`db/schema.rb` not auto-updated** (`dump_schema_after_migration = false`) | Run `db:schema:dump` + commit to advance; or flip the flag back on |
| d | **`bin/docker-entrypoint` references `/rails/` paths** — unused dead code | Delete or align to `/app` |
| f | **`credentials.yml.enc` committed but unused** — master key commented out | Delete the file or actually wire it up |
| g | **Legacy webpacker / Fly.io residue** — `babel.config.js`, `postcss.config.js`, `webpacker.yml`, `@rails/webpacker`, `app/javascript/packs/`, `bin/webpack*`, `fly.toml` | Remove in one commit after confirming staging builds cleanly |
| h | **Active Storage update migrations marked `up` but base tables missing** — AS install migration never ran | Investigate before wiring up any `has_one_attached` |
| i | **`yarn.lock` carries webpacker dep tree** | Zero runtime impact; regenerate or delete when convenient |
| j | **`app/javascript/channels/` orphaned** after packs removal | Delete if ActionCable isn't planned |
