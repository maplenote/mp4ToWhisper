# YOLO Mode Pipeline Instructions

You are an autonomous agent tasked with running the `mp4towhisper` pipeline.
Execute the following steps in order. If a step fails, stop and report the error.

## Phase 1: Audio Processing

> **Note**: Use `pwsh` for all PowerShell commands.

1. **Prepare & Convert**
   - Command: `powershell -ExecutionPolicy Bypass -File powershell/0_Prepare_And_Convert.ps1`
   - Goal: Convert MP4s in `file/ori_mp4` to MP3s in `file/ori_mp3`.

2. **Split Audio**
   - Command: `powershell -ExecutionPolicy Bypass -File powershell/1_Split_Audio.ps1`
   - Goal: Split MP3s into chunks in `file/tmp_mp3`.

3. **Transcribe (Whisper)**
   - Command: `powershell -ExecutionPolicy Bypass -File powershell/1.5_Run_whisper.ps1`
   - Goal: Transcribe chunks to SRT files in `file/tmp_srt` using `uv run whisper`.

4. **Merge SRT**
   - Command: `powershell -ExecutionPolicy Bypass -File powershell/2_Merge_SRT.ps1`
   - Goal: Merge chunks back into `file/merge_srt/*_merge.srt`.

5. **Convert S2T (OpenCC)**
   - Command: `powershell -ExecutionPolicy Bypass -File powershell/2.2_Convert_S2T.ps1`
   - Goal: Convert Simplified Chinese to Traditional Chinese.

## Phase 2: AI Analysis & Correction (Your Core Task)

> **Important**: All SRT files are **UTF-8** encoded. Ensure you read them as UTF-8 to avoid garbled Chinese characters.

6. **Generate Correction JSONs**
   - **Input**: Read all files in `file/merge_srt/` ending with `_merge.srt`.

   - **Task**: For _each_ file, analyze the text for OCR/ASR errors (wrong homophones, broken technical terms).

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

   - _Note: Do not edit the SRT files directly. Only create the JSON files._

## Phase 3: Finalization

7. **Apply Fixes**
   - Command: `powershell -ExecutionPolicy Bypass -File powershell/2.5_Fix_Error_Words.ps1`
   - Goal: Apply JSON corrections and generate final SRTs in `file/fin_srt`.

8. **Extract Text**
   - Command: `powershell -ExecutionPolicy Bypass -File powershell/3_Extract_Text.ps1`
   - Goal: Extract pure text content.
