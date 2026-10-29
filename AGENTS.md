# Working on agent-harness

- Run `bash tests/test.sh` after every change; add a case for every new hook or script behaviour.
- Keep it small: `bash skills/learn/scripts/size.sh` (SKILL.md under 90 lines). Replace or delete text before adding.
- Nothing user-specific: no names, absolute paths, product names, accounts or secrets.
- Shell: bash with `set -uo pipefail`, no dependencies beyond python3 and coreutils. Use " - " instead of em or en dashes.
