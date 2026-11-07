---
name: adopt-renovate-preset
description: Point a repository's Renovate config at the shared preset in a Fleetwright templates repository, and check that the result validates before it is committed.
---

# Adopt the shared Renovate preset

Use this when asked to put a repository on the shared Renovate policy, or when
a repository has a `renovate.json` that restates rules the preset already
carries.

1. Find the preset's owner. The person's templates repository is linked in the
   Fleetwright app under **You › Linked repositories › Templates**; if it is
   not named in the request, ask which `owner/repo` to extend rather than
   guessing. The preset file in it is `default.json`.
2. Write the repository's `renovate.json` as the one line that matters, plus
   anything that is a fact about *this* repository and not a policy:

   ```json
   {
     "$schema": "https://docs.renovatebot.com/renovate-schema.json",
     "extends": ["github>OWNER/REPO"]
   }
   ```

   Keep an existing rule only if the preset does not carry it. Grouping a
   package pair that only works together stays; a second copy of
   `rangeStrategy: pin` goes.
3. Check it the way the templates repository checks its own, pinned so the run
   says which Renovate judged it. No file argument: given a path the validator
   treats the file as self-hosted global config, which is a different schema.

   ```sh
   npx --yes --package "renovate@44.216.0" -- renovate-config-validator --strict
   ```

4. Commit `renovate.json` on its own. Do not change any other repository:
   adopting the preset elsewhere is a separate decision.

Say in the reply which rules the repository lost to the preset and which it
kept, so the diff reads as a decision and not a cleanup.
