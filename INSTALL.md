<!--
DOCUMENT INFORMATION
Document Name: INSTALL.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.0.0
Date / Time: 2026-10-09 12:56 CEST
Project: DeepEcho_faster_whisper
Short description: Installation and validation procedure for the two-stage Faster-Whisper runtime.
-->

# DeepEcho_faster_whisper — Installation

## 1. Installation design

Installation is split into two scripts and must be performed in this order:

```text
1. install_pip.sh
2. install.sh
```

`install_pip.sh` creates the isolated Python foundation. `install.sh` installs and validates Faster-Whisper inside that isolated environment.

## 2. Runtime location

The Python virtual environment is project-local: `./.venv/`.

The installer never uses system-wide pip installation. The dependency declaration is `./requirements.txt`.

## 3. Disk-space prerequisite

Both installer stages check free space on the filesystem backing the current directory (`.`). The project filesystem is also checked when it differs from the current execution directory/filesystem.

Required minimum: `4096 MiB free`.

This is intentional: the project may live on a dedicated partition and the scripts must not assume that the target filesystem is `/`.

## 4. First-stage prerequisite check

```bash
./install_pip.sh --prerequis
```

This action is read-only.

## 5. First-stage simulation

```bash
./install_pip.sh --simulate
```

Simulation describes the bootstrap operations without changing files.

## 6. Bootstrap the Python environment

```bash
./install_pip.sh --install
```

Equivalent real-action form:

```bash
./install_pip.sh --exec
```

This stage validates target paths, creates or preserves `.venv`, upgrades `pip`, `setuptools`, and `wheel` inside `.venv`, uses `--no-cache-dir`, creates or preserves `requirements.txt`, ensures `faster-whisper==1.2.1` is declared, and validates `.venv` Python and pip.

It does not install Faster-Whisper itself.

## 7. Second-stage prerequisite check

```bash
./install.sh --prerequis
```

This verifies `.venv`, Python, pip, `requirements.txt`, the Faster-Whisper declaration, and free space.

## 8. Second-stage simulation

```bash
./install.sh --simulate
```

This action performs no package installation.

## 9. Install Faster-Whisper

```bash
./install.sh --install
```

Equivalent real-action form:

```bash
./install.sh --exec
```

The installation uses `.venv/bin/python -m pip install --no-cache-dir -r requirements.txt`, then runs `pip check` and validates Faster-Whisper, CTranslate2, PyAV, and `WhisperModel`.

No Whisper model is downloaded by this installer.

## 10. Complete normal sequence

```bash
./install_pip.sh --prerequis
./install_pip.sh --install

./install.sh --prerequis
./install.sh --install
```

## 11. Help

```bash
./install_pip.sh --help
./install.sh --help
```

Launching either script without arguments also displays its complete help.

## 12. Changelogs

```bash
./install_pip.sh --changelog
./install.sh --changelog
```

## 13. Purge

Both scripts expose `--purge/-pu`. Current purge scope is intentionally restricted to `./.venv/`; `requirements.txt` is preserved.

```bash
./install_pip.sh --purge
./install.sh --purge
```

After purging, rebuild in the original order.

## 14. Validated installation result

The user execution on 2026-10-09 completed successfully with Python `3.14.7`, pip `26.2.1`, Faster-Whisper `1.2.1`, CTranslate2 `4.8.2`, and PyAV `19.0.1`.

Dependency consistency and runtime imports passed.

## 15. Repository hygiene

`.venv/` is runtime data and must remain local.

During the validated 2026-10-09 run, the installer reported that `.venv/` was not yet excluded by the repository `.gitignore`.

The installer only reports that state; it does not rewrite `.gitignore`.

## 16. Model installation

The current installation scripts do not download a Whisper model.

Model choice, model-cache location, model download behavior, and transcription runtime behavior belong to the later transcription implementation.
