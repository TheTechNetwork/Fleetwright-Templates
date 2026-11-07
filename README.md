# Fleetwright templates

A starter for the repository a Fleetwright session reads when somebody asks it
to adopt a preset, install a skill or reuse a workflow. Make your own from it,
link it, and what it holds is one `git clone` away from every session you
start, with nothing pasted.

**A template to start from, not a repository to fork, on purpose.** A fork of
a public repository stays public and stays tied to this one; a repository made
with **Use this template** is yours outright, with its own history, and may be
**private** from its first commit. A templates repository is where skills that
name internal systems end up, so that choice has to be open.

The design and the reasoning are in [`docs/linked-repos.md`](https://github.com/TheTechNetwork/Fleetwright/blob/main/docs/linked-repos.md#templates-and-the-bound-that-did-not-move)
in the Fleetwright repository. This file is the setup.

## Make yours

1. **Use this template**, at the top of this page, then **Create a new
   repository**. Public or private, your call ([which](#public-or-private)):
   a template copy may be private where a fork may not, which is why this is
   a template.
2. Install the Fleetwright GitHub App on the repository's owner and select the
   repository. Contents **read** is all a templates repository needs, and it is
   in what the App asks for.
3. In the Fleetwright app, under **You › Linked repositories › Templates**,
   enter it and press **Check and save**. The check says whether it is public,
   that it is readable, and which of `.claude`, `.github` and `default.json`
   it carries.
4. Put your own owner where this one says `TheTechNetwork/Fleetwright-Templates`:
   `renovate.json` here, and the `extends` line [below](#the-renovate-preset).

```
default.json                        a Renovate preset other repositories extend
.claude/skills/antislop*/           six vendored skills: rules for interfaces that do not look generated
.claude/skills/security-audit/      Cloudflare's security-audit skill, vendored
.claude/skills/test-audit/          a test authoring gate and audit workflow, adapted from openclaw's
.claude/skills/adopt-renovate-preset/   one skill of our own, the way Claude Code reads one
.claude/agents/<name>.md            one subagent
.claude/commands/<name>.md          one slash command
.claude/settings.json               shared settings only: no credentials, nothing machine-specific
.github/ISSUE_TEMPLATE/, PULL_REQUEST_TEMPLATE.md
.github/workflows/check.yml         checks all of the above; runs in this repository only
renovate.json                       this repository extending its own preset
```

The three top-level names are load-bearing: `src/core/linked-repo-check.js`
in Fleetwright names `.claude`, `.github` and `default.json` as the shapes a
templates repository is recognised as carrying, and the linking screen names
whichever of them it finds. Anything else in the repository is readable too;
it is just not named there.

## What a link does, and does not do

A templates link is **stored, checked for readability and shown**. Nothing in
it is turned into a task profile, typed into a session, or run. A session
reads it when somebody asks it to, in words:

> Clone TheTechNetwork/Fleetwright-Templates and vendor its
> `.claude/skills` into this project's `.claude/`.

That is deliberate, and the reasoning is in the design document linked above:
files in a repository that became profiles would move the bound on what a
session is told to do from "somebody with a shell on the box" to "somebody
with write access to that repository", for every box at once. So what a
session reads is what it was asked to read.

Reading it needs nothing new. On a permanent box a session's `git` asks the
credential broker, which answers with your own GitHub token; on a runner the
broker mints a one-repository token for it.

## Using what is in it

**The Renovate preset.** In another repository's `renovate.json`:

```json
{ "extends": ["github>TheTechNetwork/Fleetwright-Templates"] }
```

It carries the policy from Fleetwright's own `renovate.json` and none of the
facts about that one project: pin everything, let a release soak three days,
never hold a security fix, group and automerge Actions on patch and minor.
`default.json` says why for each. Renovate reads a `github>` preset from a
public repository; a private one works only where the Renovate you run can
read it.

**`.claude`, for one person.** Nothing inherits this directory on its own, and
no `.claude` repository is special to GitHub or to Claude Code; it is a
convention for keeping shared configuration in one place and pulling it in on
purpose. Into `~/.claude`, which affects every project on that machine:

```sh
git clone --depth 1 https://github.com/TheTechNetwork/Fleetwright-Templates /tmp/templates
cp -R /tmp/templates/.claude/skills/.   ~/.claude/skills/
cp -R /tmp/templates/.claude/agents/.   ~/.claude/agents/
cp -R /tmp/templates/.claude/commands/. ~/.claude/commands/
```

`settings.json` is left out of that on purpose: merge its keys into your own
rather than replacing a file that may hold your model choice and permissions.

**`.claude`, vendored into one project.** The same three copies with the
project's `.claude/` as the destination, which affects that project only. The
`/vendor-templates owner/repo` command in `.claude/commands` does exactly this,
asking before it replaces a file that differs.

**The vendored skills.** Three sets, each under a licence that allows the
copy, each **pinned to a commit and brought up to date by a person reading
the diff**, never fetched by an agent at session start. An agent that pulls
its own rules from the network is an agent whose rules changed with nobody
reviewing the change.

| skills | from | pinned at | what they are for |
|---|---|---|---|
| `antislop`, `-ui`, `-copywriting`, `-human`, `-layoutmobile`, `-code` | [miqdadbadjuber/anti-slop](https://github.com/miqdadbadjuber/anti-slop) (MIT) | release 3.2.21, `439a2ef`; `antislop/VENDORED.md` | keeping generated interfaces, copy and comments from looking generated. The core loads always; the others by task. It expects a `DESIGN.md` for direction, and that is a fact about one product, so none is here |
| `security-audit` | [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) (MIT) | `c1c8a8c`; `security-audit/VENDORED.md` | guidance for a focused security question, and a six-phase audit with independent verification when one is asked for by name. Its validators run with `node` alone |
| `test-audit` | [openclaw/openclaw](https://github.com/openclaw/openclaw) `.agents/skills/test-audit` (MIT), adapted | the note at the top of its `SKILL.md` | the four questions every new test answers before it is written, and sweeps of tests that re-assert source or pin an implementation. Read `CAMPAIGN.md` before pruning a whole subsystem's tests |

Each `VENDORED.md` says how to update: copy the upstream directory over this
one, keep `LICENSE` and the note, change the commit, and read the diff like
any other code. `antislop-human/SKILL.md` carries one local change, recorded
there, and it has to be re-applied on every update.

**`.github`.** Copy the issue forms and the pull request template into a
repository's `.github/`. `check.yml` is this repository's own: it runs only
when `github.repository` is this one, so a copy carries it without spending a
run on it.

## Public or private

Either links, and the check says which it found. A Renovate preset has to be
readable by the Renovate that extends it, which for the hosted app means
public; a repository of skills that name internal systems should not be. If
you need both, make two and link the one sessions should read.

## Keeping it up to date

GitHub does not update a repository made from a template. When this one
changes, copy what changed into yours. Nothing in Fleetwright refuses an old
copy: a templates repository is read, never dispatched into, so there is no
422 here as there is for a runner repository.
