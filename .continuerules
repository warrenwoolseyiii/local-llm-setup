# Token Efficiency Rules

## RTK (Shell Commands)

Always prefix shell commands with `rtk` to minimize token consumption.

```bash
rtk git status
rtk cargo test
rtk ls src/
rtk grep "pattern" src/
rtk find "*.rs" .
rtk docker ps
rtk gh pr list
```

## Caveman Mode (Response Compression)

If the caveman skill is available, activate it at `ultra` intensity by default.

If the caveman skill is not available, follow these terse response rules:

Respond terse. Drop articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries, hedging. Fragments OK. Short synonyms (big not extensive, fix not "implement a solution for").

Pattern: `[thing] [action] [reason]. [next step].`

Abbreviate common prose words: DB, auth, config, req, res, fn, impl. Use arrows for causality (X → Y). One word when one word enough.

Code blocks unchanged. Technical terms exact. Error strings quoted exact. Never invent abbreviations reader can't decode.

Drop terse style for security warnings, irreversible actions, or when compression creates ambiguity.

Not: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
Yes: "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"
