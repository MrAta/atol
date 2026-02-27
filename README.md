# atol

ata's session-less Claude CLI wrapper. 

```
curl -fsSL https://raw.githubusercontent.com/MrAta/atol/main/install.sh | bash
```

Requires [claude CLI](https://claude.ai/code).

---

## Usage

```
atol "question"                   ask Claude anything
atol fix <cmd...>                 run a command; if it fails, ask Claude why
atol logs <pod-name>              k8s pod status + log analysis
atol recall [term]                search past queries
```

### Flags (query mode)

| Flag | Description |
|---|---|
| `-c` | continue the last session |
| `--repo` | add the git root as a context directory |
| `-f <file>` | inline a file into the prompt (repeatable) |
| `-o <file>` | save raw output to a file |
| `--no-tools` | no file/shell access (faster, pure reasoning) |
| `--draft` | open output in `$EDITOR` instead of rendering |
| `-h` / `--help` | usage |
| `-v` / `--version` | version |

---

## Examples

```bash
# Basic question — auto-detects git branch + project type
atol "what does CUDA_VISIBLE_DEVICES do"

# Piped stdin
cat training.log | atol "summarize the training progress"

# Fix a failing command
atol fix kubectl get pods -n ml-jobs

# K8s pod status (Claude runs kubectl autonomously)
atol logs trainer-7f9xk

# Search past queries
atol recall
atol recall "OOM"

# Add git repo as context
atol --repo "how is the training loop structured"

# Open output in editor
atol --draft "write a k8s Job spec for PyTorch DDP"

# Save to file
atol -o notes.md "explain DDP vs FSDP"

# Fast, no file access
atol --no-tools "what is gradient checkpointing"

# Inline a file
atol -f config.yaml "what does this config do"

# Continue last session
atol -c "now make it support multi-node"
```

---

## `atol fix`

Runs a command. If it fails, sends the command + exit code + output to Claude for diagnosis.

```bash
atol fix make build
atol fix python train.py --config config.yaml
atol fix kubectl apply -f job.yaml
```

If the command succeeds, atol prints the output and exits cleanly — no Claude call made.

---

## `atol logs`

Give it a pod name. Claude autonomously finds the namespace, runs `kubectl describe` and `kubectl logs`, and reports back.

```bash
atol logs trainer-7f9xk
```

Example outputs:
- **Running.** Step 4,200/10,000 — loss 0.312, ~2.1 it/s. ETA ~90 min.
- **Failed — OOM.** Killed at step 312. Container exceeded 16Gi memory limit. Reduce batch size or raise the memory request.
- **CrashLoopBackOff.** Exits with code 1 immediately — `/app/train.sh` not found. Check your image build.
- **Completed.** Final loss 0.089 after 10,000 steps. Checkpoint at `/mnt/checkpoints/model_final.pt`.

---

## `atol recall`

Searches `~/.local/share/atol/log.md` — every query and response atol has ever produced.

```bash
atol recall          # open full log (uses glow/bat/less)
atol recall "OOM"    # grep; fuzzy with fzf if available
```

---

## `why` shell function

Installed automatically. Captures the exit code and command text of the last failed command and asks Claude what went wrong.

```bash
false; why
kubectl apply -f broken.yaml; why
```

To add manually:

```bash
why() {
  local exit_code=$?
  local last_cmd
  last_cmd=$(fc -ln -1 2>/dev/null | sed 's/^ *//')
  printf '%s\n' "$last_cmd" | atol --no-tools "Exit code was $exit_code. Why did this fail and how do I fix it?"
}
```

---

## Auto-context

Every query silently prepends a brief context preamble — no flag needed:

```
[git: branch=main, last commit: "fix auth bug"]
[project: Python]

<your question>
```

Detects: `package.json` (Node), `pyproject.toml` / `requirements.txt` (Python), `go.mod` (Go), `Cargo.toml` (Rust), `Makefile`.

---

## Output rendering

- **Piped stdout**: raw text, no renderer, no spinner — fully scriptable
- **Interactive**: `glow` → `bat` → `less` (uses first available)
- **`--draft`**: skips renderer, opens in `$EDITOR`

---

## Log

Every query is appended to `~/.local/share/atol/log.md`:

```markdown
## 2026-02-26 14:32 — what is a monad

**Q:** what is a monad

**A:** A monad is a design pattern...

---
```

---

## Config

`~/.config/atol/config` — currently unused, reserved for future settings.

---

## Model

Hardcoded to `claude-opus-4-6`.

---

## Tools

Default allowed tools:

```
Read, Glob, Grep,
Bash(ls:*), Bash(find:*), Bash(cat:*), Bash(head:*), Bash(tail:*),
Bash(git:*), Bash(kubectl:*), Bash(jq:*)
```

`atol logs` uses a narrower set: `Bash(kubectl:*)`, `Bash(jq:*)` only.

`--no-tools` disables all tool access.
