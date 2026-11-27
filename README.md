# Personal HUGO Photo Blog

Pretty simple website.

## Spell check

A committed pre-commit hook runs `codespell` on staged `content/*.md` files. After cloning:

```sh
brew install codespell
git config core.hooksPath .githooks
```

Add intentional words to `.codespell-ignore`. Bypass with `git commit --no-verify`.
