<!--
DOCUMENT INFORMATION
Document Name: CHANGELOG.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v2.0.0
Date / Time: 2026-10-10 04:20 CEST
Project: DeepEcho_faster_whisper
Status: Major stable release v2.0.0; source package ready for Git push.
Short description: Append-only project changelog.
-->

# DeepEcho_faster_whisper — Changelog

## v2.0.0 — 2026-10-10 04:20 CEST — Bruno DELNOZ

### MAJOR STABLE RELEASE

- RELEASED: first major stable project version `V2.0.0` based strictly on the `V1.1.4-dev` source set.
- CHANGED: synchronized current version/date/status in **all** project scripts, metadata and Markdown documents, `requirements.txt`, and appended an additive release note to `.gitignore`.
- CHANGED: runtime installer, model manager and transcriber log/version labels now show `V2.0.0`.
- ADDED: `SPECIFICATIONS.pdf` regenerated from the **complete current** `SPECIFICATIONS.md` using the approved NoXoZ.be layout (cover, clickable table of contents, PDF bookmarks, versioned header/footer).
- DOCUMENTED: `SPECIFICATIONS.md` is authoritative and PDF regeneration is mandatory after future Markdown specification changes.
- PRESERVED: V1.1.4-dev recursive MP4 scanning, sequential transcription, model management, output filenames and Processing-Time reports unchanged.
- SECURITY: no source videos, private transcriptions or runtime media copied or staged inside the repository; rejected V1.1.3-dev recovery logic remains excluded.
- PACKAGING: complete project ZIP with 14 files, including both specifications source and PDF; runtime artifacts excluded.
- NOTE: actual Git push / remote release tag is performed only by the user.


## v1.1.4-dev — 2026-10-10 04:00 CEST — Bruno DELNOZ

### Recursive MP4 transcription discovery

- ADDED: `--recursive`, `--recursif`, `--récursif`, and `--récursive` to `transcribe.sh` and `transcribe.py`.
- ADDED: recursive scan from the process current working directory (`.`), or `--source-dir` if specified, including all nested MP4s.
- FIXED: shell expansion of `--source *.mp4` no longer limits the recursive scan to only expanded top-level MP4s.
- ADDED: deterministic ordering, duplicate suppression, `.MP4` case-insensitivity and symlink traversal exclusion in recursive mode.
- PRESERVED: previous nonrecursive source selection, single-run sequential transcription, all output filenames/locations and Processing-Time benchmarking.
- PRIVACY: no source-media copies, local staging, or recovery data in the code repository.
- BASELINE: forked from v1.1.2-dev; v1.1.3-dev recovery implementation was rejected and is not included.
- CHANGED: README, INSTALL, EXAMPLES, SPECIFICATIONS and script help/changelogs updated.
- DEFERRED: no regeneration or packaging of `SPECIFICATIONS.pdf` until the Markdown is validated.
- STATUS: validation candidate; not v2.0 final release.

## v1.1.2-dev — 2026-10-09 22:08 CEST — Bruno DELNOZ

### Transcription usability and comparison

- CHANGED: `transcribe.sh` and `transcribe.py` help/examples keep `--model` last for rapid model swapping.
- CHANGED: transcript filenames now include the selected model immediately before the run timestamp.
- ADDED: normal transcription runtime logs start with the exact executed command/argv.
- ADDED: one source-local `.logs/<source>-Processing-Time-<model>-<timestamp>.md` benchmark report per processed source.
- ADDED: invariant Processing-Time report template: identical headers, field order, units and structure across models; unavailable values remain as `N/A`.
- ADDED: media duration, model load time, preprocessing time, transcription/output time, total source time, real-time factor and processing speed measurements.
- DEFERRED BY USER: `SPECIFICATIONS.pdf` regeneration/packaging until scripting and Markdown validation are finished. The existing PDF remains untouched.
- CHANGED: README, INSTALL, EXAMPLES and SPECIFICATIONS synchronized with the new naming/logging/benchmark contract.
- STATUS: Validation candidate; not a release tag.

## v1.1.1-dev — 2026-10-09 21:05 CEST — Bruno DELNOZ

### STATUS

- Validation candidate update; still not a final release/tag.

### ADDED — MODEL SIZE VISIBILITY

- Added `--size` as a read-only list modifier.
- Added `./getModels.sh --exec --list --size`.
- Added the matching Python backend form.
- Live remote size is queried from Hugging Face metadata without downloading model payloads.
- Reported remote size is scoped to the exact file patterns requested by Faster-Whisper's downloader rather than blindly using whole-repository storage.
- Local on-disk model directory size is shown beside remote download size for diagnosis of partial/corrupt downloads.
- Normal `--exec --list` remains available without remote-size metadata lookup.
- Size lookup failures are explicit; the scripts do not fabricate model sizes.

### CHANGED — MODEL MANAGEMENT

- `getModels.sh` incremented to `V1.1.1-dev`.
- `getModels.py` incremented to `V1.1.1-dev`.
- Existing multi-model downloads, default skip, INCOMPLETE handling and `--force` replacement remain unchanged.

### DOCUMENTATION

- Updated `README.md`, `INSTALL.md`, `SPECIFICATIONS.md` and `EXAMPLES.md` with the size-query workflow.

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
