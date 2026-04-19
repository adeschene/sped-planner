# CLAUDE.md — sped-planner-staging

> Staging mirror of the production Rails app at `/home/alec/docker/sped-planner/`.
> Read `../sped-planner/CLAUDE.md` first — its **Environment**, **Production status**, and **Local Detail** sections apply here unchanged unless called out below.
> Parent context: `../CLAUDE.md` (docker hub), `/home/alec/vps-admin/CLAUDE.md` (VPS overview).

---

## Purpose

- Test changes — migrations, feature work, dependency bumps, Dockerfile edits — against a clone of real prod data before merging to `main` and pulling into `../sped-planner/`.
- Workflow: cut a branch off `staging` → implement + validate here → PR against `origin/main` (GitHub) → once merged, `git pull` in `../sped-planner/` and `docker compose up -d --build`.
- **Staging is not monitored.** `../monitor.sh` probes only `planner.oddbox.tech`. Staging being down is not an alert condition; do not rely on automated recovery.
- **Staging contains real user data cloned from prod.** Treat it with the same care as prod: don't paste logs publicly, don't share the DB dump, don't expose the app without auth.

## Session hygiene — synthesize at natural break points

At the end of a completed task, when work pauses for a couple of turns without meaningful progress, or when the user signals session close (handoff prompt request, explicit wrap-up), review recent context for anything worth memorializing. Default toward more-frequent-but-filtered updates rather than waiting until session end — pruning stale memories later is cheaper than failing to re-learn a lesson in a future session.

**Worth saving:**
- A rule emerged or was refined (e.g., the tier policy)
- A non-obvious gotcha was uncovered (load-bearing file, surprising invariant, unexpected tool behavior)
- A workflow became crystallized
- An error pattern was named

**Skip saving:**
- Recap of work already visible in git history
- Project minutiae obvious from reading the code
- One-off debugging notes that won't generalize

When uncertain, err toward writing. Update target: memory file if cross-session/behavioral, this CLAUDE.md if project-specific state or workflow.

## Sharing images from a local machine to the VPS

MobaXterm's left-pane SFTP browser is the reliable channel: drag the image from Windows Explorer into that pane and drop it in `/home/alec/claude-inbox/`. Tell Claude the filename; Claude reads it directly from that path.

Why not paste/drop into the Claude Code prompt: over SSH from Windows, the prompt gets the *local* Windows path (e.g., `C:\Users\...\screenshot.png`), which doesn't resolve on the VPS. Snipping Tool output sits only on the Windows clipboard until the SFTP transfer moves the file.

Housekeeping: periodically clear out `~/claude-inbox/` — no auto-prune.

## Key differences from prod

| Thing | Prod | Staging |
|---|---|---|
| Dir | `/home/alec/docker/sped-planner/` | `/home/alec/docker/sped-planner-staging/` |
| Compose project | `sped-planner` | `sped-planner-staging` |
| Containers | `sped-planner-{app,db}-1` | `sped-planner-staging-{app,db}-1` |
| Public hostname | `planner.oddbox.tech` | `planner-staging.oddbox.tech` |
| DB name | `planner_production` | `planner_production_staging` |
| DB user | `rails_user` | `rails_user_staging` |
| `postgres_data/` | own, do not share | own, do not share |
| `storage/` | own, do not share | own, do not share |
| Git branch deployed | `main` (+ uncommitted working-tree edits) | `staging` |
| Monitored | yes (`../monitor.sh`) | no |

Both `app` services are on the shared external `proxy_network` so NPM can reach either. `db` services stay on each project's private `internal` network.

## Git layout

- Origin remote points at the upstream GitHub repo (`https://github.com/adeschene/sped-planner.git`), same as prod.
- `staging` branch carries two commits on top of `main`:
  1. **Baseline: snapshot of prod working tree** — captures prod's uncommitted-but-deployed state so the staging image builds identically. When prod eventually commits those changes to `main`, this commit will become redundant and can be squashed/dropped on rebase.
  2. **Allow planner-staging.oddbox.tech host in production env** — the one real environmental divergence (`config.hosts` entry in `config/environments/production.rb`).
- Keep environmental divergence (staging-only host config, etc.) on the `staging` branch, not in the prod working directory.
- Cross-directory access from a staging session into `/home/alec/docker/sped-planner/` is allowed — see **Prod access policy** below for the rules.

## Prod access policy — tiered

The risk that matters is *which action* runs against prod, not *which directory* Claude is in. A blanket "never touch prod" rule creates session-switching friction and blocks useful automation (committing drift to `main`, running `git pull` + rebuild after a PR merges). Instead, three tiers:

### Tier 1 — free, no confirmation (inspection only)

- Read-only ops in either directory: `git status`, `git diff`, `git log`, file reads, `docker compose logs`, `tail /home/alec/docker/monitor.log`
- Any action in `/home/alec/docker/sped-planner-staging/` that doesn't restart containers or write to `postgres_data/` / `storage/`

### Tier 2 — confirm once per plan (write, but reversible)

- `git add` / `git commit` in `/home/alec/docker/sped-planner/`
- `git push origin <feature-branch>` from any directory
- Local branch rebases anywhere

Expected flow: Claude lays out the plan in full, user approves once, Claude executes the sequence without re-prompting per command.

### Tier 3 — always confirm, every single time (hard-to-reverse or takes prod down)

- `docker compose up -d --build` or any container start/restart/stop in `/home/alec/docker/sped-planner/`
- Any op touching `postgres_data/`, `storage/`, `.env`, or running DB commands against prod (`psql`, `pg_dump`, migrations, `db:reset`, `db:schema:load`)
- Destructive git: `git reset --hard`, `git clean -f`, `git checkout --`, `git branch -D`, `git push --force`
- **Any push to `main`** (including non-force pushes via admin bypass, `gh pr merge`, and `git push origin <any-branch>:main`) — the normal flow is PR + merge via the GitHub UI, and anything else crosses the protection gate using bypass privileges
- In-place edits to files in the prod directory (this shouldn't happen in normal flow — changes funnel through staging → PR → `git pull`)
- Any `rm` or `mv` in the prod directory

Expected flow: Claude describes the specific command and its blast radius, waits for explicit confirmation, then runs it. Each tier-3 action is a separate confirmation even within one plan.

### When in doubt, up-tier

Unrecognized action or ambiguous blast radius → treat as tier 3. Cost of one extra confirmation is low; cost of an unintended tier-3 action is high (monitor flap, lost uncommitted state, visible downtime).

## Deployment workflow — staging → main → prod

General shape: `branch off staging → validate here → rebase onto main → PR → merge → pull to prod → deploy`. Prod is never edited in place; it only ever pulls `main` and rebuilds.

### 1. Branch off `staging` and make changes

```bash
cd /home/alec/docker/sped-planner-staging
git checkout staging && git fetch origin
git checkout -b <feature-branch>
# edit, commit (small commits, one concern each — makes step 3 easier)
```

### 2. Validate on staging

```bash
docker compose up -d --build
# host-aware curl — plain localhost returns 403 due to host authorization
docker compose exec -T app curl -sI \
  -H "Host: planner-staging.oddbox.tech" \
  -H "X-Forwarded-Proto: https" \
  http://localhost:3000
docker compose logs app --since 5m | grep -iE "error|warn|fatal"
```

Staging is unmonitored — breaking it is cheap — but the DB is a real clone of prod, so behavior matches reality closely. Run the actual feature through the UI when possible, not just a healthcheck.

### 3. Rebase feature commits onto `main` before opening the PR

`<feature-branch>` was cut from `staging`, which sits two commits ahead of `main` (the "baseline snapshot" and the staging host-config commit — see the Git layout section). Those are staging-only and **must not** travel into the PR. Strip them off by replaying only the feature commits onto `main`:

```bash
git fetch origin
git rebase --onto origin/main staging <feature-branch>
# <feature-branch> now contains only your feature commits on top of main
git log --oneline origin/main..<feature-branch>    # sanity check the commit list
```

`git rebase --onto <newbase> <upstream> <branch>` replays `(upstream..branch)` onto `newbase`. Here that's "take the commits between staging and the feature branch (i.e. your work) and lay them on top of main."

### 4. Open and merge the PR

```bash
git push -u origin <feature-branch>
gh pr create --base main --title "..." --body "..."
```

Review + merge on GitHub. Squash vs merge-commit is a style call — no enforced convention yet.

### 5. Deploy to prod

```bash
cd /home/alec/docker/sped-planner
git pull
docker compose up -d --build
# compose command runs db:prepare on boot, which applies new migrations
# watch the monitor for 5-10 min afterward
tail -30 /home/alec/docker/monitor.log
```

If the monitor alerts via ntfy or the app container flaps, investigate before walking away. A bad migration is the usual culprit — the app container will restart-loop because `db:prepare` fails.

### 6. Resync `staging` to the new `main`

```bash
cd /home/alec/docker/sped-planner-staging
git checkout staging
git fetch origin
git rebase origin/main
# baseline-snapshot commit may drop out if prod's tree now matches main (good)
# host-config commit stays
```

Optional but good hygiene — otherwise the next feature branch cut from `staging` will be based on an increasingly stale picture of `main`.

### Exceptions to the flow

- **Prod hotfixes:** for active fires, branch directly off `main`, fix, merge, deploy, then backport to `staging` via rebase. Not worth the ceremony at current traffic — route through staging unless something is visibly broken for users right now.
- **Docs/comment-only changes:** safe to skip the staging validation rebuild; the rebase + PR + prod pull still applies.
- **Dockerfile or dependency changes:** always rebuild staging (step 2) even if the code change looks trivial — these have the highest blast radius on rebuild.
- **CI-only changes (`.github/workflows/`, test files, test fixtures):** validation happens in the PR's CI run, not on the staging container. Skip step 2 but do everything else. Prod deploy is still useful (keeps filesystem in sync) but has no runtime effect.

## CI and branch protection

- **Workflow:** `.github/workflows/test.yml` runs Minitest on PRs targeting `main`, pushes to `main`, and manual dispatch. Postgres 15 service container, Ruby read from `.ruby-version` (3.2.11), Bundler from `BUNDLED WITH` in Gemfile.lock.
- **Branch protection on `main`:** PR required, `test` check required, force-push and deletion disabled, admin bypass enabled (`enforce_admins: false`). Configured via Settings → Branches in the GitHub UI; inspect current rules with `gh api repos/adeschene/sped-planner/branches/main/protection`.
- **Admin bypass is a sharp tool.** Regular `git push` to `main` from the command line *will land* despite the PR and status-check requirements — the remote only emits a "Bypassed rule violations" warning. Force-push and branch deletion are blocked regardless. In practice this means: don't try to push to `main` from here as a "test" of protection, and don't let your fingers wander after a rebase that leaves you one-push-away from bypassing your own gates.
- **Load-bearing runtime invariant from CI setup:** `config/boot.rb` must have `require "bundler/setup"` *before* `require "logger"` / `require "yaml"` / `require "psych"`. Otherwise Ruby pre-activates the stdlib default `logger` gem before Bundler can route to the Gemfile-pinned version, and CI explodes with "already activated logger X.Y.Z" on GitHub Actions runners (the Docker image hides it because its bundle install changes gem search order). Don't "tidy up" boot.rb by moving those requires back to the top.

## Test coverage policy

Every PR that adds a feature or restructures an existing one must include a test plan that accounts for all affected code paths. This is not optional and is not implied by "the feature works" — it must be explicit.

**What counts as requiring a test plan:**
- New controller actions or routes → controller integration tests
- New model validations, associations, scopes, or methods → model unit tests
- Changes to an existing action's behavior (redirect target, status code, guard logic) → update or add the relevant test
- New user-facing flows → system test or integration test covering the golden path and key failure cases

**How to scope it:**
- State which test files are affected and what new cases are needed before writing code.
- If a bug is discovered and fixed during the PR (as happened with `render :edit` missing `status:` in ActivitiesController and NotesController), the fix and its test travel in the same commit.
- If existing tests would pass through the change untouched but no longer reflect the new behavior, update them — don't leave stale tests that give false confidence.

**What doesn't need a test:**
- Pure copy/wording changes with no logic
- CSS/layout-only changes
- Config or workflow changes with no runtime behavior (though CI changes should be validated by watching the run)

## Docker / host file sync for dependency changes

Code in this project is **not** volume-mounted into the container (only `./storage` is). That means `docker compose exec app bundle install` mutates the *container's* filesystem, not the host's — host `Gemfile` and `Gemfile.lock` stay untouched. To update dependencies and have the changes persist on the host (and make it to git):

```bash
# 1. Edit Gemfile on the host (use your editor / Edit tool)
# 2. Copy Gemfile into the container
docker compose cp Gemfile app:/app/Gemfile
# 3. Run bundle install (or bundle update <gem>) in the container
docker compose exec -T app bundle install       # or: bundle update <gem>
# 4. Copy the regenerated Gemfile.lock back to the host
docker compose cp app:/app/Gemfile.lock Gemfile.lock
# 5. git add Gemfile Gemfile.lock && git commit
```

Skipping step 2 or 4 leaves host and container out of sync — the container may report "installed" while the host's Gemfile.lock stays stale (or vice versa), and the next image rebuild will pick up whichever state `./.` happens to have. Always verify with `git diff Gemfile.lock` before committing that the expected version changes actually landed on the host.

## Refresh workflow — re-clone prod DB

When staging data drifts too far from prod (accumulated test activity, stale users, etc.), refresh the DB:

```bash
# From any directory
cd /home/alec/docker/sped-planner
docker compose exec -T db pg_dump --clean --if-exists --no-owner --no-privileges \
  -U rails_user -d planner_production \
  > /tmp/prod_dump.sql

cd /home/alec/docker/sped-planner-staging
docker compose stop app                                  # avoid mid-restore writes
docker compose exec -T db psql -U rails_user_staging \
  -d planner_production_staging < /tmp/prod_dump.sql
docker compose start app                                 # db:prepare reapplies any staging-only migrations
rm /tmp/prod_dump.sql
```

Flags matter:
- `-T` on `docker compose exec` avoids TTY allocation, which otherwise corrupts binary-safe output.
- `--no-owner --no-privileges` on `pg_dump` strips the `OWNER TO rails_user` and grant statements — without them, the restore errors out because `rails_user` doesn't exist in the staging DB.

## Refresh workflow — resync prod working-tree changes

If prod's working tree drifts (e.g., someone edits `Dockerfile` directly in prod without committing), rebase the staging baseline onto a fresh snapshot:

```bash
cd /home/alec/docker/sped-planner-staging
git checkout staging
# drop the old baseline commit, take a fresh one:
git reset --hard main
rsync -a --exclude='.git/' --exclude='.env' --exclude='postgres_data/' \
      --exclude='node_modules/' --exclude='log/*' --exclude='tmp/*' \
      --exclude='storage/*' --exclude='CLAUDE.md' --exclude='.claude/' \
      /home/alec/docker/sped-planner/ /home/alec/docker/sped-planner-staging/
git add -A && git commit -m "Baseline: refresh snapshot of prod working tree"
# then cherry-pick or re-apply the host-config commit
```

Do this before running `docker compose up -d --build` when the goal is to reproduce a prod issue.

## Schema gotcha (inherited from prod)

- `db/schema.rb` is pinned at `2021_01_24_092131`; the live DB is at `20260331202702`. **Do not run `bin/rails db:schema:load` on a fresh staging DB** — it would recreate an empty pre-users, pre-timeslots schema.
- Use `bin/rails db:migrate` or let the compose `command:` run `db:prepare` on boot. See `../sped-planner/CLAUDE.md` → "Schema & migrations — big gotcha" for background.

## Internal verification

```bash
# App responds to the staging host (expect 302 or 200, not 403):
docker compose exec -T app curl -sI \
  -H "Host: planner-staging.oddbox.tech" \
  -H "X-Forwarded-Proto: https" \
  http://localhost:3000

# Data matches prod (until staging drifts):
docker compose exec -T app bin/rails runner \
  'puts "a=#{Activity.count} u=#{User.count} t=#{Timeslot.count} n=#{Note.count}"'
```

A bare `curl http://localhost:3000` (no Host header) returns `403 Forbidden` — that's the host-authorization layer rejecting the `localhost` Host header, and it's the expected behavior, not a problem.

## Public exposure

- NPM proxy host for `planner-staging.oddbox.tech` → `sped-planner-staging-app-1:3000` must exist in NPM's web UI (`http://<vps>:81`). Not managed from this directory.
- DNS A record for `planner-staging.oddbox.tech` must exist at the registrar. Not managed from this directory.
- Until both are in place, staging is reachable only over the Docker network from other containers on `proxy_network`.

## Vestigial compose entry

`docker-compose.yml` carries an unused `nginx-proxy-manager_default` network declaration, inherited from prod. Kept as-is to stay a literal mirror of prod; safe to remove when prod removes it.

## First planned work

Prioritized backlog of issues flagged in `../sped-planner/CLAUDE.md`. Fix on a branch cut from `staging`, validate here, then PR to `main`. All of these exist in prod today; the point of staging is to let us touch them without blast radius.

### a. `sessions_controller.rb:14` — `:unreadble_entity` typo

**Problem:** Failed logins pass `status: :unreadble_entity` to `render`, which Rails doesn't recognize. Every bad login raises `ArgumentError: Unrecognized status code :unreadble_entity` instead of re-rendering the login form with the flash.
**Why it matters:** Users who fat-finger their password see a 500 page, not "Invalid email or password." The flash never renders.
**Fix:** Replace with `:unprocessable_entity` (HTTP 422).

### b. `docker-compose.yml` storage bind-mount path mismatch

**Problem:** Compose mounts `./storage:/rails/storage` but the Dockerfile `WORKDIR` is `/app`. Active Storage's local service writes to `Rails.root.join("storage")` = `/app/storage`, so the bind mount catches nothing. `/app/storage` currently holds only `.keep`.
**Why it matters:** Dormant today because no model uses `has_one_attached` / `has_many_attached`. The first time someone wires up attachments, every upload will be lost on the next `docker compose up -d --build`.
**Fix:** Change the mount to `./storage:/app/storage`. Safe to do now while there's no data at risk.

### c. Stale `db/schema.rb`

**Problem:** Schema file is pinned at `2021_01_24_092131`; the live DB is at `20260331202702`. `db:schema:load` on a fresh DB would miss `timeslots`, `users`, and the Active Storage tables. Caused by `config.active_record.dump_schema_after_migration = false` in `production.rb` plus no dev-side dump ever committed.
**Why it matters:** Any new contributor (or new deploy target) cloning the repo and running `db:setup` gets a broken schema. Recovery requires `db:migrate` from scratch.
**Fix:** Run `bin/rails db:schema:dump` against an up-to-date dev DB and commit the result. Optionally flip `dump_schema_after_migration` back on so the file stays current going forward.

### d. `bin/docker-entrypoint` references `/rails/tmp/pids/server.pid`

**Problem:** The Rails-generated Dockerfile entrypoint script assumes `WORKDIR /rails`, but this project uses `WORKDIR /app`. The script is also not invoked — compose's `command:` override supplies a replacement boot sequence.
**Why it matters:** Dead code with wrong paths. Low-severity, but it trips up anyone debugging container boot.
**Fix:** Either align the paths to `/app/tmp/pids/server.pid` or delete the script entirely if nothing invokes it. Verify no CI or tooling references it before deleting.

### e. Hardcoded `172.19.0.2` in `config.hosts`

**Problem:** `config/environments/production.rb` adds the literal IP `172.19.0.2` to `config.hosts`. This is the current internal address of `nginx-proxy-manager-app-1` on `proxy_network`. Docker may renumber bridge networks on recreate.
**Why it matters:** If the IP changes, NPM's upstream requests will be rejected by Rails' host authorization with a 403 — the same symptom as a misconfigured proxy, easy to misdiagnose.
**Fix:** Replace the hardcoded IP with a regex/CIDR entry covering the `proxy_network` subnet (Docker's default for user-defined bridges is `172.19.0.0/16`), or drive the extra host from an env var set in `.env`.

### f. `RAILS_MASTER_KEY` commented out but `credentials.yml.enc` exists

**Problem:** `.env` has `#RAILS_MASTER_KEY=` and `production.rb` has `# config.require_master_key = true`. Yet `config/credentials.yml.enc` is committed. The app runs fine because nothing reads encrypted credentials, but the encrypted file is unused dead weight.
**Why it matters:** Future contributor sees `credentials.yml.enc`, assumes it's load-bearing, trips over the missing master key. Or someone adds a secret to the encrypted file thinking it'll be read, and it silently isn't.
**Fix:** Either populate the master key, uncomment `config.require_master_key`, and use the encrypted credentials for secrets; or delete `config/credentials.yml.enc` and keep `.env` as the single source of truth. Current `.env`-only approach is simpler — deletion is probably the right move.

### g. Legacy webpacker / Fly.io residue

**Problem:** `babel.config.js`, `postcss.config.js`, `config/webpacker.yml`, `@rails/webpacker` in `package.json`, `app/javascript/packs/`, `bin/webpack*`, and `fly.toml` are all vestiges of an older toolchain. Current pipeline is importmap-rails + dartsass-rails + Docker-on-VPS.
**Why it matters:** Dead code confuses future work. `package.json` drags unnecessary deps on every `yarn install`.
**Fix:** Remove in a single commit once staging confirms `docker compose up -d --build` still produces a working image. Low risk — `.dockerignore` already excludes `node_modules`, and nothing in the live asset pipeline references these files.

### h. Active Storage update migrations marked `up` with no base tables

**Problem:** Surfaced while refreshing `db/schema.rb` (item c). Three Active Storage update migrations (`20260307202709`, `20260307202710`, `20260307202711`) are marked `up` in `schema_migrations`, yet the dump contains no `active_storage_blobs` / `active_storage_attachments` / `active_storage_variant_records` tables. The base `active_storage:install` migration appears to have never run (or to have run as a no-op), so the update migrations landed on a schema that never had the underlying tables.
**Why it matters:** Dormant today — no model uses `has_one_attached` / `has_many_attached`. The first contributor to wire up attachments will hit "relation does not exist" errors and have to unwind why the update migrations are marked done but the tables are missing.
**Fix:** Investigate whether the three update migrations actually executed or silently no-op'd. Then either run `bin/rails active_storage:install` followed by the updates in order, or accept the current state and document it for whoever turns on attachments first. Re-dump schema afterward.

### i. `yarn.lock` still carries the webpacker dependency tree

**Problem:** Leftover from item (g). Removing `@rails/webpacker` and `webpack-dev-server` from `package.json` did not touch `yarn.lock`, which still pins the full webpack/babel/terser tree.
**Why it matters:** Zero runtime impact — `.dockerignore` excludes `node_modules`, so yarn never runs during image build — but the lockfile misrepresents the real dependency closure and will mislead anyone running `yarn install` locally.
**Fix:** Regenerate with `yarn install` on a machine that has Node/yarn, or delete `yarn.lock` and let whoever next needs it regenerate.

### j. `app/javascript/channels/` orphaned after pack removal

**Problem:** The `channels/` directory contained `index.js` and `consumer.js`, imported via `import "channels"` from the deleted `app/javascript/packs/application.js`. No other code references it. `config/cable.yml` still configures an ActionCable adapter, but there are no JS consumers.
**Why it matters:** Dead code with a "this looks intentional" shape, which is worse than obviously-dead code. Future contributor might try to use it and waste time figuring out why the channel never connects.
**Fix:** Delete `app/javascript/channels/` if ActionCable isn't planned, or wire it up through importmap (`pin "channels", to: "channels/index.js"` + equivalent for consumer) if it is.
