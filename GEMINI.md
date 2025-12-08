# Gemini CLI / AI Agent Instructions

This document contains instructions for running the `mp4towhisper` pipeline using an AI CLI or Agent.

> **Important**:
>
> 1. Use `pwsh` for all PowerShell commands.
> 2. All SRT files and source code in this project are encoded in **UTF-8**. When reading filenames or content, ensure you are using UTF-8 encoding to prevent Chinese characters from becoming garbled.

## YOLO Mode (Autonomous Execution)

To run the entire pipeline from start to finish, follow these steps in order.

### Step 1: Prepare and Convert

Convert source MP4 files to MP3.

- **Command**: `powershell -ExecutionPolicy Bypass -File powershell/0_Prepare_And_Convert.ps1`
- **Check**: Ensure `.mp3` files exist in `file/ori_mp3`.

### Step 2: Split Audio

Split MP3 files into chunks for processing.

- **Command**: `powershell -ExecutionPolicy Bypass -File powershell/1_Split_Audio.ps1`
- **Check**: Ensure chunk files exist in `file/tmp_mp3`.

### Step 3: Transcribe (Whisper)

Run OpenAI Whisper on the audio chunks using `uv run`.

- **Command**: `powershell -ExecutionPolicy Bypass -File powershell/1.5_Run_whisper.ps1`
- **Check**: Ensure `.srt` files exist in `file/tmp_srt`.

### Step 4: Merge SRT

Merge the chunked SRT files back into a single sequence.

- **Command**: `powershell -ExecutionPolicy Bypass -File powershell/2_Merge_SRT.ps1`
- **Check**: Ensure `_merge.srt` files exist in `file/merge_srt`.

### Step 5: AI Error Correction (Agent Task)

**This step requires the AI Agent to generate correction data.**

> **Note**: Ensure you read the SRT files using **UTF-8** encoding.

1. **Scan**: Look for `*_merge.srt` files in `file/merge_srt`.
2. **Analyze**: For each file, read the content and identify phonetic errors, typos, or contextually incorrect terms (especially technical terms).
3. **Generate JSON**: Create a JSON file named `{basename}.json` in `file/merge_srt/` (e.g., if file is `video_merge.srt`, create `video.json`).
4. **JSON Format**:

    ```json
    {
      "mappings": [
        {
          "correct": "正確詞彙",
          "wrong": ["錯誤詞彙1", "錯誤詞彙2"]
        },
        {
          "correct": "ProductModel",
          "wrong": ["ProducModel", "ProductModle"]
        }
      ]
    }
    ```

    *Note: Only generate the JSON file. Do not modify the SRT manually.*

### Step 6: Apply Fixes

Apply the AI-generated corrections to the SRT files.

- **Command**: `powershell -ExecutionPolicy Bypass -File powershell/2.5_Fix_Error_Words.ps1`
- **Check**: Ensure `_ai.srt` files are created and copied to `file/fin_srt`.

### Step 7: Extract Text (Optional)

Extract pure text from the final SRT.

- **Command**: `powershell -ExecutionPolicy Bypass -File powershell/3_Extract_Text.ps1`

---

## Quick Start Prompt

You can directly use the file [YOLO_PROMPT.md](YOLO_PROMPT.md) as your instruction set.

Or copy and paste this into your AI CLI to run the full pipeline:

> *Note: Use `pwsh` and ensure UTF-8 encoding for all file operations.*
>
> **Execute the mp4towhisper pipeline in YOLO mode.**
>
> 1. Run `powershell/0_Prepare_And_Convert.ps1`.
> 2. Run `powershell/1_Split_Audio.ps1`.
> 3. Run `powershell/1.5_Run_whisper.ps1`.
> 4. Run `powershell/2_Merge_SRT.ps1`.
> 5. **CRITICAL**: Read all `file/merge_srt/*_merge.srt` files. For each, generate a correction JSON file (same basename, .json extension) containing a list of `mappings` with `correct` and `wrong` (array) fields to fix common speech recognition errors.
> 6. Run `powershell/2.5_Fix_Error_Words.ps1`.
> 7. Run `powershell/3_Extract_Text.ps1`.
