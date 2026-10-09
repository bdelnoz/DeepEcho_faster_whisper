#!/usr/bin/env bash
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : getModels.sh
# Full Path       : ./getModels.sh
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V1.0.1
# Date / Time     : 2026-10-09 15:41
# Target usage    : User-facing Faster-Whisper model manager
#
# CHANGELOG
# V1.0.1 - 2026-10-09 15:41 - Bruno DELNOZ
#   - Renamed the delivered interface to getModels.sh / getModels.py.
#   - Keeps the SH as the user-facing interface and forwards the same business
#     arguments to the Python backend.
#   - Supports --exec --list.
#   - Supports --exec --download --model <NAME>.
#   - Supports --simulate, --prerequis, --changelog and --models-dir.
#   - Uses the repository-local .venv.
#   - Stores models by default below <repo>/models/<model-name>/.
#   - No argument displays help and performs no action.
################################################################################

set -uo pipefail

VERSION="V1.0.1"
DATE_TIME="2026-10-09 15:41"
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
  ./getModels.sh --simulate --download --model <NAME>
  ./getModels.sh --exec --download --model <NAME>
  ./getModels.sh --exec --download --model <NAME> --models-dir <PATH>

SOLO CONTROL OPTIONS
  --help, -h
      Display this help and perform no action.

  --exec, -exe
      Execute the selected business action.

  --simulate, -s
      Validate and display the selected action without downloading anything.

  --prerequis, -pr
      Check the local Python runtime and Faster-Whisper prerequisites.

  --changelog, -ch
      Display the complete script changelog.

MODEL ACTIONS
  --list
      List every named model exposed by the installed Faster-Whisper package.

  --download
      Download one model. Requires --model <NAME>.

MODEL OPTIONS
  --model <NAME>
      Model name returned by --exec --list.

  --models-dir <PATH>
      Override model storage.
      Default: ${DEFAULT_MODELS_DIR}

EXAMPLES
  ./getModels.sh --prerequis
  ./getModels.sh --exec --list
  ./getModels.sh --simulate --download --model tiny
  ./getModels.sh --exec --download --model tiny
  ./getModels.sh --exec --download --model medium
  ./getModels.sh --exec --download --model large-v3

DEFAULT STORAGE
  tiny      -> ${DEFAULT_MODELS_DIR}/tiny/
  medium    -> ${DEFAULT_MODELS_DIR}/medium/
  large-v3  -> ${DEFAULT_MODELS_DIR}/large-v3/

NOTES
  - Models contain several CTranslate2 files, so each model has its own folder.
  - The script does not start a transcription.
  - The default models/ directory may be replaced by a symbolic link.
EOF
}

show_changelog() {
    cat <<'EOF'
getModels.sh CHANGELOG

V1.0.1 - 2026-10-09 15:41 - Bruno DELNOZ
  ADDED/CHANGED:
  - Final camel-case file name: getModels.sh.
  - Shell remains the user-facing interface.
  - Same business arguments are forwarded to getModels.py.
  - --exec --list.
  - --exec --download --model <NAME>.
  - --simulate.
  - --prerequis.
  - --changelog.
  - --models-dir.
  - Repository-local .venv discovery.
  - Repository-local models/ default.
  - No-argument help behavior.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

shell_prerequisites() {
    local rc=0

    echo "PREREQUISITES"
    echo "------------------------------------------------------------"

    if [[ -x "$PYTHON" ]]; then
        echo "PRESENT : .venv Python       : $("$PYTHON" --version 2>&1)"
    else
        echo "MISSING : .venv Python       : ${PYTHON}"
        rc=2
    fi

    if [[ -f "$PY_SCRIPT" ]]; then
        echo "PRESENT : Python backend     : ${PY_SCRIPT}"
    else
        echo "MISSING : Python backend     : ${PY_SCRIPT}"
        rc=2
    fi

    if [[ -x "$PYTHON" ]]; then
        if "$PYTHON" -c 'import faster_whisper' >/dev/null 2>&1; then
            echo "PRESENT : faster-whisper     : import OK"
        else
            echo "MISSING : faster-whisper     : run ./install.sh --install"
            rc=2
        fi

        if "$PYTHON" -c 'import huggingface_hub' >/dev/null 2>&1; then
            echo "PRESENT : huggingface-hub    : import OK"
        else
            echo "MISSING : huggingface-hub    : required by faster-whisper"
            rc=2
        fi
    fi

    echo "INFO    : default models dir : ${DEFAULT_MODELS_DIR}"
    echo "------------------------------------------------------------"

    if (( rc != 0 )); then
        echo "RESULT  : ERROR"
        return "$rc"
    fi

    "$PYTHON" "$PY_SCRIPT" --prerequis
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
MODEL=""
MODELS_DIR=""

while (( $# > 0 )); do
    case "$1" in
        --help|-h)
            HELP_MODE=1
            shift
            ;;
        --exec|-exe)
            EXEC_MODE=1
            shift
            ;;
        --simulate|-s)
            SIMULATE_MODE=1
            shift
            ;;
        --prerequis|-pr)
            PREREQUIS_MODE=1
            shift
            ;;
        --changelog|-ch)
            CHANGELOG_MODE=1
            shift
            ;;
        --list)
            ACTION_LIST=1
            shift
            ;;
        --download)
            ACTION_DOWNLOAD=1
            shift
            ;;
        --model)
            (( $# >= 2 )) || die "--model requires a value."
            MODEL="$2"
            shift 2
            ;;
        --models-dir)
            (( $# >= 2 )) || die "--models-dir requires a path."
            MODELS_DIR="$2"
            shift 2
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

if (( HELP_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 && PREREQUIS_MODE == 0 && CHANGELOG_MODE == 0 && ACTION_LIST == 0 && ACTION_DOWNLOAD == 0 )) \
        || die "--help must be used alone."
    show_help
    exit 0
fi

if (( CHANGELOG_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 && PREREQUIS_MODE == 0 && ACTION_LIST == 0 && ACTION_DOWNLOAD == 0 )) \
        || die "--changelog must be used alone."
    show_changelog
    exit 0
fi

if (( PREREQUIS_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 && ACTION_LIST == 0 && ACTION_DOWNLOAD == 0 )) \
        || die "--prerequis must be used alone."
    shell_prerequisites
    exit $?
fi

(( EXEC_MODE + SIMULATE_MODE == 1 )) \
    || die "Use exactly one execution gate: --exec or --simulate."

(( ACTION_LIST + ACTION_DOWNLOAD == 1 )) \
    || die "Use exactly one model action: --list or --download."

if (( ACTION_DOWNLOAD == 1 )); then
    [[ -n "$MODEL" ]] || die "--download requires --model <NAME>."
else
    [[ -z "$MODEL" ]] || die "--model is only valid with --download."
fi

[[ -x "$PYTHON" ]] \
    || die "Missing ${PYTHON}. Run ./install_pip.sh --install first."

[[ -f "$PY_SCRIPT" ]] \
    || die "Missing ${PY_SCRIPT}."

"$PYTHON" -c 'import faster_whisper' >/dev/null 2>&1 \
    || die "faster-whisper is not installed in .venv. Run ./install.sh --install."

exec "$PYTHON" "$PY_SCRIPT" "${ORIGINAL_ARGS[@]}"
