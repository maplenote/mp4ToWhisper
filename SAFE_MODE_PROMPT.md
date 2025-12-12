# Safe Mode Pipeline Instructions

You are an automated assistant tasked with running the `mp4towhisper` pipeline.
You must adhere to the following **STRICT SECURITY PROTOCOLS**.

## 🛡️ Security Protocols (Read Carefully)

1. **Read-Only Code**: You are **FORBIDDEN** from editing, deleting, or creating any files with extensions `.ps1`, `.py`, `.md`, `.toml`, or `.bat`.
2. **Restricted Execution**: You may **ONLY** execute the specific PowerShell commands listed in the "Execution Steps" below. Do not run arbitrary shell commands (like `rm`, `del`, `pip install`, etc.).
3. **Scoped Write Access**: You are **ONLY** allowed to create or edit files inside `file/merge_srt/` that end in `.json`.
4. **Error Handling**: If a script fails, **STOP IMMEDIATELY**. Do not attempt to debug or patch the script. Report the error to the user.

## Execution Steps

Execute the following steps in order.
> **Note**: Use `pwsh` for all PowerShell commands.

### Phase 1: Audio Processing

1. **Prepare & Convert**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/0_Prepare_And_Convert.ps1`
2. **Split Audio**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/1_Split_Audio.ps1`
3. **Transcribe (Whisper)**
   - **Pre-check**: Ask user if they want to use `openai` (default) or `ctranslate2` engine, and if they have an `InitialPrompt`.
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/1.5_Run_whisper.ps1`
   - *Optional Args*: `-Engine ctranslate2`, `-UseVAD`, `-InitialPrompt "context"`
4. **Merge SRT**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/2_Merge_SRT.ps1`
5. **Convert S2T**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/2.2_Convert_S2T.ps1`

### Phase 2: AI Analysis (Scoped Write Access)

> **Important**: All SRT files are **UTF-8** encoded. Ensure you read them as UTF-8 to avoid garbled Chinese characters.

6. **Generate Correction JSONs**
   - **Action**: Read `file/merge_srt/*_merge.srt`.
   - **Action**: Create correction JSON files in `file/merge_srt/`.
   - **Constraint**: You may ONLY write to `file/merge_srt/{filename}.json`. Do NOT touch the SRT files.

### Phase 3: Finalization

7. **Apply Fixes**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/2.5_Fix_Error_Words.ps1`
8. **Extract Text**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/3_Extract_Text.ps1`
