#!/usr/bin/env bash
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : getModels.sh
# Full Path       : ./getModels.sh
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V2.0.0
# Date / Time     : 2026-10-10 04:20 CEST
# Target usage    : User-facing Faster-Whisper model manager
#
# CHANGELOG
# V2.0.0 - 2026-10-10 04:20 CEST - Bruno DELNOZ
#   - MAJOR RELEASE: version metadata synchronized at V2.0.0.
#   - Preserved V1.1.4-dev behavior; no new runtime features.
# V1.1.1-dev - 2026-10-09 21:05 CEST - Bruno DELNOZ
#   - Added --size list modifier.
#   - --exec --list --size displays live remote Faster-Whisper download sizes.
#   - Size lookup remains read-only and downloads no model payload.
#   - Backend also reports local on-disk size for comparison/diagnosis.
#   - Preserved all V1.1.0-dev model-management behavior.
# V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
#   - Validation candidate; not a release tag.
#   - Added full 19-model reference immediately before EXAMPLES in help.
#   - Added multi-model --model parsing for downloads.
#   - Added --force explicit redownload/replace behavior.
#   - Preserved --exec --list live registry/status behavior.
# V1.0.1 - 2026-10-09 15:41 - Bruno DELNOZ
#   - Initial user-facing model-management wrapper.
################################################################################

set -uo pipefail

VERSION="V2.0.0"
DATE_TIME="2026-10-09 21:05 CEST"
AUTHOR="Bruno DELNOZ"
EMAIL="bruno.delnoz@protonmail.com"

resolve_script_path() {
    local src="${BASH_SOURCE[0]}"
    if command -v readlink >/dev/null 2>&1; then
        readlink -f -- "$src" 2>/dev/null && return 0
    fi
    printf '%s/%s\n' "$(cd -- "$(dirname -- "$src")" && pwd -P)" "$(basename -- "$src")"
}

SCRIPT_PATH="$(resolve_script_path)"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd -P)"
PYTHON="${SCRIPT_DIR}/.venv/bin/python"
PY_SCRIPT="${SCRIPT_DIR}/getModels.py"
DEFAULT_MODELS_DIR="${SCRIPT_DIR}/models"

show_help() {
    cat <<EOF
getModels.sh ${VERSION}

User-facing Faster-Whisper model manager.

USAGE
  ./getModels.sh --help
  ./getModels.sh --prerequis
  ./getModels.sh --exec --list
  ./getModels.sh --exec --list --size
  ./getModels.sh --simulate --download --model <NAME> [NAME ...]
  ./getModels.sh --exec --download --model <NAME> [NAME ...]

SOLO CONTROL OPTIONS
  --help, -h
      Display help and perform no action.

  --exec, -exe
      Execute the selected model action.

  --simulate, -s
      Resolve/validate the selected action without downloading or deleting.

  --prerequis, -pr
      Check model-management prerequisites only.

  --changelog, -ch
      Display the complete script changelog.

MODEL ACTIONS
  --list
      List every model exposed by the installed Faster-Whisper runtime.
      Status is shown as INSTALLED, INCOMPLETE or not installed.

  --download
      Download one or more requested models.

MODEL OPTIONS
  --model <NAME> [NAME ...]
      One or more model names.
      Example: --model base small medium

  --models-dir <PATH>
      Override model storage.
      Default: ${DEFAULT_MODELS_DIR}

  --force
      Valid only with --download.
      Remove and redownload every requested local model, even when already
      complete. Use this to replace a suspected corrupt local model.

  --size
      Valid only with --list.
      Query live Hugging Face metadata and display the expected Faster-Whisper
      download size for every model. No model payload is downloaded.

DEFAULT STORAGE
  ${DEFAULT_MODELS_DIR}/<model-name>/

AVAILABLE MODEL NAMES (REFERENCE)
   1. tiny.en
   2. tiny
   3. base.en
   4. base
   5. small.en
   6. small
   7. medium.en
   8. medium
   9. large-v1
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

EXAMPLES
  ./getModels.sh --prerequis
  ./getModels.sh --exec --list
  ./getModels.sh --exec --list --size
  ./getModels.sh --simulate --download --model tiny
  ./getModels.sh --exec --download --model tiny
  ./getModels.sh --exec --download --model base small medium
  ./getModels.sh --simulate --download --model base small medium --force
  ./getModels.sh --exec --download --model base small medium --force
  ./getModels.sh --exec --download --model large-v3 --models-dir /data/models

NOTES
  - --list --size requires network access to Hugging Face metadata.
  - Existing complete models are skipped unless --force is used.
  - An incomplete local model is not silently trusted; use --force to replace it.
  - Invalid model names are reported; valid requested models are still processed.
  - Models contain several CTranslate2 files, so each model has its own directory.
EOF
}

show_changelog() {
    cat <<'EOF'
getModels.sh CHANGELOG

V2.0.0 - 2026-10-10 04:20 CEST - Bruno DELNOZ
  - MAJOR RELEASE: synchronized script version, unchanged model-management behavior.

V1.1.1-dev - 2026-10-09 21:05 CEST - Bruno DELNOZ
  ADDED/CHANGED:
  - --size list modifier.
  - --exec --list --size forwards live remote-size lookup to getModels.py.
  - Read-only size lookup; no model payload download.

V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
  ADDED/CHANGED:
  - Validation candidate; not a release tag.
  - Complete 19-model reference immediately before EXAMPLES in help.
  - Multiple model names accepted after --model.
  - --force for explicit model replacement/redownload.
  - Preserved live --exec --list status reporting.

V1.0.1 - 2026-10-09 15:41 - Bruno DELNOZ
  ADDED/CHANGED:
  - User-facing shell model manager.
  - --exec --list and --exec --download --model <NAME>.
  - --simulate, --prerequis, --changelog and --models-dir.
  - Repository-local .venv and models/ defaults.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

shell_prerequisites() {
    local rc=0
    echo "PREREQUISITES"
    echo "------------------------------------------------------------------------"
    if [[ -x "$PYTHON" ]]; then
        echo "PRESENT : .venv Python         : $("$PYTHON" --version 2>&1)"
    else
        echo "MISSING : .venv Python         : ${PYTHON}"
        rc=2
    fi
    if [[ -f "$PY_SCRIPT" ]]; then
        echo "PRESENT : Python backend       : ${PY_SCRIPT}"
    else
        echo "MISSING : Python backend       : ${PY_SCRIPT}"
        rc=2
    fi
    if [[ -x "$PYTHON" ]]; then
        "$PYTHON" -c 'import faster_whisper' >/dev/null 2>&1 \
            && echo "PRESENT : faster-whisper       : import OK" \
            || { echo "MISSING : faster-whisper       : run ./install.sh --install"; rc=2; }
        "$PYTHON" -c 'import huggingface_hub' >/dev/null 2>&1 \
            && echo "PRESENT : huggingface-hub      : import OK" \
            || { echo "MISSING : huggingface-hub      : required by faster-whisper"; rc=2; }
    fi
    echo "INFO    : default models dir   : ${DEFAULT_MODELS_DIR}"
    echo "------------------------------------------------------------------------"
    (( rc == 0 )) || { echo "RESULT  : ERROR"; return "$rc"; }
    "$PYTHON" "$PY_SCRIPT" --prerequis
}

is_known_option() {
    case "$1" in
        --help|-h|--exec|-exe|--simulate|-s|--prerequis|-pr|--changelog|-ch|\
        --list|--download|--model|--models-dir|--force|--size)
            return 0 ;;
        *) return 1 ;;
    esac
}

if (( $# == 0 )); then
    show_help
    exit 0
fi

ORIGINAL_ARGS=("$@")
EXEC_MODE=0
SIMULATE_MODE=0
PREREQUIS_MODE=0
HELP_MODE=0
CHANGELOG_MODE=0
ACTION_LIST=0
ACTION_DOWNLOAD=0
FORCE=0
SIZE=0
MODEL_COUNT=0
MODELS_DIR=""

while (( $# > 0 )); do
    case "$1" in
        --help|-h) HELP_MODE=1; shift ;;
        --exec|-exe) EXEC_MODE=1; shift ;;
        --simulate|-s) SIMULATE_MODE=1; shift ;;
        --prerequis|-pr) PREREQUIS_MODE=1; shift ;;
        --changelog|-ch) CHANGELOG_MODE=1; shift ;;
        --list) ACTION_LIST=1; shift ;;
        --download) ACTION_DOWNLOAD=1; shift ;;
        --force) FORCE=1; shift ;;
        --size) SIZE=1; shift ;;
        --models-dir)
            (( $# >= 2 )) || die "--models-dir requires PATH."
            MODELS_DIR="$2"
            shift 2
            ;;
        --model)
            shift
            (( $# >= 1 )) || die "--model requires at least one NAME."
            VALUES=0
            while (( $# > 0 )); do
                if is_known_option "$1"; then
                    break
                fi
                MODEL_COUNT=$((MODEL_COUNT + 1))
                VALUES=$((VALUES + 1))
                shift
            done
            (( VALUES > 0 )) || die "--model requires at least one NAME."
            ;;
        *) die "Unknown argument: $1" ;;
    esac
done

if (( HELP_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 && PREREQUIS_MODE == 0 && CHANGELOG_MODE == 0 && ACTION_LIST == 0 && ACTION_DOWNLOAD == 0 && FORCE == 0 && SIZE == 0 && MODEL_COUNT == 0 )) \
        || die "--help must be used alone."
    show_help
    exit 0
fi

if (( CHANGELOG_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 && PREREQUIS_MODE == 0 && ACTION_LIST == 0 && ACTION_DOWNLOAD == 0 && FORCE == 0 && SIZE == 0 && MODEL_COUNT == 0 )) \
        || die "--changelog must be used alone."
    show_changelog
    exit 0
fi

if (( PREREQUIS_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 && ACTION_LIST == 0 && ACTION_DOWNLOAD == 0 && FORCE == 0 && SIZE == 0 && MODEL_COUNT == 0 )) \
        || die "--prerequis must be used alone."
    shell_prerequisites
    exit $?
fi

(( EXEC_MODE + SIMULATE_MODE == 1 )) || die "Use exactly one execution gate: --exec or --simulate."
(( ACTION_LIST + ACTION_DOWNLOAD == 1 )) || die "Use exactly one model action: --list or --download."

if (( ACTION_DOWNLOAD == 1 )); then
    (( MODEL_COUNT > 0 )) || die "--download requires --model NAME [NAME ...]."
else
    (( MODEL_COUNT == 0 )) || die "--model is only valid with --download."
    (( FORCE == 0 )) || die "--force is only valid with --download."
fi

if (( ACTION_DOWNLOAD == 1 && SIZE == 1 )); then
    die "--size is a list modifier. Use --exec --list --size."
fi

[[ -x "$PYTHON" ]] || die "Missing ${PYTHON}. Run ./install_pip.sh --install first."
[[ -f "$PY_SCRIPT" ]] || die "Missing ${PY_SCRIPT}."
"$PYTHON" -c 'import faster_whisper' >/dev/null 2>&1 \
    || die "faster-whisper is not installed in .venv. Run ./install.sh --install."

exec "$PYTHON" "$PY_SCRIPT" "${ORIGINAL_ARGS[@]}"
