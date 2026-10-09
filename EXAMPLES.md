<!--
DOCUMENT INFORMATION
Document Name: EXAMPLES.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.1.0-dev
Date / Time: 2026-10-09 18:32 CEST
Project: DeepEcho_faster_whisper
Status: Validation candidate; not a release tag.
Short description: Structured examples for every current script and every supported argument.
-->

# DeepEcho_faster_whisper — Examples

This document is organized by script. It starts with simple examples and progresses toward combined examples. Every currently supported CLI argument is represented by at least one example.

---

# 1. `install_pip.sh`

`install_pip.sh` is the first installation stage. It prepares the project-local Python environment, `requirements.txt`, runtime Git exclusions and bootstrap logs for real actions.

## 1.1 No arguments — help only

```bash
./install_pip.sh
```

Expected behavior: display help and perform no modification.

## 1.2 `--help` / `-h`

```bash
./install_pip.sh --help
./install_pip.sh -h
```

## 1.3 `--prerequis` / `-pr`

```bash
./install_pip.sh --prerequis
./install_pip.sh -pr
```

Read-only prerequisite checks. No log is created.

## 1.4 `--simulate` / `-s`

```bash
./install_pip.sh --simulate
./install_pip.sh -s
```

Simulation shows the intended bootstrap operations without modifying files.

## 1.5 `--install` / `-i`

```bash
./install_pip.sh --install
./install_pip.sh -i
```

Real bootstrap action. It may create/update:

```text
.venv/
requirements.txt
.gitignore
logs/install_pip-V1.1.0-dev-YYYYMMDD-HHMM-SS.log
```

## 1.6 `--exec` / `-exe`

```bash
./install_pip.sh --exec
./install_pip.sh -exe
```

Equivalent real action to `--install`.

## 1.7 `--changelog` / `-ch`

```bash
./install_pip.sh --changelog
./install_pip.sh -ch
```

## 1.8 `--purge` / `-pu`

```bash
./install_pip.sh --purge
./install_pip.sh -pu
```

Removes only the project `.venv`. `requirements.txt`, logs and repository source are preserved.

## 1.9 Typical first-stage sequence

```bash
./install_pip.sh --prerequis
./install_pip.sh --simulate
./install_pip.sh --install
```

---

# 2. `install.sh`

`install.sh` is the second installation stage. It installs and validates Faster-Whisper inside the `.venv` created by `install_pip.sh`.

## 2.1 No arguments — help only

```bash
./install.sh
```

## 2.2 `--help` / `-h`

```bash
./install.sh --help
./install.sh -h
```

## 2.3 `--prerequis` / `-pr`

```bash
./install.sh --prerequis
./install.sh -pr
```

Checks `.venv`, `requirements.txt`, disk space and current `.gitignore` state.

## 2.4 `--simulate` / `-s`

```bash
./install.sh --simulate
./install.sh -s
```

No package or file is modified.

## 2.5 `--install` / `-i`

```bash
./install.sh --install
./install.sh -i
```

Real runtime installation. A log is generated under:

```text
./logs/install-V1.1.0-dev-YYYYMMDD-HHMM-SS.log
```

## 2.6 `--exec` / `-exe`

```bash
./install.sh --exec
./install.sh -exe
```

Equivalent real action to `--install`.

## 2.7 `--changelog` / `-ch`

```bash
./install.sh --changelog
./install.sh -ch
```

## 2.8 `--purge` / `-pu`

```bash
./install.sh --purge
./install.sh -pu
```

Removes only `.venv` and leaves the repository, models, requirements and logs in place.

## 2.9 Complete two-stage installation

```bash
./install_pip.sh --prerequis
./install_pip.sh --install
./install.sh --prerequis
./install.sh --install
```

---

# 3. `getModels.sh`

`getModels.sh` is the normal user-facing model-management interface.

## 3.1 No arguments — help only

```bash
./getModels.sh
```

## 3.2 `--help` / `-h`

```bash
./getModels.sh --help
./getModels.sh -h
```

The help includes the full 19-model reference immediately before its examples.

## 3.3 `--prerequis` / `-pr`

```bash
./getModels.sh --prerequis
./getModels.sh -pr
```

## 3.4 `--changelog` / `-ch`

```bash
./getModels.sh --changelog
./getModels.sh -ch
```

## 3.5 `--exec --list`

```bash
./getModels.sh --exec --list
./getModels.sh -exe --list
```

This lists every model exposed by the installed Faster-Whisper runtime and reports local state:

```text
INSTALLED
INCOMPLETE
not installed
```

## 3.6 `--simulate --download`

```bash
./getModels.sh --simulate --download --model tiny
```

No model data is written.

## 3.7 `--exec --download`

```bash
./getModels.sh --exec --download --model tiny
```

## 3.8 `--model` — one model

```bash
./getModels.sh --exec --download --model base
```

## 3.9 `--model` — multiple models

```bash
./getModels.sh --exec --download --model base small medium
```

All requested valid names are processed in the same invocation.

## 3.10 `--models-dir`

```bash
./getModels.sh --exec --download --model tiny --models-dir /mnt/models
```

Multiple models with a custom location:

```bash
./getModels.sh --exec --download --model base small medium --models-dir /mnt/models
```

## 3.11 Existing complete models — default skip

```bash
./getModels.sh --exec --download --model tiny base small
```

If `tiny` is already complete, it is reported as `SKIP` and the remaining requested models continue.

## 3.12 Incomplete/corrupt model without force

```bash
./getModels.sh --exec --download --model small
```

If `models/small/` exists but fails completeness validation, the script reports the problem and instructs the user to use `--force`.

## 3.13 `--force` — one model

```bash
./getModels.sh --exec --download --model tiny --force
```

The existing local target is removed and downloaded again.

## 3.14 `--force` — multiple models

```bash
./getModels.sh --exec --download --model base small medium --force
```

`--force` applies to every requested valid model.

## 3.15 Simulate a forced multi-model replacement

```bash
./getModels.sh --simulate --download --model base small medium --force
```

No directory is removed and nothing is downloaded.

## 3.16 Complex model example

```bash
./getModels.sh --exec --download --model tiny base small medium large-v3 --models-dir /mnt/data/whisper-models --force
```

This combines:

- `--exec`;
- `--download`;
- multi-value `--model`;
- custom `--models-dir`;
- `--force`.

---

# 4. `getModels.py`

`getModels.py` is the backend. Normal users should prefer `getModels.sh`, but the backend exposes the same model-management business arguments.

## 4.1 Help

```bash
./.venv/bin/python ./getModels.py --help
```

## 4.2 Prerequisites

```bash
./.venv/bin/python ./getModels.py --prerequis
```

## 4.3 Changelog

```bash
./.venv/bin/python ./getModels.py --changelog
```

## 4.4 List

```bash
./.venv/bin/python ./getModels.py --exec --list
```

## 4.5 Simulate one model

```bash
./.venv/bin/python ./getModels.py --simulate --download --model tiny
```

## 4.6 Download one model

```bash
./.venv/bin/python ./getModels.py --exec --download --model tiny
```

## 4.7 Download several models

```bash
./.venv/bin/python ./getModels.py --exec --download --model base small medium
```

## 4.8 Custom models directory

```bash
./.venv/bin/python ./getModels.py --exec --download --model tiny --models-dir /mnt/models
```

## 4.9 Forced replacement

```bash
./.venv/bin/python ./getModels.py --exec --download --model base small medium --force
```

---

# 5. `transcribe.sh`

`transcribe.sh` is the normal user-facing transcription interface.

## 5.1 No arguments — help only

```bash
./transcribe.sh
```

## 5.2 `--help` / `-h`

```bash
./transcribe.sh --help
./transcribe.sh -h
```

## 5.3 `--prerequis` / `-pr`

```bash
./transcribe.sh --prerequis
./transcribe.sh -pr
```

No transcription, log or output file is created.

## 5.4 `--changelog` / `-ch`

```bash
./transcribe.sh --changelog
./transcribe.sh -ch
```

## 5.5 `--simulate` / `-s`

```bash
./transcribe.sh --simulate --model tiny --source video.mp4
./transcribe.sh -s --model tiny --source video.mp4
```

Simulation resolves the complete plan without creating `.transcription/`, `.logs/` or output files.

## 5.6 `--exec` / `-exe`

```bash
./transcribe.sh --exec --model tiny --source video.mp4
./transcribe.sh -exe --model tiny --source video.mp4
```

## 5.7 `--model`

```bash
./transcribe.sh --exec --model tiny --source video.mp4
```

Another local model:

```bash
./transcribe.sh --exec --model medium --source video.mp4
```

## 5.8 `--models-dir`

```bash
./transcribe.sh --exec --model tiny --models-dir /mnt/models --source video.mp4
```

## 5.9 `--source` — one file

```bash
./transcribe.sh --exec --model tiny --source video.mp4
```

## 5.10 `--source` — filename with spaces

```bash
./transcribe.sh --exec --model tiny --source '2015-02-06 07.01.33.mp4'
```

## 5.11 `--source` — quoted glob

```bash
./transcribe.sh --exec --model tiny --source '*.mp4'
```

The script receives the pattern and resolves it internally.

## 5.12 `--source` — unquoted shell-expanded glob

```bash
./transcribe.sh --exec --model tiny --source *.mp4
```

Bash expands the glob first. The wrapper accepts all resulting filenames, including filenames containing spaces.

## 5.13 `--source` — prefix glob

```bash
./transcribe.sh --exec --model tiny --source 'VID_2016*.mp4'
```

## 5.14 `--source` — several values after one option

```bash
./transcribe.sh --exec --model tiny --source 2011.mp4 '2015-02-06 07.01.33.mp4' '2016-02-15 07.06.18.mp4'
```

## 5.15 Repeated `--source`

```bash
./transcribe.sh --exec --model tiny --source first.mp4 --source second.mp4
```

## 5.16 Default `*.mp4` source pattern

When `--source` is omitted:

```bash
./transcribe.sh --simulate --model tiny
```

The default pattern is `*.mp4` inside the selected source directory/current directory.

## 5.17 `--source-dir`

```bash
./transcribe.sh --exec --model tiny --source-dir /mnt/videos
```

With a pattern:

```bash
./transcribe.sh --exec --model tiny --source-dir /mnt/videos --source '*.mp4'
```

## 5.18 `--dest-dir`

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --dest-dir /mnt/results
```

Plain Markdown and TXT go to:

```text
/mnt/results/.transcription/
```

The timestamped Markdown and runtime log remain source-local.

## 5.19 `--language`

French is already default:

```bash
./transcribe.sh --exec --model tiny --source video.mp4
```

Explicit French:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --language fr
```

Automatic language detection:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --language auto
```

Another language code:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --language en
```

## 5.20 `--device`

CPU default:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --device cpu
```

A different supported CTranslate2 device may be supplied explicitly when the runtime supports it.

## 5.21 `--compute-type`

Default `int8`:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --compute-type int8
```

Another CTranslate2 compute type:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --compute-type float32
```

## 5.22 `--vad`

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --vad
```

VAD is opt-in.

## 5.23 `--no-vad`

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --no-vad
```

This explicitly selects the default OFF behavior.

## 5.24 `--normalize`

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --normalize
```

FFmpeg creates a temporary normalized WAV. The source is unchanged.

## 5.25 `--amplify`

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --amplify 2
```

## 5.26 `--amplify-db`

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --amplify-db 6
```

`--amplify` and `--amplify-db` are mutually exclusive.

## 5.27 `--timestamp`

Timestamped Markdown is enabled by default, but can be requested explicitly:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --timestamp
```

## 5.28 `--no-timestamp`

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --no-timestamp
```

Plain Markdown/TXT are still created.

## 5.29 `--force`

Normal runs allocate a fresh timestamp and therefore avoid overwriting old files automatically.

`--force` exists for the rare case where the exact timestamped target set already exists and deliberate replacement is wanted:

```bash
./transcribe.sh --exec --model tiny --source video.mp4 --force
```

## 5.30 Combined batch example

```bash
./transcribe.sh --exec --model medium --source '*.mp4' --language fr --device cpu --compute-type int8 --vad --normalize
```

## 5.31 Combined batch with amplification and explicit model directory

```bash
./transcribe.sh --exec --model medium --models-dir /mnt/models --source '*.mp4' --language fr --device cpu --compute-type int8 --amplify-db 6 --timestamp
```

## 5.32 Complex example with source and destination directories

```bash
./transcribe.sh --exec --model medium --models-dir /mnt/models --source-dir /mnt/source-videos --source 'VID_*.mp4' --dest-dir /mnt/results --language fr --device cpu --compute-type int8 --no-vad --normalize --timestamp
```

## 5.33 Multi-directory source example

```bash
./transcribe.sh --exec --model tiny --source /mnt/a/video1.mp4 /mnt/b/'video 2.mp4'
```

Default behavior:

```text
/mnt/a/.transcription/
/mnt/a/.logs/
/mnt/b/.transcription/
/mnt/b/.logs/
```

The same run timestamp is used in both source directories.

---

# 6. `transcribe.py`

The Python backend accepts the same transcription business arguments. Normally use `transcribe.sh`; direct examples are provided for testing/debugging.

## 6.1 Help

```bash
./.venv/bin/python ./transcribe.py --help
```

## 6.2 Prerequisites

```bash
./.venv/bin/python ./transcribe.py --prerequis
```

## 6.3 Changelog

```bash
./.venv/bin/python ./transcribe.py --changelog
```

## 6.4 Simulation

```bash
./.venv/bin/python ./transcribe.py --simulate --model tiny --source video.mp4
```

## 6.5 Execution

```bash
./.venv/bin/python ./transcribe.py --exec --model tiny --source video.mp4
```

## 6.6 Shell-expanded glob direct to Python

```bash
./.venv/bin/python ./transcribe.py --simulate --model tiny --source *.mp4
```

The Python parser accepts multiple values after `--source`.

## 6.7 Quoted glob direct to Python

```bash
./.venv/bin/python ./transcribe.py --simulate --model tiny --source '*.mp4'
```

## 6.8 Direct backend with spaces

```bash
./.venv/bin/python ./transcribe.py --exec --model tiny --source 'video with spaces.mp4'
```

## 6.9 Direct backend with all main runtime options

```bash
./.venv/bin/python ./transcribe.py --exec --model medium --models-dir /mnt/models --source-dir /mnt/videos --source '*.mp4' --dest-dir /mnt/results --language fr --device cpu --compute-type int8 --vad --normalize --timestamp
```

## 6.10 Direct backend with amplification factor

```bash
./.venv/bin/python ./transcribe.py --exec --model tiny --source video.mp4 --amplify 2
```

## 6.11 Direct backend with amplification dB

```bash
./.venv/bin/python ./transcribe.py --exec --model tiny --source video.mp4 --amplify-db 6
```

## 6.12 Direct backend without VAD and without timestamped Markdown

```bash
./.venv/bin/python ./transcribe.py --exec --model tiny --source video.mp4 --no-vad --no-timestamp
```

## 6.13 Direct backend forced exact-target replacement

```bash
./.venv/bin/python ./transcribe.py --exec --model tiny --source video.mp4 --force
```

---

# 7. End-to-end examples

## 7.1 Fresh setup + Tiny + one MP4

```bash
./install_pip.sh --install
./install.sh --install
./getModels.sh --exec --download --model tiny
/path/to/DeepEcho_faster_whisper/transcribe.sh --exec --model tiny --source video.mp4
```

## 7.2 Fresh setup + several models

```bash
./install_pip.sh --install
./install.sh --install
./getModels.sh --exec --download --model tiny base small medium
./getModels.sh --exec --list
```

## 7.3 Replace potentially corrupt local models

```bash
./getModels.sh --simulate --download --model base small medium --force
./getModels.sh --exec --download --model base small medium --force
./getModels.sh --exec --list
```

## 7.4 Transcribe every MP4 in the current directory

```bash
/path/to/DeepEcho_faster_whisper/transcribe.sh --exec --model medium --source *.mp4
```

## 7.5 Conservative raw French transcription

No VAD, no normalization and no amplification are needed because these are already OFF by default:

```bash
/path/to/DeepEcho_faster_whisper/transcribe.sh --exec --model medium --source '*.mp4'
```

## 7.6 Weak/quiet audio test with explicit amplification

```bash
/path/to/DeepEcho_faster_whisper/transcribe.sh --simulate --model medium --source video.mp4 --amplify-db 6
/path/to/DeepEcho_faster_whisper/transcribe.sh --exec --model medium --source video.mp4 --amplify-db 6
```

## 7.7 Explicit normalization + VAD

```bash
/path/to/DeepEcho_faster_whisper/transcribe.sh --exec --model medium --source '*.mp4' --normalize --vad
```

---

# 8. Output examples

For source:

```text
2011.mp4
```

with run timestamp:

```text
20261009-1832-45
```

the default generated artifacts are:

```text
2011.mp4
2011.mp4.transcription_timestamps-20261009-1832-45.md
.transcription/2011.mp4.transcription-20261009-1832-45.md
.transcription/2011.mp4.transcript-20261009-1832-45.txt
.logs/transcribe-V1.1.0-dev-20261009-1832-45.log
```

Installer examples use repository-local logs such as:

```text
logs/install_pip-V1.1.0-dev-20261009-1832-45.log
logs/install-V1.1.0-dev-20261009-1832-51.log
```

---

# 9. Changelog

## v1.1.0-dev — 2026-10-09 18:32 CEST — Bruno DELNOZ

- REPLACED: Placeholder examples document with complete per-script examples.
- ADDED: Example coverage for every current CLI argument.
- ADDED: Multi-model download examples.
- ADDED: `--force` model replacement examples.
- ADDED: quoted/unquoted glob and filename-with-spaces examples.
- ADDED: simple, intermediate and combined transcription examples.
- ADDED: output-layout and timestamp examples.
- STATUS: Validation candidate; not a release tag.

## v1.0.0 — 2026-10-09 12:56 CEST — Bruno DELNOZ

- ADDED: Initial placeholder `EXAMPLES.md`.
