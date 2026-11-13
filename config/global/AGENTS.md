# Global Development Preferences

> Personal defaults for all projects. Follow applicable project instructions when they conflict with these preferences.

## Communication

- Be concise. No fluff, no filler, no restating the question.
- Skip introductions and conclusions unless the answer is complex.
- When showing terminal commands, explain impact briefly before running.
- Default to action over asking for confirmation on safe, reversible changes.

## Coding Style

- **Shell**: Bash with `set -euo pipefail`. Always double-quote variables.
- **TypeScript/JavaScript**: Prefer `const`, strict mode, no `any` unless unavoidable.
- **Python**: Type hints on public APIs. Use `pathlib` over `os.path`.
- **Naming**: `snake_case` for shell/Python, `camelCase` for JS/TS, `PascalCase` for types/classes.
- **Indentation**: 2 spaces for shell/JS/TS/JSON/YAML, 4 spaces for Python.
- **Comments**: Explain *why*, not *what*. No obvious comments.

## Tool & Stack Preferences

- **OS**: macOS (Apple Silicon). Use `brew` for package management.
- **Shell**: zsh (interactive), bash (scripts).
- **Editor**: VS Code with Copilot extensions. Prettier as default formatter.
- **Node**: Use the system Node managed by Homebrew. Prefer `npx` for one-off tools.
- **Git**: Conventional commits when feasible. Prefer rebase over merge for local work. Default branch `main`. Commits are SSH-signed.
- **Git commits by AI**: Do not append "Co-developed-by" or "Co-authored-by" trailers. Do not explicitly set `--author` unless asked.
- **Containers**: Docker Desktop on macOS. Prefer multi-stage builds.
- **Line endings**: LF only. Trim trailing whitespace. Always insert final newline.
- **Formatting**: Prettier for JS/TS/CSS/HTML/JSON/YAML. `shfmt` for shell.

## Security

- Never hardcode secrets, tokens, or credentials. Use environment variables or secret managers.
- Validate inputs at system boundaries (CLI args, API inputs, file reads from untrusted sources).
- Prefer principle of least privilege for file permissions and network access.
- Do not pipe curl output directly to shell without review.
- Flag any code that disables TLS verification or uses `--insecure`.

## Project Structure Conventions

- Config files belong in the project root or a dedicated `config/` directory.
- Keep scripts executable and self-documenting with usage headers.
- Prefer flat structures over deep nesting.
- One concern per file; split when a file exceeds ~300 lines.

## Things to Avoid

- Don't add features, refactor, or "improve" code beyond what was asked.
- Don't add docstrings/comments to code you didn't change.
- Don't create wrapper functions for one-time operations.
- Don't suggest switching to a different language/framework unless there's a clear blocker.
- Don't use `sudo` without explicitly calling it out.
- Don't use raw `echo` for user-facing output in shell scripts — use structured logging helpers.
- Don't leave docs/comments out of sync with code changes.
