<!--
DOCUMENT INFORMATION
Document Name: SPECIFICATIONS.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.0.0
Date / Time: 2026-10-09 12:56 CEST
Project: DeepEcho_faster_whisper
Short description: Current repository and installer specifications, plus the agreed boundary for the future transcription layer.
-->

# DeepEcho_faster_whisper — Specifications

## 1. Purpose

`DeepEcho_faster_whisper` is the public scripting repository for the user's Faster-Whisper tooling.

The repository stores reusable scripts and project documentation. It is not the storage location for source videos, generated transcriptions, generated Markdown transcripts, operational logs, model caches, or other private working data.

## 2. Scope

The current implemented scope is the installation/bootstrap layer:

- `install_pip.sh`
- `install.sh`
- project-local `.venv`
- `requirements.txt`
- Faster-Whisper Python runtime installation and validation

The transcription layer is planned but is not yet implemented in this repository version.

## 3. Existing verified behavior

The installation workflow has been executed successfully on the user's Kali Linux environment.

Verified runtime state from that execution:

- Python: `3.14.7`
- pip inside `.venv`: `26.2.1`
- Faster-Whisper: `1.2.1`
- CTranslate2: `4.8.2`
- PyAV: `19.0.1`
- dependency consistency check: successful
- `WhisperModel` import: successful
- model download during installation: none

The installation completed inside the project-local `.venv`.

## 4. Repository architecture

Current root-level runtime/project files:

```text
DeepEcho_faster_whisper/
├── install_pip.sh
├── install.sh
├── requirements.txt
├── .venv/                 # local runtime environment; not project source
├── README.md
├── CHANGELOG.md
├── INSTALL.md
├── WHY.md
├── SPECIFICATIONS.md
└── EXAMPLES.md
```

Other repository control directories such as `.git/`, `.old/`, and `.zip/` are managed separately from the application logic.

## 5. Functional requirements — installer layer

### 5.1 `install_pip.sh`

`install_pip.sh` is the first installer stage.

It must:

- display structured help when launched without arguments;
- support `--help/-h`;
- support `--prerequis/-pr`;
- support `--simulate/-s`;
- support `--install/-i`;
- support `--exec/-exe` as the real bootstrap action;
- support `--changelog/-ch`;
- support `--purge/-pu`;
- require Python `>= 3.9`;
- verify Python `venv` support;
- verify the required shell utilities;
- check available disk space on the current directory filesystem (`.`);
- check project filesystem space too when the project directory differs from the current runtime directory/filesystem;
- require at least `4096 MiB` of free space;
- create the project-local `.venv` only when absent;
- preserve an existing valid `.venv`;
- bootstrap/upgrade `pip`, `setuptools`, and `wheel` inside `.venv`;
- use `--no-cache-dir` during pip bootstrap;
- create `requirements.txt` only when absent;
- preserve existing `requirements.txt` content;
- ensure `faster-whisper==1.2.1` is declared;
- validate the virtual environment after bootstrap;
- never install Faster-Whisper itself during this first stage;
- never install Python packages system-wide.

`--purge` may remove only the project-local `.venv`. It must preserve `requirements.txt`.

### 5.2 `install.sh`

`install.sh` is the second installer stage.

It must:

- display structured help when launched without arguments;
- support `--help/-h`;
- support `--prerequis/-pr`;
- support `--simulate/-s`;
- support `--install/-i`;
- support `--exec/-exe` as the real installation action;
- support `--changelog/-ch`;
- support `--purge/-pu`;
- refuse installation when the project-local `.venv` is missing or invalid;
- refuse installation when `requirements.txt` is missing;
- verify that Faster-Whisper is declared in `requirements.txt`;
- check available disk space on the current directory filesystem (`.`);
- check project filesystem space too when applicable;
- require at least `4096 MiB` of free space;
- install requirements strictly through `.venv/bin/python -m pip`;
- use `--no-cache-dir`;
- run `pip check`;
- validate imports and report versions for `faster-whisper`, `ctranslate2`, and `av`;
- validate `WhisperModel` import;
- not download Whisper models during installation;
- never install Faster-Whisper system-wide.

`--purge` may remove only the project-local `.venv`. It must preserve `requirements.txt`.

## 6. Installation order

The required physical execution order is:

```text
1. install_pip.sh
2. install.sh
```

Canonical sequence:

```bash
./install_pip.sh --prerequis
./install_pip.sh --install
./install.sh --prerequis
./install.sh --install
```

## 7. Planned transcription requirements

The transcription layer is intentionally separated from the installer layer and will be implemented later.

The agreed baseline is:

- source media is not stored in this public repository;
- generated transcriptions are not stored in this public repository;
- generated Markdown transcripts are not stored in this public repository;
- operational transcription logs are not stored in this public repository;
- transcription scripts must be callable from a directory containing or referencing the media to process;
- the default working location is the current working directory (`.`);
- default generated transcription artefacts must go to the current working directory unless an explicit destination argument overrides it;
- MP4 is a primary input format;
- French transcription is a primary use case;
- transcription must preserve the spoken content in raw form without censorship or editorial omission;
- model selection must be configurable;
- audio amplification/normalization must be available as explicit processing options rather than hidden behavior;
- repository code and private working data must remain separated.

No transcription CLI, output naming scheme, timestamp format, model default, or model-cache location is considered implemented until the corresponding scripts are created and validated.

## 8. Non-functional requirements

- Python runtime isolation through project-local `.venv`.
- No `sudo pip`.
- No system-wide Python package installation.
- No source video committed as project content.
- No generated transcript committed as project content by design.
- No generated operational log committed as project content by design.
- No Whisper model committed to the repository.
- No secret embedded in scripts or documentation.
- HTTPS-only external package/model retrieval.
- Installer actions must be explicit.
- No-argument execution must not install or modify the system.
- `--prerequis` must remain read-only.
- `--simulate` must not modify the runtime.
- Installer failures must stop with a non-zero exit status.

## 9. Inputs

### Current installer inputs

- current working directory (`.`);
- repository location;
- system Python;
- `requirements.txt` when already present;
- CLI control action.

### Future transcription inputs

- media file(s), primarily MP4;
- optional explicit source path;
- optional explicit destination path;
- transcription/model/audio-processing options.

## 10. Outputs

### Current installer outputs

`install_pip.sh` may create:

- `.venv/`
- `requirements.txt` when absent

`install.sh` modifies only the Python environment under `.venv` by installing declared runtime dependencies.

### Future transcription outputs

The exact file set will be specified with the transcription implementation. Markdown transcription output is part of the agreed future scope.

## 11. Files and directories concerned

### Repository source/documentation

```text
install_pip.sh
install.sh
requirements.txt
README.md
CHANGELOG.md
INSTALL.md
WHY.md
SPECIFICATIONS.md
EXAMPLES.md
```

### Local runtime

```text
.venv/
```

### Explicitly outside repository working data

- videos;
- audio source files;
- generated transcriptions;
- generated transcript Markdown;
- transcription logs;
- model cache/data unless a later specification explicitly defines a separate local location.

## 12. Interfaces and commands

Current control interface for both installer scripts:

```text
--help       -h
--exec       -exe
--simulate   -s
--prerequis  -pr
--install    -i
--changelog  -ch
--purge      -pu
```

No argument must display help only.

## 13. Constraints and safety rules

- `install_pip.sh` must run before `install.sh` on a fresh checkout/runtime.
- `.venv` must remain project-local.
- Installation must not fall back to system Python package locations.
- Free-space checks must use the real current working directory (`.`), not assume that the repository partition is `/`.
- The project directory may be on a dedicated filesystem and must be treated as such.
- Purge actions are restricted to runtime artefacts owned by these scripts.
- Existing `requirements.txt` content must be preserved.
- Model downloads are outside the current installer stage.

## 14. Validation and acceptance criteria

The installer layer is accepted when:

1. no-argument invocation displays help;
2. `--prerequis` reports present/missing prerequisites and disk-space state;
3. `install_pip.sh --install` creates or preserves `.venv`;
4. `requirements.txt` contains Faster-Whisper;
5. `install.sh --install` installs into `.venv` only;
6. `pip check` succeeds;
7. Faster-Whisper, CTranslate2, and PyAV imports succeed;
8. `WhisperModel` imports successfully;
9. no model is downloaded by the installers;
10. purge does not remove repository source/documentation or `requirements.txt`.

The user execution dated 2026-10-09 satisfied the current installation acceptance criteria.

## 15. Task-scoped specification boundary

This version specifies the installer/bootstrap layer and records only the already agreed high-level transcription boundary.

Detailed transcription CLI behavior will be specified when transcription implementation begins.

## 16. Out-of-scope items

Not implemented in this version:

- transcription script;
- MP4 batch processing;
- model download management;
- model-cache relocation;
- transcript timestamp formatting;
- subtitle generation;
- transcript naming policy;
- audio normalization implementation;
- audio amplification implementation;
- GPU/CUDA installation;
- web UI or desktop UI.

## 17. Changelog

### v1.0.0 — 2026-10-09 12:56 CEST — Bruno DELNOZ

- ADDED: Initial repository specification for the Faster-Whisper installation layer.
- ADDED: Verified installation behavior and runtime versions from the user execution.
- ADDED: Explicit two-stage installer contract.
- ADDED: Current-directory disk-space requirement.
- ADDED: Repository/private-working-data separation.
- ADDED: High-level future transcription boundary without claiming unimplemented behavior.
