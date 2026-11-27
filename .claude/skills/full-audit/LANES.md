# Lanes

One reviewer to a lane. These are shapes, not a list to run as it stands:
after stage 1 the parent names this repository's own lanes, one for each
layer a boundary separates, puts real paths in each, and adds what the
batch claims. [EXAMPLE-FLEETWRIGHT.md](EXAMPLE-FLEETWRIGHT.md) is what
that came to in the repository this was written in, with what each lane
found.

Each brief opens the same way:

```
Read <run directory>/COMMON.md in full first and follow it exactly.
Your lane is `<name>`. Your scratch directory is <scratch root>/<name>/.

Scope: <files you own, with the diff command that shows what changed>.

Background: <what was never run for real; what an earlier review found>.

What this batch claims, each of which you should try to break:
1. ...

Questions I most want answered, with evidence:
1. ...

Report as COMMON.md says.
```

Every lane also answers four questions, whatever else it is asked:

- **Two at once, and stopped half way.** For each thing in scope that
  changes state: two calls at once, a restart in the middle, a write that
  fails half way, a clock a minute wrong, a lock nobody releases.
- **Older and newer.** What an older peer on each side does with what
  this sends, and the reverse. Which merge order of the open pull
  requests is safe.
- **Secrets.** Plant a marked value where a credential goes and search
  for it everywhere it should not be: logs, records, events, error text,
  process arguments, an environment.
- **The tests.** Does each new test prove what its name says? Does the
  stand-in accept what the real thing would refuse? For the three most
  important regression tests: do they fail on the code before the fix?

---

## custody

Whatever holds credentials or keys, and whoever asks it for them.

1. For each kind of secret: who may read it, and is that checked where
   it leaves, against the record of who is allowed as it is at that
   moment?
2. Removal and return: remove then add the same identity again, two
   removals racing, a grant made in the same instant as the removal, a
   grant stamped by a client whose clock is behind, a row that fails to
   write half way. Does access ever come back?
3. Signed answers: are the signed bytes the same on both sides, byte for
   byte? Replay of an old answer to a new request, an answer signed for
   another recipient, rotation of the key, and where the verifier learns
   the public key. Could a less trusted party have written it?
4. New code on one side against old code on the other, both ways. Does
   the refusal say what to do?
5. Every refusal: a code, a sentence with a way out, and no secret.

## server

The service that takes requests and keeps state, and every way in to it.

1. Authorisation. For every operation: who may call it, and is that
   checked where the action happens? Can somebody act on what is not
   theirs, approve their own request, raise their own limit, or read
   another group's data? What if the person who could was removed in
   between?
2. An approval end to end. Is the held request the same request when it
   goes through: same parameters, same requester, same content? Can it
   be used twice, by another person, for another target, or after it
   expired?
3. State. Where is each collection kept, does it survive a restart, is
   it bounded, and is anything read, awaited and written without a
   guard? Compare what is saved with what is restored. Reproduce a lost
   update with two concurrent calls against the real module in memory.
4. Locks. For each lock: what frees it on every path, including the one
   where the message was never sent and the one where the other side
   went away.
5. Numbers. Where a count or an amount comes from, who can report one,
   and whether any answer says zero where the truth is "not known".
6. Off by default. With nothing configured, does any existing flow
   behave differently than before the batch?
7. API truth. Pick three operations and compare the published contract
   with what the code returns, field by field. Does any tool or endpoint
   description promise what the code does not do?

## runtime

What runs on a machine: daemons, workers, anything that starts
processes, writes files or listens on a socket.

1. The life of each long operation: start, a second start while one is
   going, status, cancel, expiry, a restart in the middle, the child
   dying, the first line never arriving, two users at once. Where does
   state go wrong, leak, or say what it does not know?
2. Processes. A child that is missing, exits at once, hangs, prints
   megabytes or is killed. Are children reaped, timeouts real, output
   bounded? Does a failure reach the person as a sentence?
3. Files that one piece of work can write and a later one reads: a
   shared directory, a config, a plugin, a note handed on. Can one job
   steer the next, or another user's?
4. What is inside the signature or the encryption and what rides beside
   it. Anything outside is something a less trusted party can write.
5. What is believed from a less trusted process, and what happens on a
   malformed, oversized or repeated message.

## outside

Everything the code assumes about software it does not own. The pins say
which version. Read that project's public source at that tag, cloned
into scratch.

For each assumption, state what the code assumes, what the source says,
and whether they agree:

1. Does the command or endpoint exist, and is the protocol the code
   speaks to it (methods, field names, order of messages, how an end, a
   limit and an error are reported) what the real one speaks?
2. Where does the tool keep its state, in what shape, and does the
   code's reading of it match?
3. What does it need to run where this runs it: headless, as this user,
   in a container?
4. The error words the code looks for: are they the real tool's words?
5. Every stand-in in the tests: where does it accept, answer or keep
   open what the real tool would refuse, answer differently or close?
   This is the heart of the lane.
6. Then walk the whole path a person takes to a working result, step by
   step, and name the first step that cannot be done.

## real-binaries

The code against the real tools it was only ever tested against
stand-ins for. Only in the deep profile, and only on a machine where
`unshare -n true` works.

**The rule, which is absolute.** Install exactly the pinned versions
into scratch. After that, every run of the binary, direct or through the
project's own code, `--version` included, is inside `unshare -n` with
`env -i PATH=... HOME=...` and every home and state directory pointed at
a fresh directory in scratch. Bring loopback up inside the namespace
when a test needs it; a server and its client run in the same namespace.
`timeout` on everything. Never a real credential, never a request a paid
service would answer. If `unshare -n` is refused, stop and report; do
not look for another way.

Record the exact bytes exchanged.

1. Start the tool and speak to it exactly as the code does. Does the
   first exchange succeed with the fields the code sends?
2. With no state, and with a planted, plainly fake one in the shape the
   source writes: what does the tool say, and does the code's own check
   agree with it?
3. With no network, what does the first step that needs it do: which
   error, in which shape, after how long? Does the code turn that into
   the message it promises, or hang?
4. The handshake before real work, and no further.
5. Anything the stand-ins do not do: a banner before the structured
   output, noise on stderr, a first-run prompt, a refusal to run as
   root, files written outside the directories given, a slow start.

What this lane settles is worth keeping as a CI step that starts the
pinned tool with the network cut.

## clients-wire

Every client of the server: apps, a web page, a command line. Reviewed
by reading where it cannot be built here; say so.

1. For each request a client sends and each answer it parses: path,
   method, field name, type and whether it may be absent. Build the
   server's real answer with a script driving the real module and lay it
   beside each client's declaration. Know what each client does with a
   field of the wrong type: one fails the whole decode, another reads a
   silent null.
2. What is checked before something is shown. Is there a path where a
   code, an address or a name is drawn from something that did not pass
   every check? Compare, byte for byte, how each client builds the bytes
   it verifies.
3. Where two clients differ in what they accept: a missing field, an
   empty string against null, a number's format.
4. The state machine and its life: polling, leaving the screen, coming
   back, somebody else's attempt already going, cancel while a request
   is in the air, an answer for a request the screen has moved past.
5. Where a secret lives on the client and for how long: the platform's
   keystore, a field that is not secure, the clipboard, a log.

## design

The design audit. Load `antislop`, `antislop-ui`, `antislop-copywriting`,
`antislop-human` and `antislop-layoutmobile` in mode "after": audit, do
not edit. The project's own design direction and any exception it has
recorded to those rules come first.

1. Walk each feature as a person would and fill in a table: feature,
   can it be finished on each client, and where it breaks. A path that
   dead-ends, or needs something the client cannot do, is a finding.
2. Every control, and whether the server would accept its request in
   the state where it is drawn.
3. Everywhere an absent value or a failed request is drawn as "none",
   "0", "up to date", "Ready" or an empty list with a reassuring
   sentence.
4. Parity: every sentence and every condition for showing a control, on
   each client that is meant to match. List each difference.
5. The words. Read every new string as a person in a hurry would. Which
   are unclear, which claim more than the product knows, which read as
   generated? The answer first, then the reason, then the mechanism.
6. A row that looks different should mean something is different. Where
   does the design spend that signal on nothing?
7. People: labels on icon-only controls, large text against fixed
   heights, touch targets, colour as the only signal. Run
   `antislop-human`'s `contrast-check.py` on any new colour pair before
   saying it passes.
8. A new colour, radius or size written outside the palette, or one
   surface disagreeing with the others.

## resources

Whatever the system makes and must later take away: machines,
containers, volumes, jobs, tokens.

1. Lifecycle and races: made but not started, started but not recorded,
   a sweep that misreads a state, a timer, a build running while its
   release is replaced, a failed build retried, a disk filling.
2. Will a thing made this way work once it joins the rest? Follow what
   it needs at start that its image or template lacks.
3. Authority at each hop. Who can end somebody else's, or start one in
   their name? Can one person exhaust what is shared?
4. Every value written into a generated config: is it escaped?
5. The packaged release: is everything the code needs present on an
   installed copy, with the modes it needs?

## docs-truth

Not a hunt for bugs in the code. Whether what the project says is true.

1. Each concrete claim (a behaviour, a default, a time, a limit, a
   name, what a screen says) against the code, with `file:line` on both
   sides.
2. What is documented as working and has never been run for real. This
   becomes the report's "never been run" list.
3. The most important behaviours with no test, ranked by risk.
4. Tests whose names promise more than they check.

## ci-gate

The workflows, the gate a contributor runs, the dependency bot's
config, the image and package builds.

1. A step that passes with the thing it checks absent: a grep that
   matches nothing and exits 0, `|| true`, a status dropped in a
   subshell, a test skipped when a binary is missing. For each check,
   is there a negative control?
2. A `needs` and `if` pair that lets something publish when its test
   was skipped or cancelled. A path filter that keeps a job from running
   on the change it guards. A push to the default branch that ships what
   a pull request never tested.
3. Every action pinned to a commit. No secret a fork's pull request can
   reach. Every pin's pattern run against the file it is meant to match.
4. "No network" really holding for a step that says so.
5. The gate: does it name the cause when a run fails with no failing
   test, and never hide a real one? Does anything it claims about the
   runtime hold? Run it on one small suite and see.
6. A run that fails with every test passing: which process did it?
   Reproduce it, then fix the cause.
