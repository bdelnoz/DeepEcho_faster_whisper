<!--
DOCUMENT INFORMATION
Document Name: INSTALL.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.1.0-dev
Date / Time: 2026-10-09 18:32 CEST
Project: DeepEcho_faster_whisper
Status: Validation candidate; not a release tag.
Short description: Complete automated installation, model-management and first-transcription workflow.
-->

# DeepEcho_faster_whisper — Installation

## 1. Goal

The installation workflow is designed so that the user does not need to create runtime directories manually, edit `.gitignore` manually, create `requirements.txt` manually, install Python packages system-wide, or copy source videos into the repository.

The normal order is:

```text
1. install_pip.sh
2. install.sh
3. getModels.sh
4. transcribe.sh
```

The two installer scripts prepare the runtime. `getModels.sh` downloads one or more local Faster-Whisper models. `transcribe.sh` consumes media from any working/source directory.

## 2. Repository prerequisites

The repository should contain at least:

```text
install_pip.sh
install.sh
getModels.sh
getModels.py
transcribe.sh
transcribe.py
requirements.txt      # may already exist; install_pip.sh can create it if absent
.gitignore            # may already exist; installer can create/extend it
README.md
CHANGELOG.md
INSTALL.md
SPECIFICATIONS.md
EXAMPLES.md
```

`WHY.md` is intentionally not part of the current project.

## 3. Stage 1 — inspect bootstrap prerequisites

Run:

```bash
./install_pip.sh --prerequis
```

This is read-only.

It checks:

- Bash;
- Python 3;
- Python version >= 3.9;
- Python `venv` support;
- required shell utilities;
- current-directory free space;
- project-filesystem free space when relevant;
- current `.gitignore` state.

It does not create `.venv`, logs, requirements or Git-ignore entries.

## 4. Stage 1 — simulate bootstrap

Run:

```bash
./install_pip.sh --simulate
```

Simulation describes the operations that a real bootstrap would perform, but creates no files and no logs.

## 5. Stage 1 — real bootstrap

Run:

```bash
./install_pip.sh --install
```

Equivalent real-action form:

```bash
./install_pip.sh --exec
```

A real bootstrap performs the following automatically:

1. creates a timestamped log under `./logs/`;
2. checks prerequisites and free space;
3. extends `.gitignore` only with required missing runtime exclusions;
4. creates or preserves `./.venv/`;
5. upgrades `pip`, `setuptools` and `wheel` inside `.venv`;
6. creates `requirements.txt` when absent;
7. preserves existing `requirements.txt` content when present;
8. adds `faster-whisper==1.2.1` only when no Faster-Whisper requirement exists;
9. validates `.venv` Python and pip.

### 5.1 Bootstrap log

The log is created under:

```text
./logs/install_pip-V1.1.0-dev-YYYYMMDD-HHMM-SS.log
```

The `logs/` directory and `*.log` files are excluded from Git.

## 6. Automatic `.gitignore` maintenance

Both real installer stages protect runtime data automatically.

The policy is strict and additive:

- no existing line is removed;
- no existing comment is removed;
- existing duplicate lines remain untouched;
- missing required lines are appended;
- existing lines are not reordered;
- a missing `.gitignore` may be created during a real install action.

The required runtime set includes:

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

The delivered `.gitignore` retains all historical rules that were already present.

## 7. `requirements.txt` ownership

`install_pip.sh` owns creation/preservation of `requirements.txt`.

If the file does not exist, the bootstrap creates:

```text
faster-whisper==1.2.1
```

with project comments.

If the file already exists, its content is preserved. If no Faster-Whisper declaration is present, the bootstrap appends the required declaration instead of replacing the file.

`install.sh` consumes the resulting file. It does not own the initial creation logic.

## 8. Stage 2 — inspect runtime prerequisites

Run:

```bash
./install.sh --prerequis
```

This validates:

- `.venv/bin/python`;
- Python >= 3.9 inside the venv;
- pip inside `.venv`;
- `requirements.txt`;
- Faster-Whisper declaration;
- free disk space;
- required shell utilities;
- current `.gitignore` state.

This action is read-only and creates no log.

## 9. Stage 2 — simulate runtime installation

Run:

```bash
./install.sh --simulate
```

This action does not install packages and does not create a log.

## 10. Stage 2 — install Faster-Whisper runtime

Run:

```bash
./install.sh --install
```

Equivalent real-action form:

```bash
./install.sh --exec
```

The real runtime installer automatically:

1. creates a timestamped installer log under `./logs/`;
2. validates `.venv` and `requirements.txt`;
3. extends `.gitignore` additively when required entries are missing;
4. installs requirements through `.venv/bin/python -m pip`;
5. uses `--no-cache-dir`;
6. runs `pip check`;
7. validates Faster-Whisper import/version;
8. validates CTranslate2 import/version;
9. validates PyAV import/version;
10. validates `WhisperModel` import;
11. confirms that no Whisper model is downloaded by this stage.

### 10.1 Runtime install log

The log is created under:

```text
./logs/install-V1.1.0-dev-YYYYMMDD-HHMM-SS.log
```

## 11. Complete normal runtime installation sequence

Recommended first setup:

```bash
./install_pip.sh --prerequis
./install_pip.sh --simulate
./install_pip.sh --install

./install.sh --prerequis
./install.sh --simulate
./install.sh --install
```

The simulation commands are optional but useful before a first real installation.

## 12. Installer purge

Both installer scripts expose:

```text
--purge
-pu
```

The purge scope remains intentionally narrow: the project-local `.venv` only.

Examples:

```bash
./install_pip.sh --purge
./install.sh --purge
```

Purge preserves:

- `requirements.txt`;
- repository source files;
- documentation;
- downloaded models;
- generated installer logs.

Purge is a real modifying action and therefore creates a timestamped log under `./logs/`.

After purge, rebuild in the normal order:

```bash
./install_pip.sh --install
./install.sh --install
```

## 13. Installer help and changelogs

```bash
./install_pip.sh --help
./install_pip.sh --changelog

./install.sh --help
./install.sh --changelog
```

Launching either installer without arguments displays help and performs no action.

## 14. Download Faster-Whisper models

The runtime installation intentionally does not download models.

Use:

```bash
./getModels.sh --exec --list
```

This shows the runtime registry and local status.

## 15. Download one model

Example:

```bash
./getModels.sh --exec --download --model tiny
```

Default target:

```text
./models/tiny/
```

## 16. Download several models

Example:

```bash
./getModels.sh --exec --download --model base small medium
```

The same command supports any combination of valid model names exposed by Faster-Whisper.

## 17. Simulate model download

```bash
./getModels.sh --simulate --download --model base small medium
```

Simulation does not create, remove or download model data.

## 18. Existing model behavior

Without `--force`:

- a complete local model is skipped;
- a missing model is downloaded;
- an incomplete/corrupt local directory is reported as an error and is not silently overwritten.

## 19. Force model replacement

Use `--force` when the local copy is suspected to be corrupt or must be rebuilt:

```bash
./getModels.sh --exec --download --model base small medium --force
```

For every requested valid model, `--force` removes the existing local target first and downloads a fresh copy.

Use simulation first when desired:

```bash
./getModels.sh --simulate --download --model base small medium --force
```

## 20. Custom model directory

Example:

```bash
./getModels.sh --exec --download --model large-v3 --models-dir /mnt/models
```

When `--models-dir` is not specified, the default remains repository-local `./models/`.

## 21. Verify models after download

Run:

```bash
./getModels.sh --exec --list
```

Status values are:

```text
INSTALLED
INCOMPLETE
not installed
```

## 22. First transcription prerequisite check

Run:

```bash
./transcribe.sh --prerequis
```

This validates the local runtime and models without creating transcription output.

## 23. First transcription simulation

From the directory containing the media, or by using `--source-dir`, run for example:

```bash
/path/to/DeepEcho_faster_whisper/transcribe.sh --simulate --model tiny --source '*.mp4'
```

Simulation resolves:

- media sources;
- local model;
- output paths;
- run timestamp;
- runtime options.

It does not create `.transcription`, `.logs`, logs or transcript files.

## 24. First real transcription

Example:

```bash
/path/to/DeepEcho_faster_whisper/transcribe.sh --exec --model tiny --source '*.mp4'
```

Default transcription language is French. `--language fr` is not required.

## 25. Transcription output layout

For source:

```text
/path/videos/2011.mp4
```

a real run creates output similar to:

```text
/path/videos/2011.mp4.transcription_timestamps-20261009-1832-45.md
/path/videos/.transcription/2011.mp4.transcription-20261009-1832-45.md
/path/videos/.transcription/2011.mp4.transcript-20261009-1832-45.txt
/path/videos/.logs/transcribe-V1.1.0-dev-20261009-1832-45.log
```

The same timestamp identifies all output generated by that invocation.

## 26. Multi-source and spaces

These forms are supported:

```bash
./transcribe.sh --exec --model tiny --source '*.mp4'
./transcribe.sh --exec --model tiny --source *.mp4
./transcribe.sh --exec --model tiny --source 'video with spaces.mp4'
./transcribe.sh --exec --model tiny --source first.mp4 'second file.mp4'
```

The shell-expanded glob case accepts multiple filenames, including names with spaces.

## 27. Multi-directory batches

When sources from several directories are selected:

- each source uses its own `.transcription/` directory by default;
- each involved source directory receives a `.logs/` run log;
- all batch artifacts use the same run timestamp.

## 28. Destination override

Use `--dest-dir` when plain Markdown/TXT should be centralized elsewhere:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --dest-dir /path/results
```

Plain output goes to:

```text
/path/results/.transcription/
```

The timestamped Markdown and runtime log remain beside/under the source directory by design.

## 29. Optional audio processing

VAD:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --vad
```

Normalization:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --normalize
```

Amplification factor:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --amplify 2
```

Amplification in dB:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --amplify-db 6
```

The source media is never modified. FFmpeg preprocessing uses a temporary audio copy.

## 30. Runtime compatibility note

Faster-Whisper `1.2.1` passes `metadata_errors` to PyAV. PyAV `19.x` removed this argument.

`transcribe.py` detects PyAV 19+ and installs a process-local compatibility wrapper that removes only this obsolete keyword before the actual PyAV `open()` call.

No manual downgrade is required by this project.

## 31. What the user does not have to do manually

The intended workflow does not require manual creation of:

- `.venv`;
- `requirements.txt`;
- `logs/`;
- `.transcription/`;
- `.logs/`;
- model target subdirectories;
- required `.gitignore` runtime entries.

The scripts own those tasks when the corresponding real action requires them.

## 32. Validation build status

This package is intentionally labeled `v1.1.0-dev` until the user validates the major update.

It is not a final release declaration and is not a Git tag instruction.
