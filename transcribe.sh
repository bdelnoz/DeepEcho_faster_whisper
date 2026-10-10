#!/usr/bin/env bash
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : transcribe.sh
# Full Path       : ./transcribe.sh
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V2.0.0
# Date / Time     : 2026-10-10 04:20 CEST
# Target usage    : User-facing Faster-Whisper transcription interface
#
# CHANGELOG
# V2.0.0 - 2026-10-10 04:20 CEST - Bruno DELNOZ
#   - MAJOR RELEASE: version metadata synchronized at V2.0.0.
#   - Preserved V1.1.4-dev behavior; no new runtime features.
# V1.1.4-dev - 2026-10-10 04:00 CEST - Bruno DELNOZ
#   - Added --recursive/--recursif MP4 scan under current/--source-dir.
#   - Preserved original glob and filenames-with-spaces handling without --recursive.
# V1.1.2-dev - 2026-10-09 22:08 CEST - Bruno DELNOZ
#   - Model is shown last in help/examples for fast model swapping.
#   - Forwards the exact shell argv command to the Python runtime log.
#   - Documents model-aware transcript names and Processing-Time report.
# V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
#   - Validation candidate; not a release tag.
#   - New timestamped output layout using YYYYMMDD-HHMM-SS.
#   - Timestamped Markdown remains beside source media.
#   - Plain Markdown/TXT default to source-local .transcription/.
#   - Runtime logs default to source-local .logs/.
#   - Preserved multi-source, glob, names-with-spaces and PyAV 19 fixes.
# V1.0.1 - 2026-10-09 17:40 - Bruno DELNOZ
#   - Fixed shell-expanded globs and filenames containing spaces.
#   - Backend added PyAV 19 / Faster-Whisper 1.2.1 compatibility.
# V1.0.0 - 2026-10-09 16:45 - Bruno DELNOZ
#   - Initial user-facing Faster-Whisper transcription shell.
################################################################################

set -uo pipefail

VERSION="V2.0.0"
DATE_TIME="2026-10-10 04:00 CEST"
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
The shell validates the request and forwards the same business arguments to
transcribe.py through the repository-local .venv.

USAGE
  ./transcribe.sh --help
  ./transcribe.sh --prerequis
  ./transcribe.sh --simulate [OPTIONS] --model <NAME>
  ./transcribe.sh --exec [OPTIONS] --model <NAME>

SOLO CONTROL OPTIONS
  --help, -h
      Display help and perform no action.

  --exec, -exe
      Execute transcription.

  --simulate, -s
      Resolve/validate sources, model and output plan without writing files.

  --prerequis, -pr
      Check prerequisites only.

  --changelog, -ch
      Display the complete script changelog.

SOURCE / DESTINATION
  --source <FILE_OR_GLOB> [FILE_OR_GLOB ...]
      One or more source files or glob patterns. Repeatable.
      Quoted globs and shell-expanded unquoted globs are both supported.
      Filenames containing spaces are preserved correctly.
      Examples:
        --source video.mp4
        --source '*.mp4'
        --source *.mp4
        --source 'Toto*.mp4'
        --source first.mp4 'second file.mp4'
        --source first.mp4 --source second.mp4
      Default during --exec/--simulate: *.mp4

  --source-dir <PATH>
      Base directory for relative sources/patterns. Default: .

  --dest-dir <PATH>
      Override the base directory for plain Markdown/TXT output only.
      Those files are placed in <dest-dir>/.transcription/.
      Default: <source-file-directory>/.transcription/.
      Timestamped Markdown and runtime logs always remain source-local.

RUNTIME
  --models-dir <PATH>
      Override local model storage. Default: ${DEFAULT_MODELS_DIR}

  --language <LANG>
      Transcription language. Default: fr
      Use auto for automatic language detection.

  --device <DEVICE>
      CTranslate2 device. Default: cpu

  --compute-type <TYPE>
      CTranslate2 compute type. Default: int8

AUDIO PROCESSING
  --vad
      Enable Silero VAD. Default: OFF.

  --no-vad
      Explicitly disable VAD.

  --normalize
      Normalize a temporary audio copy before transcription. Default: OFF.

  --amplify <FACTOR>
      Multiply volume on a temporary audio copy. Example: --amplify 2

  --amplify-db <DB>
      Change volume on a temporary audio copy in dB. Example: --amplify-db 6

  --amplify and --amplify-db are mutually exclusive.
  Original source media is never modified.

OUTPUT
  --timestamp
      Generate timestamped Markdown. Default: ON.

  --no-timestamp
      Disable timestamped Markdown.

  --force
      Allow replacement only if the exact timestamped target already exists.
      Normal runs avoid overwrites by allocating a unique run timestamp.

RECURSIVE DISCOVERY
  --recursive, --recursif, --récursif, --récursive
      Scan every MP4 in the working directory and all subdirectories.
      With --source-dir, scan that directory instead.
      In recursive mode, --source values do not restrict the MP4 scan.
      Works with unquoted --source *.mp4 expanded by Bash.
      Processes discovered files sequentially, one per run.
      No symbolic-link directories are traversed.
      Default: OFF; without it the normal source selection is unchanged.

MODEL (LAST)
  --model <NAME>
      Required for --exec/--simulate.
      Model must already exist under ${DEFAULT_MODELS_DIR}/<NAME>/.
      Kept last in help/examples so the model can be swapped quickly.

DEFAULT OUTPUT LAYOUT
  source-dir/
  ├── source.mp4
  ├── source.mp4.transcription_timestamps-MODEL-YYYYMMDD-HHMM-SS.md
  ├── .transcription/
  │   ├── source.mp4.transcription-MODEL-YYYYMMDD-HHMM-SS.md
  │   └── source.mp4.transcript-MODEL-YYYYMMDD-HHMM-SS.txt
  └── .logs/
      ├── transcribe-${VERSION}-YYYYMMDD-HHMM-SS.log
      └── source.mp4-Processing-Time-MODEL-YYYYMMDD-HHMM-SS.md

EXAMPLES
  ./transcribe.sh --prerequis
  ./transcribe.sh --simulate --source video.mp4 --model tiny
  ./transcribe.sh --exec --source video.mp4 --model tiny
  ./transcribe.sh --exec --source '*.mp4' --model tiny
  ./transcribe.sh --exec --source *.mp4 --model tiny
  ./transcribe.sh --exec --source 'video with spaces.mp4' --model tiny
  ./transcribe.sh --exec --source first.mp4 'second file.mp4' --model tiny
  ./transcribe.sh --exec --source *.mp4 --recursive --model large-v3
  ./transcribe.sh --simulate --source '*.mp4' --recursive --model tiny
  ./transcribe.sh --exec --source-dir /media/videos --recursive --model medium
  ./transcribe.sh --exec --source-dir /media/videos --model tiny
  ./transcribe.sh --exec --source video.mp4 --dest-dir /media/results --model tiny
  ./transcribe.sh --exec --source video.mp4 --amplify 2 --model tiny
  ./transcribe.sh --exec --source video.mp4 --amplify-db 6 --model tiny
  ./transcribe.sh --exec --source video.mp4 --normalize --model tiny
  ./transcribe.sh --exec --source video.mp4 --vad --model tiny

IMPORTANT
  - French is already the default; --language fr is unnecessary.
  - VAD, normalization and amplification are never enabled silently.
  - Transcription is raw model output: no editorial rewriting or censorship.
  - Videos are never copied into the repository.
  - Every generated transcript/log filename is timestamped to the second.
  - The same run timestamp is shared by all outputs from one invocation.
  - Processing-Time Markdown reports use one invariant template across all models.
  - Speaker diarization is NOT implemented; no fake speaker labels.
  - SRT, WebVTT and JSON are not generated in this validation build.
EOF
}

show_changelog() {
    cat <<'EOF'
transcribe.sh CHANGELOG

V2.0.0 - 2026-10-10 04:20 CEST - Bruno DELNOZ
  - MAJOR RELEASE: synchronized script version, unchanged transcription behavior.

V1.1.4-dev - 2026-10-10 04:00 CEST - Bruno DELNOZ
  ADDED:
  - --recursive/--recursif discovers every nested MP4 under current/--source-dir.
  - Works with unquoted --source *.mp4 expanded by the shell.
  - No change to nonrecursive behavior, output layout or privacy policy.

V1.1.2-dev - 2026-10-09 22:08 CEST - Bruno DELNOZ
  ADDED/CHANGED:
  - Model kept last in help/examples.
  - Exact shell command forwarded to the backend for the first runtime-log record.
  - Model-aware transcript filename convention.
  - Source-local invariant Processing-Time Markdown report.

V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
  ADDED/CHANGED:
  - Validation candidate; not a release tag.
  - Run timestamp format YYYYMMDD-HHMM-SS.
  - Timestamped Markdown beside source media.
  - Plain Markdown/TXT under source-local .transcription/ by default.
  - Runtime logs under source-local .logs/.
  - Same timestamp shared by every generated artefact from one run.
  - Preserved glob expansion, filenames with spaces and multi-source behavior.

V1.0.1 - 2026-10-09 17:40 - Bruno DELNOZ
  FIXED:
  - Unquoted shell-expanded globs after --source.
  - Filenames containing spaces.
  - Compatibility with transcribe.py PyAV 19 workaround.

V1.0.0 - 2026-10-09 16:45 - Bruno DELNOZ
  ADDED:
  - Initial shell interface and complete transcription argument forwarding.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

check_shell_prerequisites() {
    local rc=0
    echo "PREREQUISITES"
    echo "----------------------------------------------------------------------------"
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
        for module in faster_whisper ctranslate2 av; do
            if "$PYTHON" -c "import ${module}" >/dev/null 2>&1; then
                echo "PRESENT : ${module} : import OK"
            else
                echo "MISSING : ${module} : run ./install.sh --install"
                rc=2
            fi
        done
    fi
    if command -v ffmpeg >/dev/null 2>&1; then
        echo "PRESENT : ffmpeg               : $(command -v ffmpeg)"
    else
        echo "OPTIONAL: ffmpeg               : needed only for normalize/amplify"
    fi
    echo "INFO    : models directory     : ${DEFAULT_MODELS_DIR}"
    echo "----------------------------------------------------------------------------"
    (( rc == 0 )) || { echo "RESULT  : ERROR"; return "$rc"; }
    "$PYTHON" "$PY_SCRIPT" --prerequis
}

is_known_option() {
    case "$1" in
        --help|-h|--exec|-exe|--simulate|-s|--prerequis|-pr|--changelog|-ch|\
        --source|--source-dir|--dest-dir|--recursive|--recursif|--récursif|--récursive|--model|--models-dir|--language|\
        --device|--compute-type|--vad|--no-vad|--normalize|--amplify|\
        --amplify-db|--timestamp|--no-timestamp|--force)
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
RECURSIVE=0

while (( $# > 0 )); do
    case "$1" in
        --help|-h) HELP_MODE=1; shift ;;
        --exec|-exe) EXEC_MODE=1; shift ;;
        --simulate|-s) SIMULATE_MODE=1; shift ;;
        --prerequis|-pr) PREREQUIS_MODE=1; shift ;;
        --changelog|-ch) CHANGELOG_MODE=1; shift ;;
        --source)
            shift
            (( $# >= 1 )) || die "--source requires at least one FILE_OR_GLOB."
            SOURCE_VALUES=0
            while (( $# > 0 )); do
                if is_known_option "$1"; then break; fi
                SOURCE_COUNT=$((SOURCE_COUNT + 1))
                SOURCE_VALUES=$((SOURCE_VALUES + 1))
                shift
            done
            (( SOURCE_VALUES > 0 )) || die "--source requires at least one FILE_OR_GLOB."
            ;;
        --source-dir)
            (( $# >= 2 )) || die "--source-dir requires PATH."
            SOURCE_DIR="$2"; shift 2 ;;
        --dest-dir)
            (( $# >= 2 )) || die "--dest-dir requires PATH."
            DEST_DIR="$2"; shift 2 ;;
        --model)
            (( $# >= 2 )) || die "--model requires NAME."
            MODEL="$2"; shift 2 ;;
        --models-dir)
            (( $# >= 2 )) || die "--models-dir requires PATH."
            MODELS_DIR="$2"; shift 2 ;;
        --language)
            (( $# >= 2 )) || die "--language requires LANG."
            LANGUAGE="$2"; shift 2 ;;
        --device)
            (( $# >= 2 )) || die "--device requires DEVICE."
            DEVICE="$2"; shift 2 ;;
        --compute-type)
            (( $# >= 2 )) || die "--compute-type requires TYPE."
            COMPUTE_TYPE="$2"; shift 2 ;;
        --vad)
            [[ -z "$VAD_MODE" ]] || die "Use only one of --vad or --no-vad."
            VAD_MODE="on"; shift ;;
        --no-vad)
            [[ -z "$VAD_MODE" ]] || die "Use only one of --vad or --no-vad."
            VAD_MODE="off"; shift ;;
        --normalize) NORMALIZE=1; shift ;;
        --amplify)
            (( $# >= 2 )) || die "--amplify requires FACTOR."
            [[ -z "$AMPLIFY_DB" ]] || die "--amplify and --amplify-db are mutually exclusive."
            AMPLIFY="$2"; shift 2 ;;
        --amplify-db)
            (( $# >= 2 )) || die "--amplify-db requires DB."
            [[ -z "$AMPLIFY" ]] || die "--amplify and --amplify-db are mutually exclusive."
            AMPLIFY_DB="$2"; shift 2 ;;
        --timestamp)
            [[ -z "$TIMESTAMP_MODE" ]] || die "Use only one of --timestamp or --no-timestamp."
            TIMESTAMP_MODE="on"; shift ;;
        --no-timestamp)
            [[ -z "$TIMESTAMP_MODE" ]] || die "Use only one of --timestamp or --no-timestamp."
            TIMESTAMP_MODE="off"; shift ;;
        --force) FORCE=1; shift ;;
        --recursive|--recursif|--récursif|--récursive) RECURSIVE=1; shift ;;
        *) die "Unknown argument: $1" ;;
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
    (( EXEC_MODE == 0 && SIMULATE_MODE == 0 )) || die "--prerequis must be used alone."
    check_shell_prerequisites
    exit $?
fi

(( EXEC_MODE + SIMULATE_MODE == 1 )) || die "Use exactly one execution gate: --exec or --simulate."
[[ -n "$MODEL" ]] || die "--exec/--simulate requires --model <NAME>."
[[ -x "$PYTHON" ]] || die "Missing ${PYTHON}. Run ./install_pip.sh --install first."
[[ -f "$PY_SCRIPT" ]] || die "Missing ${PY_SCRIPT}."
"$PYTHON" -c 'import faster_whisper, ctranslate2, av' >/dev/null 2>&1 \
    || die "Faster-Whisper runtime is incomplete. Run ./install.sh --install."

printf -v DEEPECHO_ORIGINAL_COMMAND '%q ' "$0" "${ORIGINAL_ARGS[@]}"
DEEPECHO_ORIGINAL_COMMAND="${DEEPECHO_ORIGINAL_COMMAND% }"
export DEEPECHO_ORIGINAL_COMMAND
exec "$PYTHON" "$PY_SCRIPT" "${ORIGINAL_ARGS[@]}"
