<!--
DOCUMENT INFORMATION
Document Name: WHY.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.0.0
Date / Time: 2026-10-09 12:56 CEST
Project: DeepEcho_faster_whisper
Short description: Rationale for the Faster-Whisper repository architecture and two-stage installation model.
-->

# Why DeepEcho_faster_whisper Exists

## 1. Purpose

The project provides a clean Faster-Whisper foundation for a reusable local transcription workflow while separating reusable public code from private media and generated transcription data.

## 2. Why a new project

The older DeepEcho Whisper workflow used a different installation model including `whisper.cpp` cloning, CMake compilation, binary validation, and model handling.

Faster-Whisper has a different runtime architecture. For this project, cloning and compiling `whisper.cpp` would add complexity without serving the chosen runtime.

The new repository therefore starts with a Python-native Faster-Whisper environment.

## 3. Why two installer scripts

`install_pip.sh` owns Python-environment bootstrap: prerequisite checks, disk-space checks, `.venv` creation, pip tooling, and `requirements.txt`.

`install.sh` owns the application runtime: requirement installation, dependency consistency, and Faster-Whisper runtime validation.

This split makes failures easier to isolate and allows the Python foundation to be prepared or rebuilt independently from application dependencies.

## 4. Why a project-local virtual environment

A project-local `./.venv/` provides dependency isolation, reproducibility, clean removal/rebuild, no system Python pollution, explicit interpreter selection, and easier debugging.

## 5. Why disk space is checked before installation

Python wheels, CTranslate2, PyAV, ONNX Runtime, NumPy and future Whisper models can consume meaningful disk space.

The installers therefore check space before installation instead of discovering the problem halfway through package deployment.

The primary check is the filesystem backing `.`. The project filesystem is checked separately when required. This avoids the incorrect assumption that the repository partition is the system `/` filesystem.

## 6. Why pip cache is disabled during installation

Both stages use `--no-cache-dir` to avoid duplicating package payloads in a persistent pip cache when the installed wheels already exist inside the project environment.

## 7. Why models are not installed yet

Model management is deliberately outside the bootstrap/install layer.

A Whisper model can be substantially larger than the Python code and has different lifecycle requirements. Model selection and model-cache placement should be decided together with the transcription runtime, not hidden inside a generic package installer.

## 8. Why media and transcripts are outside the repository

The repository is for reusable scripts and documentation. Private source videos and generated transcription material have a separate lifecycle.

Keeping them outside the public repository prevents accidental publication, repository bloat, mixing source code with evidence/media, unnecessary Git history growth, and coupling the script location to a specific media directory.

## 9. Why current-directory defaults matter

The scripts will be used from different working directories containing different media sets. The project should not require copying private videos into the repository.

For future transcription, the default runtime context is therefore the current working directory (`.`), with outputs following that working context unless the user explicitly selects another destination.

## 10. Why installation and transcription remain separate

Installation changes the local Python runtime. Transcription consumes user media and produces user data.

Keeping these concerns separate makes the project safer, easier to reason about, and easier to maintain.

## 11. Current limit

Version v1.0.0 establishes only the installation/runtime foundation.

The actual transcription CLI, model policy, output formats, timestamp behavior, audio preprocessing, and model-cache strategy will be implemented and validated in a later project phase.
