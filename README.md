<!--
DOCUMENT INFORMATION
Document Name: README.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.0.0
Date / Time: 2026-10-09 12:56 CEST
Project: DeepEcho_faster_whisper
Short description: Project overview and current installation status.
-->

# DeepEcho_faster_whisper

`DeepEcho_faster_whisper` is the scripting repository for a Faster-Whisper based transcription workflow.

The repository contains reusable code and documentation. Source videos, generated transcriptions, generated Markdown transcripts, operational transcription logs, and model data are intentionally kept outside the public repository.

## Current status

The installation/bootstrap layer is implemented and has been executed successfully.

Current validated runtime from the 2026-10-09 installation:

```text
Python          3.14.7
pip             26.2.1
faster-whisper  1.2.1
ctranslate2     4.8.2
PyAV            19.0.1
pip check       OK
WhisperModel    import OK
Models          not downloaded by installer
```

The transcription layer is the next project phase and is not yet implemented.

## Repository layout

```text
DeepEcho_faster_whisper/
├── install_pip.sh
├── install.sh
├── requirements.txt
├── SPECIFICATIONS.md
├── README.md
├── CHANGELOG.md
├── INSTALL.md
├── WHY.md
├── EXAMPLES.md
└── .venv/                 # local runtime only
```

## Installation model

Installation is intentionally split into two stages.

### Stage 1 — Python bootstrap

`install_pip.sh` prepares the isolated Python environment.

It checks prerequisites and free disk space on the current working directory (`.`), creates the project-local `.venv`, upgrades pip/setuptools/wheel inside `.venv`, and creates or preserves `requirements.txt` with the Faster-Whisper requirement.

### Stage 2 — Faster-Whisper runtime

`install.sh` installs and validates the runtime inside the existing `.venv`.

It checks `.venv` and `requirements.txt`, checks free space, installs requirements with `--no-cache-dir`, runs `pip check`, and validates Faster-Whisper, CTranslate2, PyAV, and `WhisperModel`.

It does not download a Whisper model.

## Quick installation

```bash
./install_pip.sh --prerequis
./install_pip.sh --install
./install.sh --prerequis
./install.sh --install
```

## CLI controls

Both installer scripts support:

```text
--help       -h
--exec       -exe
--simulate   -s
--prerequis  -pr
--install    -i
--changelog  -ch
--purge      -pu
```

Launching either script without arguments displays help and performs no installation.

## Disk-space policy

The installers check the filesystem backing the real current working directory (`.`). They also check the project filesystem when it differs from the current working directory/filesystem.

The current minimum is `4096 MiB` free.

## Runtime isolation

All Python packages are installed under `./.venv/`. No system-wide pip installation is used.

`requirements.txt` currently pins `faster-whisper==1.2.1`.

## Data-location policy

The repository is code/documentation only. The future transcription workflow must default to the directory from which the transcription command is executed.

By design, MP4/video inputs, private audio, generated transcriptions, generated transcript Markdown, operational transcription logs, and Whisper model data do not belong in the public repository.

## Documentation

- `SPECIFICATIONS.md` — current functional contract and future transcription boundary.
- `INSTALL.md` — installation, checks, simulation and purge.
- `WHY.md` — architecture rationale.
- `CHANGELOG.md` — append-only project history.
- `EXAMPLES.md` — reserved for the future stabilized transcription examples.

## Project boundary

This repository replaces the old `whisper.cpp`-oriented installation approach for this new Faster-Whisper project.

The current implementation deliberately avoids cloning or compiling `whisper.cpp`: Faster-Whisper is installed as a Python runtime dependency inside the isolated project environment.
