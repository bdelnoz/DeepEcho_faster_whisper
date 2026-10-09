<!--
DOCUMENT INFORMATION
Document Name: CHANGELOG.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.0.0
Date / Time: 2026-10-09 12:56 CEST
Project: DeepEcho_faster_whisper
Short description: Append-only project changelog.
-->

# DeepEcho_faster_whisper — Changelog

## v1.0.0 — 2026-10-09 12:56 CEST — Bruno DELNOZ

### ADDED

- Initial `install_pip.sh` v1.0.0.
- Initial `install.sh` v1.0.0.
- Two-stage installation workflow.
- Project-local `.venv`.
- `requirements.txt` management.
- Faster-Whisper `1.2.1` runtime requirement.
- Current-directory (`.`) filesystem free-space verification.
- Additional project-filesystem verification when it differs from the execution filesystem.
- `--no-cache-dir` pip behavior.
- CLI controls: `--help/-h`, `--exec/-exe`, `--simulate/-s`, `--prerequis/-pr`, `--install/-i`, `--changelog/-ch`, `--purge/-pu`.
- No-argument help behavior.
- Runtime import validation for Faster-Whisper, CTranslate2 and PyAV.
- `pip check` validation.
- Repository documentation baseline: `SPECIFICATIONS.md`, `README.md`, `CHANGELOG.md`, `INSTALL.md`, `WHY.md`, `EXAMPLES.md`.

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

### NOTES

- Source videos and generated transcription artefacts are intentionally outside the repository.
- The transcription implementation is not part of v1.0.0.
- During the validated bootstrap run, `.gitignore` did not yet exclude `.venv/`; this is a repository-maintenance item and was not modified by the installer scripts.
