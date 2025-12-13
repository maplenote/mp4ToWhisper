# YOLO Mode Pipeline Instructions

You are an autonomous agent tasked with running the `mp4towhisper` pipeline.
Execute the following steps in order. If a step fails, stop and report the error.

## Phase 1: Audio Processing

> **Note**: Use `pwsh` for all PowerShell commands.

1. **Prepare & Convert**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/1_Prepare_And_Convert.ps1`
   - Goal: Convert MP4s in `file/ori_mp4` to MP3s in `file/ori_mp3`.

2. **Split Audio**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/2_Split_Audio.ps1`
   - Goal: Split MP3s into chunks in `file/tmp_mp3`.

3. **Transcribe (Whisper)**
   - **Auto-Config**:
     - **Engine**: Read `WHISPER_ENGINE` from `.env`. Default to `openai` if missing.
     - **Context**: **Automatically** read filenames from `file/ori_mp4` (or mp3). Construct a descriptive sentence (e.g., "This is a video about [Filename]") to use as the `-InitialPrompt`.
     - **Constraint**: Do **NOT** ask the user. Decide autonomously.
   - **Note**: If specifying a target file via `-TargetFileName`, ensure you use the **.mp3** filename from `file/ori_mp3`, NOT the original .mp4 filename.
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/3_Run_whisper.ps1 -Engine <Auto_Engine> -InitialPrompt "<Auto_Context>"`
   - *Example*: `... -InitialPrompt "This is a video about Physics_Lecture_01"`
   - Goal: Transcribe chunks to SRT files in `file/tmp_srt` using `uv run whisper` or `whisper-ctranslate2`.

4. **Merge SRT**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/4_Merge_SRT.ps1`
   - Goal: Merge chunks back into `file/merge_srt/*_merge.srt`.

5. **Convert S2T (OpenCC)**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/5_Convert_S2T.ps1`
   - Goal: Convert Simplified Chinese to Traditional Chinese.

## Phase 2: AI Analysis & Correction (Your Core Task)

> **Important**: All SRT files are **UTF-8** encoded. Ensure you read them as UTF-8 to avoid garbled Chinese characters.

6. **Generate Correction JSONs**
   - **Input**: Read all files in `file/merge_srt/` ending with `_merge.srt`.

   - **Task**: For *each* file, analyze the text for OCR/ASR errors (wrong homophones, broken technical terms).

   - **Output**: Create a JSON file in `file/merge_srt/` with the same basename (e.g., `video01.json` for `video01_merge.srt`).

   - **JSON Format**:

     ```json
     {
         "mappings": [
             { "correct": "專有名詞", "wrong": ["專有名字", "專用名詞"] },
             { "correct": "API", "wrong": ["A P I", "APP I"] }
         ]
     }
     ```

   - *Note: Do not edit the SRT files directly. Only create the JSON files.*

## Phase 3: Finalization

7. **Apply Fixes**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/6_Fix_Error_Words.ps1`
   - Goal: Apply JSON corrections and generate final SRTs in `file/fin_srt`.

8. **Extract Text**
   - Command: `pwsh -ExecutionPolicy Bypass -File pwsh/7_Extract_Text.ps1`
   - Goal: Extract pure text content.
