# Isolated Windows DAS qualification setup

This script is for the **local Windows machine that runs DAS**. GitHub API access
cannot operate that local machine or connect the running DAS supervisor to a
new project. No changes to the existing DAS or Gleaner database are needed.

## Requirements

- A checkout of the DAS source on the local PC, with Node.js and pnpm installed
  and dependencies already installed there.
- PowerShell 7 (`pwsh`), Git, Node.js, pnpm and Docker Desktop with Linux
  containers running.
- An unused local TCP port 55437; a disposable PostgreSQL container named
  `das-testing-qualification-db` must not already exist.
- No existing file at
  `$env:LOCALAPPDATA\DAS-Testing-Qualification\connection.ps1`.
- The fixture checkout must be on `main` and have the exact expected GitHub
  HTTPS `origin` URL; the script refuses any other remote.

## Run on the local DAS machine

From the cloned **DAS-Testing** repository:

```powershell
pwsh -File .\scripts\prepare-isolated-das.ps1 -DASPath 'D:\path\to\DAS' -TestingPath 'D:\DAS-Testing'
```

Replace `D:\path\to\DAS` with the actual existing DAS source checkout path.
If the test repository is not already at `D:\DAS-Testing`, the script clones
that GitHub repository. This script has not been executed against the user's
Windows machine.

The script validates the fixture, starts **a newly created container** with
a randomly generated password, binds PostgreSQL to **127.0.0.1:55437 only**,
runs DAS migrations on **that specific database**, registers `das-testing`
there, sets the canonical remote and checkout binding, and runs
`das project doctor`. It refuses to attach to or replace an existing
container of the same name.

It deliberately clears the ambient `SUPABASE_DAS_TEST_DATABASE_URL` and
overrides `DAS_DATABASE_URL` only for its own process and CLI children.
It never starts the worker, a provider or an autonomous task, and never
creates a release or approval.

If validation fails, it stops the new disposable container and exits
nonzero. On successful registration, it writes a **local-only** PowerShell
connection file containing the temporary disposable database URL. Do not
commit this file or send its contents to ChatGPT.

## Subsequent commands

In the **same configured local test environment**, use the connection file
for subsequent isolated DAS CLI invocations:

```powershell
. "$env:LOCALAPPDATA\DAS-Testing-Qualification\connection.ps1"
# In your DAS source checkout:
pnpm exec tsx src/cli/index.ts project list
pnpm exec tsx src/cli/index.ts project doctor das-testing
```

When finished:

```powershell
docker stop das-testing-qualification-db
```

The database uses `docker run --rm` with no persistent data volume;
stopping the container **deletes the rehearsal database**. The local
connection file must then be deleted before a fresh setup.

## Live rehearsal remains a separate authority gate

The registration script is a preparation step only. Task `TASK-001.md`
is currently a **proposal**, not an approved DAS task. A real unattended
rehearsal requires an explicitly authorized task/plan and worker, a provider
configured on the local machine, a bounded execution budget, and acceptance
and release evidence. The interruption/recovery procedure must run only
against the isolated test project and be recorded, rather than inferred from
green GitHub CI.
