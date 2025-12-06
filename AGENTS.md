We're going to be using slash command from `powershell\`

## Modes

### 1. YOLO Mode (Full Autonomy)

See [GEMINI.md](GEMINI.md) or use [YOLO_PROMPT.md](YOLO_PROMPT.md).
Allows the AI to fix code, install packages, and run any command to get the job done.

### 2. Safe Mode (Restricted)

Use [SAFE_MODE_PROMPT.md](SAFE_MODE_PROMPT.md).
Restricts the AI to:

- **Read-only** for code files (.ps1, .py).
- **Execution** of specific pipeline scripts only.
- **Write access** limited to generating JSON correction files in `file/merge_srt/`.
