<!--
DOCUMENT INFORMATION
Document Name: CHANGELOG.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.1.0-dev
Date / Time: 2026-10-09 18:32 CEST
Project: DeepEcho_faster_whisper
Status: Validation candidate; not a release tag.
Short description: Append-only project changelog.
-->

# DeepEcho_faster_whisper — Changelog

## v1.1.0-dev — 2026-10-09 18:32 CEST — Bruno DELNOZ

### STATUS

- Validation candidate for a major project update.
- Not yet a final release/tag.
- User validation is required before release finalization.

### ADDED — INSTALLATION / REPOSITORY HYGIENE

- Repository-local installer logs under `./logs/`.
- Installer log naming with explicit seconds: `*-YYYYMMDD-HHMM-SS.log`.
- Automatic additive `.gitignore` maintenance during real install actions.
- Required Git exclusions for `.venv/`, `.VENV/`, `venv/`, `models/`, `.zip/`, `.old/`, `.logs/`, `logs/`, `.exports/`, `.export/`, `.transcription/`, `__pycache__/`, `*.pyc`, `*.log`.
- Explicit rule that `.gitignore` lines are never removed, reordered or deduplicated automatically.
- Installer preservation of pre-existing duplicate `.gitignore` lines.
- Read-only installer controls continue to create no logs/files.

### CHANGED — INSTALLATION

- `install_pip.sh` incremented to `V1.1.0-dev`.
- `install.sh` incremented to `V1.1.0-dev`.
- `install_pip.sh` remains owner of automatic `requirements.txt` creation/preservation.
- `install.sh` remains consumer/installer of `requirements.txt` inside project `.venv`.
- Real install/purge actions are now timestamp-logged.
- Existing two-stage installation order is preserved.
- No system-wide pip behavior introduced.
- Model downloads remain outside installer responsibility.

### ADDED — MODEL MANAGEMENT

- Complete 19-model static reference in `getModels.sh --help` and `getModels.py --help` immediately before examples.
- Multi-model download syntax:
  - `--exec --download --model base small medium`
- `--force` model replacement/redownload option.
- Default skip for already complete local models.
- Explicit `INCOMPLETE` handling for existing incomplete/corrupt local model directories.
- Aggregate batch behavior that reports invalid/failed model names while continuing independent valid requested models.
- Live `--exec --list` status values:
  - `INSTALLED`
  - `INCOMPLETE`
  - `not installed`
- No `--local` option; it was considered and deliberately removed before implementation.

### CHANGED — MODEL MANAGEMENT

- `getModels.sh` incremented to `V1.1.0-dev`.
- `getModels.py` incremented to `V1.1.0-dev`.
- Default model storage remains repository-local `models/<model-name>/`.
- `models/` is protected from Git pushes by `.gitignore` and installer checks.

### ADDED — TRANSCRIPTION OUTPUT LAYOUT

- One run timestamp shared by all generated artifacts.
- Filename timestamp format: `YYYYMMDD-HHMM-SS`.
- Timestamped Markdown remains beside each source media file.
- Plain Markdown and TXT now default to source-local `.transcription/`.
- Transcription runtime logs now default to source-local `.logs/`.
- Multi-directory batch logging: every involved source directory receives its own run log copy.
- Timestamp collision avoidance to prevent normal overwrite behavior.
- Explicit output collision detection when a common destination would collapse different sources onto the same filename.

### CHANGED — TRANSCRIPTION

- `transcribe.sh` incremented to `V1.1.0-dev`.
- `transcribe.py` incremented to `V1.1.0-dev`.
- French remains the default language.
- CPU remains the default device.
- `int8` remains the current default compute type pending user validation.
- VAD remains OFF by default.
- Normalization/amplification remain explicit only.
- Original media remains immutable.
- `--dest-dir` now overrides the base for plain Markdown/TXT only; timestamped Markdown and logs remain source-local.
- Existing glob, multi-source and filename-with-spaces fixes are preserved.
- Existing PyAV 19 / Faster-Whisper 1.2.1 compatibility workaround is preserved.

### DOCUMENTATION

- `README.md` completely updated to reflect implemented installation, models and transcription layers.
- `INSTALL.md` completely updated with automated end-to-end setup workflow.
- `SPECIFICATIONS.md` expanded into the full current contract, including all detailed requirements agreed before this Markdown was created.
- `EXAMPLES.md` replaced with structured per-script sections and examples for every supported argument.
- `CHANGELOG.md` updated with transcription/model/runtime history missing from the old installer-only document.
- `WHY.md` removed from the current package by explicit project decision.

### PACKAGING

- Full-project ZIP required for this candidate.
- Runtime/private data excluded from ZIP: `.venv`, models, source media, generated transcripts, runtime logs, caches and local export/archive directories.
- Package remains validation-only until the user approves behavior.

## v1.0.1 — 2026-10-09 17:40 CEST — Bruno DELNOZ

### FIXED — TRANSCRIPTION

- Fixed shell-expanded unquoted glob handling after `--source`.
- Fixed multi-source parsing when filenames contain spaces.
- Added matching multi-value `--source` support to `transcribe.py`.
- Fixed Faster-Whisper `1.2.1` failure with PyAV `19.x` caused by removed `metadata_errors` keyword.
- Added process-local PyAV compatibility shim instead of forcing a package downgrade.

### PRESERVED

- French default language.
- CPU/int8 default runtime.
- VAD OFF by default.
- Raw transcription behavior.
- Non-destructive source-media handling.

## v1.0.0-transcription — 2026-10-09 16:45 CEST — Bruno DELNOZ

### ADDED — TRANSCRIPTION

- Initial `transcribe.sh` user-facing interface.
- Initial `transcribe.py` backend.
- Explicit local model selection.
- Single-file and batch source selection.
- Quoted glob support.
- Repeated source support.
- Timestamped Markdown output.
- Plain Markdown output.
- Plain TXT output.
- VAD controls.
- Normalization control.
- Amplification factor/dB controls.
- Simulation/prerequisite/help/changelog controls.
- Original-media protection.
- Explicit overwrite control.

## v1.0.1-models — 2026-10-09 15:41 CEST — Bruno DELNOZ

### ADDED — MODEL MANAGEMENT

- `getModels.sh` user-facing model manager.
- `getModels.py` model backend.
- Runtime model registry listing.
- Explicit model download action.
- Repository-local model storage.
- Prerequisite and simulation controls.

## v1.0.0 — 2026-10-09 12:56 CEST — Bruno DELNOZ

### ADDED

- Initial `install_pip.sh` v1.0.0.
- Initial `install.sh` v1.0.0.
- Two-stage installation workflow.
- Project-local `.venv`.
- `requirements.txt` management.
- Faster-Whisper `1.2.1` runtime requirement.
- Current-directory filesystem free-space verification.
- Additional project-filesystem verification when it differs from the execution filesystem.
- `--no-cache-dir` pip behavior.
- Installer CLI controls: `--help/-h`, `--exec/-exe`, `--simulate/-s`, `--prerequis/-pr`, `--install/-i`, `--changelog/-ch`, `--purge/-pu`.
- No-argument help behavior.
- Runtime import validation for Faster-Whisper, CTranslate2 and PyAV.
- `pip check` validation.
- Initial repository documentation baseline.

### VERIFIED

The user executed the complete installation workflow successfully on 2026-10-09.

Observed successful runtime:

```text
Python          3.14.7
pip             26.2.1
faster-whisper  1.2.1
ctranslate2     4.8.2
PyAV            19.0.1
pip check       OK
WhisperModel    import OK
```

The installer reported `INSTALLATION RESULT: OK` and `Models downloaded: NO`.

### HISTORICAL NOTE

During the original validated bootstrap, `.gitignore` did not yet protect every runtime directory. The `v1.1.0-dev` installer candidate now ensures the required runtime exclusions additively.
