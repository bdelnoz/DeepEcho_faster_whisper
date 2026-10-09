#!/usr/bin/env bash
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : transcribe.sh
# Full Path       : ./transcribe.sh
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V1.0.0
# Date / Time     : 2026-10-09 16:45
# Target usage    : User-facing Faster-Whisper transcription interface
#
# CHANGELOG
# V1.0.0 - 2026-10-09 16:45 - Bruno DELNOZ
#   - Initial user-facing Faster-Whisper transcription shell.
#   - Shell is the canonical interface; transcribe.py is the backend.
#   - Same business arguments are accepted by SH and PY.
#   - French transcription language by default.
#   - CPU device and int8 compute type by default.
#   - Explicit local model selection; no hidden model download.
#   - --source supports one file, repeated files and glob patterns.
#   - --source-dir and --dest-dir.
#   - Default *.mp4 source pattern when --source is omitted.
#   - --timestamp default and --no-timestamp override.
#   - --vad opt-in, disabled by default.
#   - --normalize, --amplify and --amplify-db.
#   - --exec, --simulate, --prerequis, --help and --changelog.
#   - --force explicit overwrite.
#   - No-argument help behavior.
#   - Repository-local .venv/backend discovery.
################################################################################

set -uo pipefail

VERSION="V1.0.0"
DATE_TIME="2026-10-09 16:45"
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
PY_SCRIPT="${SCRIPT_DIR}/transcribe.py"
DEFAULT_MODELS_DIR="${SCRIPT_DIR}/models"

show_help() {
    cat <<EOF
transcribe.sh ${VERSION}

User-facing DeepEcho Faster-Whisper transcription interface.
Use this shell script. It validates the request and forwards the same
business arguments to transcribe.py through the repository-local .venv.

USAGE
  ./transcribe.sh --help
  ./transcribe.sh --prerequis
  ./transcribe.sh --simulate --model <NAME> [OPTIONS]
  ./transcribe.sh --exec --model <NAME> [OPTIONS]

SOLO CONTROL OPTIONS
  --help, -h
      Display help and perform no action.

  --exec, -exe
      Execute transcription.

  --simulate, -s
      Resolve and validate sources/model/outputs without transcribing.

  --prerequis, -pr
      Check prerequisites only.

  --changelog, -ch
      Display the complete script changelog.

SOURCE / DESTINATION
  --source <FILE_OR_GLOB>
      Source file or glob pattern. Repeatable.
      Examples:
        --source video.mp4
        --source '*.mp4'
        --source 'Toto*.mp4'
        --source first.mp4 --source second.mp4

      If omitted during --exec/--simulate, the default pattern is:
        *.mp4

  --source-dir <PATH>
      Base directory for relative source files/patterns.
      Default: .

  --dest-dir <PATH>
      Destination directory for transcript files.
      Default: source file directory.
      In the normal current-directory workflow this is therefore ".".

MODEL / RUNTIME
  --model <NAME>
      Required for --exec/--simulate.
      Model must already exist under:
        ${DEFAULT_MODELS_DIR}/<NAME>/

      No model is downloaded automatically.
      Use getModels.sh to list/download models.

  --models-dir <PATH>
      Override local model storage.
      Default: ${DEFAULT_MODELS_DIR}

  --language <LANG>
      Transcription language.
      Default: fr
      Use: auto
      to request automatic language detection.

  --device <DEVICE>
      CTranslate2 device.
      Default: cpu

  --compute-type <TYPE>
      CTranslate2 compute type.
      Default: int8

AUDIO PROCESSING
  --vad
      Enable Silero VAD.
      Default: OFF.

  --no-vad
      Explicitly disable VAD.

  --normalize
      Normalize a temporary audio copy before transcription.
      Default: OFF.

  --amplify <FACTOR>
      Multiply audio volume on a temporary copy.
      Example: --amplify 2

  --amplify-db <DB>
      Amplify a temporary audio copy in decibels.
      Example: --amplify-db 6

  --amplify and --amplify-db are mutually exclusive.
  Original source media is never modified.

OUTPUT
  --timestamp
      Generate timestamped Markdown.
      Default: ON.

  --no-timestamp
      Disable timestamped Markdown.

  --force
      Explicitly allow replacement of existing transcript files.

DEFAULT OUTPUTS FOR Toto.mp4
  Toto.mp4.transcription_timestamps.md
  Toto.mp4.transcription.md
  Toto.mp4.transcript.txt

EXAMPLES
  ./transcribe.sh --prerequis

  ./transcribe.sh --simulate --model tiny --source video.mp4

  ./transcribe.sh --exec --model tiny --source video.mp4

  ./transcribe.sh --exec --model tiny --source '*.mp4'

  ./transcribe.sh --exec --model tiny --source 'Toto*.mp4'

  ./transcribe.sh --exec --model tiny --source-dir /media/videos

  ./transcribe.sh --exec --model tiny --source video.mp4 --dest-dir /media/results

  ./transcribe.sh --exec --model tiny --source video.mp4 --amplify 2

  ./transcribe.sh --exec --model tiny --source video.mp4 --amplify-db 6

  ./transcribe.sh --exec --model tiny --source video.mp4 --normalize

  ./transcribe.sh --exec --model tiny --source video.mp4 --vad

IMPORTANT
  - French is already the default language; you do not need --language fr.
  - VAD, normalization and amplification are never enabled silently.
  - Transcription is raw model output: no editorial rewriting or censorship.
  - Videos are never copied into the repository.
  - Transcripts are written beside their source by default or to --dest-dir.
  - Runtime logs are written to the directory from which you invoke this script.
  - Speaker diarization is NOT implemented in V1.0.0. No fake speaker labels.
  - SRT, WebVTT and JSON outputs are not generated in this version.
EOF
}

show_changelog() {
    cat <<'EOF'
transcribe.sh CHANGELOG

V1.0.0 - 2026-10-09 16:45 - Bruno DELNOZ
  ADDED:
  - Initial user-facing Faster-Whisper shell interface.
  - Shell as canonical user entry point.
  - Same business arguments forwarded to transcribe.py.
  - French default language.
  - CPU/int8 defaults.
  - Explicit local model selection.
  - --source, --source-dir, --dest-dir.
  - Repeated sources and glob patterns.
  - Default *.mp4 source pattern when --source is omitted.
  - --timestamp / --no-timestamp.
  - --vad / --no-vad.
  - --normalize.
  - --amplify / --amplify-db.
  - --device / --compute-type.
  - --models-dir.
  - --force.
  - --exec / --simulate / --prerequis / --help / --changelog.
  - No-argument help behavior.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

check_shell_prerequisites() {
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
        if "$PYTHON" -c 'import faster_whisper' >/dev/null 2>&1; then
            echo "PRESENT : faster-whisper       : import OK"
        else
            echo "MISSING : faster-whisper       : run ./install.sh --install"
            rc=2
        fi

        if "$PYTHON" -c 'import ctranslate2' >/dev/null 2>&1; then
            echo "PRESENT : ctranslate2          : import OK"
        else
            echo "MISSING : ctranslate2          : run ./install.sh --install"
            rc=2
        fi

        if "$PYTHON" -c 'import av' >/dev/null 2>&1; then
            echo "PRESENT : PyAV                 : import OK"
        else
            echo "MISSING : PyAV                 : run ./install.sh --install"
            rc=2
        fi
    fi

    if command -v ffmpeg >/dev/null 2>&1; then
        echo "PRESENT : ffmpeg               : $(command -v ffmpeg)"
    else
        echo "OPTIONAL: ffmpeg               : missing; needed only for normalize/amplify"
    fi

    echo "INFO    : models directory    : ${DEFAULT_MODELS_DIR}"
    echo "------------------------------------------------------------------------"

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

MODEL=""
SOURCE_COUNT=0
SOURCE_DIR="."
DEST_DIR=""
MODELS_DIR="$DEFAULT_MODELS_DIR"
LANGUAGE="fr"
DEVICE="cpu"
COMPUTE_TYPE="int8"
VAD_MODE=""
NORMALIZE=0
AMPLIFY=""
AMPLIFY_DB=""
TIMESTAMP_MODE=""
FORCE=0

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
        --source)
            (( $# >= 2 )) || die "--source requires FILE_OR_GLOB."
            SOURCE_COUNT=$((SOURCE_COUNT + 1))
            shift 2
            ;;
        --source-dir)
            (( $# >= 2 )) || die "--source-dir requires PATH."
            SOURCE_DIR="$2"
            shift 2
            ;;
        --dest-dir)
            (( $# >= 2 )) || die "--dest-dir requires PATH."
            DEST_DIR="$2"
            shift 2
            ;;
        --model)
            (( $# >= 2 )) || die "--model requires NAME."
            MODEL="$2"
            shift 2
            ;;
        --models-dir)
            (( $# >= 2 )) || die "--models-dir requires PATH."
            MODELS_DIR="$2"
            shift 2
            ;;
        --language)
            (( $# >= 2 )) || die "--language requires LANG."
            LANGUAGE="$2"
            shift 2
            ;;
        --device)
            (( $# >= 2 )) || die "--device requires DEVICE."
            DEVICE="$2"
            shift 2
            ;;
        --compute-type)
            (( $# >= 2 )) || die "--compute-type requires TYPE."
            COMPUTE_TYPE="$2"
            shift 2
            ;;
        --vad)
            [[ -z "$VAD_MODE" ]] || die "Use only one of --vad or --no-vad."
            VAD_MODE="on"
            shift
            ;;
        --no-vad)
            [[ -z "$VAD_MODE" ]] || die "Use only one of --vad or --no-vad."
            VAD_MODE="off"
            shift
            ;;
        --normalize)
            NORMALIZE=1
            shift
            ;;
        --amplify)
            (( $# >= 2 )) || die "--amplify requires FACTOR."
            [[ -z "$AMPLIFY_DB" ]] || die "--amplify and --amplify-db are mutually exclusive."
            AMPLIFY="$2"
            shift 2
            ;;
        --amplify-db)
            (( $# >= 2 )) || die "--amplify-db requires DB."
            [[ -z "$AMPLIFY" ]] || die "--amplify and --amplify-db are mutually exclusive."
            AMPLIFY_DB="$2"
            shift 2
            ;;
        --timestamp)
            [[ -z "$TIMESTAMP_MODE" ]] || die "Use only one of --timestamp or --no-timestamp."
            TIMESTAMP_MODE="on"
            shift
            ;;
        --no-timestamp)
            [[ -z "$TIMESTAMP_MODE" ]] || die "Use only one of --timestamp or --no-timestamp."
            TIMESTAMP_MODE="off"
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

if (( HELP_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 && PREREQUIS_MODE == 0 && CHANGELOG_MODE == 0 )) \
        || die "--help must be used alone."
    show_help
    exit 0
fi

if (( CHANGELOG_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 && PREREQUIS_MODE == 0 )) \
        || die "--changelog must be used alone."
    show_changelog
    exit 0
fi

if (( PREREQUIS_MODE == 1 )); then
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 )) \
        || die "--prerequis must be used alone."
    check_shell_prerequisites
    exit $?
fi

(( EXEC_MODE + SIMULATE_MODE == 1 )) \
    || die "Use exactly one execution gate: --exec or --simulate."

[[ -n "$MODEL" ]] \
    || die "--exec/--simulate requires --model <NAME>."

[[ -x "$PYTHON" ]] \
    || die "Missing ${PYTHON}. Run ./install_pip.sh --install first."

[[ -f "$PY_SCRIPT" ]] \
    || die "Missing ${PY_SCRIPT}."

"$PYTHON" -c 'import faster_whisper, ctranslate2, av' >/dev/null 2>&1 \
    || die "Faster-Whisper runtime is incomplete. Run ./install.sh --install."

exec "$PYTHON" "$PY_SCRIPT" "${ORIGINAL_ARGS[@]}"
