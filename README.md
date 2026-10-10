<!--
DOCUMENT INFORMATION
Document Name: README.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v2.0.0
Date / Time: 2026-10-10 04:20 CEST
Project: DeepEcho_faster_whisper
Status: Major stable release v2.0.0; source package ready for Git push.
Short description: Complete project overview for installation, model management and Faster-Whisper transcription.
-->

# DeepEcho_faster_whisper

`DeepEcho_faster_whisper` is a local Faster-Whisper transcription project built around a strict separation between reusable repository code and private runtime data.

The V2.0.0 major release includes the complete working layers for:

- Python environment bootstrap;
- Faster-Whisper runtime installation;
- local model management;
- single-file, batch and optional recursive MP4 transcription;
- raw transcript generation;
- timestamped transcript generation;
- optional audio normalization/amplification;
- source-local runtime logs;
- invariant per-source Processing-Time benchmark reports for model comparison;
- automatic repository hygiene through additive `.gitignore` maintenance.

This package is **V2.0.0**, the first major stable project release. It preserves the V1.1.4-dev implementation without introducing any new transcription or storage features. A repository push is a separate action controlled by the user.

## Current validated runtime baseline

The project has been built against the following runtime family:

```text
Python          3.14.7
pip             26.2.1
faster-whisper  1.2.1
ctranslate2     4.8.2
PyAV            19.0.1
```

Faster-Whisper `1.2.1` and PyAV `19.x` have a compatibility mismatch around the removed `metadata_errors` argument. `transcribe.py` includes a local runtime compatibility shim that strips only this obsolete argument when PyAV 19 or newer is detected. No package downgrade is required by the project.

## Repository layout

```text
DeepEcho_faster_whisper/
├── install_pip.sh
├── install.sh
├── getModels.sh
├── getModels.py
├── transcribe.sh
├── transcribe.py
├── requirements.txt
├── .gitignore
├── README.md
├── CHANGELOG.md
├── INSTALL.md
├── SPECIFICATIONS.md
├── SPECIFICATIONS.pdf
└── EXAMPLES.md
```

`WHY.md` is intentionally no longer part of the project.

Runtime-only data may exist locally but is not repository source:

```text
DeepEcho_faster_whisper/
├── .venv/                  # local Python virtual environment
├── models/                 # downloaded Faster-Whisper models
├── logs/                   # installer logs
├── .zip/                   # local package/archive workspace
├── .old/                   # local historical workspace
├── .exports/               # local exports
├── .export/                # local exports
└── ...
```

Source-media directories may additionally contain:

```text
media-directory/
├── source.mp4
├── source.mp4.transcription_timestamps-MODEL-YYYYMMDD-HHMM-SS.md
├── .transcription/
│   ├── source.mp4.transcription-MODEL-YYYYMMDD-HHMM-SS.md
│   └── source.mp4.transcript-MODEL-YYYYMMDD-HHMM-SS.txt
└── .logs/
    ├── transcribe-VERSION-YYYYMMDD-HHMM-SS.log
    └── source.mp4-Processing-Time-MODEL-YYYYMMDD-HHMM-SS.md
```

## Installation architecture

Installation is intentionally split into two scripts.

### Stage 1 — `install_pip.sh`

`install_pip.sh` prepares the isolated Python foundation. It:

- checks Python and `venv` support;
- checks required shell utilities;
- checks free disk space;
- extends `.gitignore` additively with required runtime exclusions;
- creates or preserves the project-local `.venv`;
- upgrades `pip`, `setuptools` and `wheel` inside `.venv`;
- creates `requirements.txt` when absent;
- preserves existing `requirements.txt` content when present;
- ensures `faster-whisper==1.2.1` is declared;
- creates installer logs for real install/purge actions under `./logs/`.

### Stage 2 — `install.sh`

`install.sh` installs and validates the actual runtime. It:

- requires the `.venv` created by `install_pip.sh`;
- requires `requirements.txt`;
- extends `.gitignore` additively if required rules are still missing;
- installs requirements through `.venv/bin/python -m pip` only;
- uses `--no-cache-dir`;
- runs `pip check`;
- validates imports and versions for Faster-Whisper, CTranslate2 and PyAV;
- validates `WhisperModel` import;
- never downloads Whisper models;
- creates installer logs for real install/purge actions under `./logs/`.

The required installation order is therefore:

```bash
./install_pip.sh --install
./install.sh --install
```

See `INSTALL.md` for the complete workflow.

## Installer logging

Real installer actions create repository-local logs:

```text
./logs/install_pip-V2.0.0-YYYYMMDD-HHMM-SS.log
./logs/install-V2.0.0-YYYYMMDD-HHMM-SS.log
```

The `logs/` directory and `*.log` files are excluded from Git by `.gitignore`.

Read-only actions such as no-argument help, `--help`, `--prerequis` and `--simulate` do not create log files.

## `.gitignore` policy

The installation workflow protects local runtime data automatically.

The installer scripts use an **additive-only** policy:

- existing lines are never removed;
- existing comments are never rewritten;
- existing duplicate lines are never deduplicated;
- only missing required entries are appended;
- a missing `.gitignore` may be created by a real install action.

Required runtime exclusions include, among others:

```text
.venv/
.VENV/
venv/
models/
.zip/
.old/
.logs/
logs/
.exports/
.export/
.transcription/
__pycache__/
*.pyc
*.log
```

The delivered `.gitignore` also preserves all rules that already existed before this update.

## Model management

The normal model-management entry point is:

```text
./getModels.sh
```

The Python backend is:

```text
./getModels.py
```

### List models

```bash
./getModels.sh --exec --list
```

The list reports each runtime model as one of:

- `INSTALLED`;
- `INCOMPLETE`;
- `not installed`.

### Show model download sizes before downloading

Use the live size view:

```bash
./getModels.sh --exec --list --size
```

This performs a read-only Hugging Face metadata query and does **not** download model payloads. The `DOWNLOAD SIZE` column is calculated from the same file patterns requested by Faster-Whisper (`config.json`, `preprocessor_config.json`, `model.bin`, `tokenizer.json`, and `vocabulary.*`). A `LOCAL SIZE` column is also shown when a local model directory exists.

This allows free-space planning before downloading large models. Internet access is required for the live remote-size lookup.

### Download one model

```bash
./getModels.sh --exec --download --model tiny
```

### Download several models in one command

```bash
./getModels.sh --exec --download --model base small medium
```

### Existing local model behavior

By default:

- a complete existing model is skipped;
- an incomplete/corrupt target directory is reported and is not silently trusted;
- use `--force` to remove and redownload requested local models.

Example:

```bash
./getModels.sh --exec --download --model base small medium --force
```

`--force` applies to every requested model in that invocation.

### Model storage

Default model storage is:

```text
./models/<model-name>/
```

No model is committed to Git.

## Faster-Whisper model reference

The current static help reference contains the following 19 names:

```text
1.  tiny.en
2.  tiny
3.  base.en
4.  base
5.  small.en
6.  small
7.  medium.en
8.  medium
9.  large-v1
10. large-v2
11. large-v3
12. large
13. distil-large-v2
14. distil-medium.en
15. distil-small.en
16. distil-large-v3
17. distil-large-v3.5
18. large-v3-turbo
19. turbo
```

The static list is convenient documentation. `--exec --list` remains the runtime-authoritative registry/status view.

## Transcription architecture

The normal transcription entry point is:

```text
./transcribe.sh
```

The backend is:

```text
./transcribe.py
```

The shell validates user-facing arguments and forwards the same business arguments to the Python backend through the repository-local `.venv`.

## Transcription defaults

Current defaults are:

```text
Language       fr
Device         cpu
Compute type   int8
VAD            OFF
Normalization  OFF
Amplification  OFF
Timestamps     ON
Source pattern *.mp4 when --source is omitted
```

No source media is modified.

No automatic model download occurs during transcription.

## Source selection

The transcription CLI supports:

- one source file;
- several source files;
- repeated `--source` options;
- quoted globs;
- unquoted shell-expanded globs;
- filenames containing spaces;
- a source directory override;
- common video and audio extensions.

Examples:

```bash
./transcribe.sh --simulate --source video.mp4 --model tiny
./transcribe.sh --simulate --source '*.mp4' --model tiny
./transcribe.sh --simulate --source *.mp4 --model tiny
./transcribe.sh --simulate --source 'video with spaces.mp4' --model tiny
./transcribe.sh --simulate --source first.mp4 'second file.mp4' --model tiny
```

The shell-expansion bug that previously caused additional expanded filenames to become `Unknown argument` errors is fixed in the current release.

## Recursive MP4 scan (`--recursive`)

`--recursive` (aliases `--recursif`, `--récursif`, `--récursive`) scans **all `.mp4` files under the current working directory**, including nested folders, regardless of how many top-level files Bash expanded from `--source *.mp4`. The scan is case-insensitive for `.mp4` extensions, skips symlinked directories and files, sorts paths deterministically and deduplicates results. All discovered files are processed **sequentially in a single invocation** (not as six parallel transcription processes).

```bash
./transcribe.sh --exec --source *.mp4 --recursive --model large-v3
./transcribe.sh --simulate --source '*.mp4' --recursive --model tiny
./transcribe.sh --exec --source-dir /media/videos --recursive --model medium
```

When recursive mode is enabled, the `--source` file arguments are accepted for command compatibility, **but they do not filter the recursive scan**: every MP4 under the scan root is selected. `--source-dir` explicitly overrides that root; otherwise it is the working directory, not the script/repository directory. Without `--recursive`, the preexisting exact-file/glob behavior is unchanged. Generated transcripts remain next to each source or in its source-local `.transcription/` directory; runtime logs and benchmark reports remain source-local under `.logs/`. No MP4 or personal data is copied into the repository. The simulation creates no files.

## Raw transcription policy

The transcription layer is designed to preserve model output rather than rewrite it.

The program does not deliberately:

- censor spoken content;
- summarize the source;
- rewrite sentences editorially;
- sanitize vocabulary;
- omit content for stylistic reasons.

Only surrounding whitespace around model segments is normalized when output lines are assembled.

## Timestamped output policy

Every generated transcript, Processing-Time report and runtime log receives one run timestamp in the form:

```text
YYYYMMDD-HHMM-SS
```

For example:

```text
20261009-1832-45
```

All files generated from one invocation use the same run timestamp. Transcript filenames and Processing-Time reports also include the selected model immediately before that timestamp.

This design prevents ordinary runs from overwriting prior output.

If a timestamp collision is detected, the transcription backend allocates the next free second before creating files.

## Transcript locations

For a source such as:

```text
/media/evidence/2011.mp4
```

the default outputs are:

```text
/media/evidence/2011.mp4.transcription_timestamps-MODEL-YYYYMMDD-HHMM-SS.md
/media/evidence/.transcription/2011.mp4.transcription-MODEL-YYYYMMDD-HHMM-SS.md
/media/evidence/.transcription/2011.mp4.transcript-MODEL-YYYYMMDD-HHMM-SS.txt
/media/evidence/.logs/transcribe-V2.0.0-YYYYMMDD-HHMM-SS.log
/media/evidence/.logs/2011.mp4-Processing-Time-MODEL-YYYYMMDD-HHMM-SS.md
```

The timestamped Markdown deliberately remains beside the source file.

Plain Markdown and plain TXT deliberately live under `.transcription/`.

Runtime transcription logs deliberately live under `.logs/`.

## Processing-Time benchmark reports

Every real source transcription creates a separate Markdown benchmark report under the source-local `.logs/` directory. It is deliberately separate from the normal operational `.log`.

Naming:

```text
<source-name>-Processing-Time-<model>-YYYYMMDD-HHMM-SS.md
```

Example:

```text
2011.mp4-Processing-Time-tiny-20261009-2208-05.md
2011.mp4-Processing-Time-large-v3-20261009-2212-41.md
```

The report is a fixed comparison template. Every model uses the same title, section order, field names, units and table structure; unavailable values remain present as `N/A`. Only the values change. This makes two reports directly comparable side by side while scrolling.

The fixed timing section records media duration, model load time, processing start/end, preprocessing time, transcription/output processing time, total source processing time, real-time factor and processing speed.

The normal runtime log remains separate and its first record is the exact command/argv that launched the transcription. For shell-expanded globs, that record necessarily reflects the argv after shell expansion.

## Multi-directory batches

If one transcription command includes sources from different directories:

- each source uses its own source-local `.transcription/` directory by default;
- each involved source directory receives the run log under its own `.logs/` directory;
- the same run timestamp identifies every artifact across the batch.

## Explicit destination override

`--dest-dir` overrides the base location for plain Markdown/TXT only.

Example:

```bash
./transcribe.sh --exec --source video.mp4 --dest-dir /media/results --model tiny
```

Plain outputs then go under:

```text
/media/results/.transcription/
```

The timestamped Markdown and runtime log remain source-local by design.

## Audio processing

Audio preprocessing is never enabled silently.

### VAD

VAD is OFF by default.

Enable it explicitly:

```bash
./transcribe.sh --exec --source video.mp4 --vad --model tiny
```

### Normalization

Enable temporary FFmpeg loudness normalization explicitly:

```bash
./transcribe.sh --exec --source video.mp4 --normalize --model tiny
```

### Amplification factor

```bash
./transcribe.sh --exec --source video.mp4 --amplify 2 --model tiny
```

### Amplification in dB

```bash
./transcribe.sh --exec --source video.mp4 --amplify-db 6 --model tiny
```

`--amplify` and `--amplify-db` are mutually exclusive.

Preprocessing uses a temporary WAV file. The source is never modified.

## Simulation

Simulation resolves the planned operation without creating transcription directories, logs or outputs:

```bash
./transcribe.sh --simulate --source '*.mp4' --model tiny
```

## Prerequisite checks

```bash
./transcribe.sh --prerequis
```

This validates the local runtime without starting a transcription.

## Output formats in this release

Implemented:

- timestamped Markdown;
- plain Markdown;
- plain TXT.

Not implemented yet:

- SRT;
- WebVTT;
- JSON;
- speaker diarization.

Speaker labels are never fabricated. Real diarization requires a separate diarization layer and remains outside this release.

## Documentation

- `README.md` — project overview and common workflow;
- `INSTALL.md` — complete automated installation/model/transcription setup workflow;
- `SPECIFICATIONS.md` — exhaustive current functional and technical contract;
- `SPECIFICATIONS.pdf` — complete NoXoZ.be formatted PDF edition synchronized with the Markdown;
- `EXAMPLES.md` — command examples for every supported argument;
- `CHANGELOG.md` — append-only project history.

## Release status

**V2.0.0 — MAJOR STABLE RELEASE.** Based strictly on V1.1.4-dev, with no change to transcription, model-management, installer behavior, or private-data placement. Source package includes all 13 original files plus `SPECIFICATIONS.pdf`.

Git push/tag and real-media validation remain separate user-controlled operations. Future audio-optimization improvements require explicit authorization and are not included here.
