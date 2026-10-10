#!/usr/bin/env bash
# ==============================================================================
# PATH         : ./install.sh
# SCRIPT NAME  : install.sh
# AUTHOR       : Bruno DELNOZ
# EMAIL        : bruno.delnoz@protonmail.com
# TARGET USAGE : Install and validate Faster-Whisper inside project .venv
# VERSION      : V2.0.0
# DATE         : 2026-10-10 04:20 CEST
# ==============================================================================
# CHANGELOG:
#   V2.0.0 - 2026-10-10 04:20 CEST - Bruno DELNOZ
#       RELEASE:
#       - Promoted the validated source to major release V2.0.0.
#       - Synchronized CLI/log version metadata; no behavior changes.
#   V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
#       CHANGED:
#       - Validation candidate; not a release tag.
#       - Real install/purge actions log under repository ./logs/.
#       - Log names use *-YYYYMMDD-HHMM-SS.log.
#       - Installer ensures required runtime .gitignore rules additively.
#       - Existing .gitignore lines and duplicate entries are never removed.
#       - Preserved project-local .venv, --no-cache-dir, pip check and runtime
#         import/version validation.
#   V1.0.0 - 2026-10-09 10:46 UTC - Bruno DELNOZ
#       - Initial Faster-Whisper runtime installer.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
RUN_DIR="$(pwd -P)"
VERSION="V2.0.0"
VERSION_DATE="2026-10-10 04:20 CEST"
AUTHOR="Bruno DELNOZ"
EMAIL="bruno.delnoz@protonmail.com"
VENV_DIR="${SCRIPT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
GITIGNORE_FILE="${SCRIPT_DIR}/.gitignore"
LOG_DIR="${SCRIPT_DIR}/logs"
MIN_FREE_MB=4096
LOG_FILE=""

GITIGNORE_REQUIRED=(
    ".venv/"
    ".VENV/"
    "venv/"
    "models/"
    ".zip/"
    ".old/"
    ".logs/"
    "logs/"
    ".exports/"
    ".export/"
    ".transcription/"
    "__pycache__/"
    "*.pyc"
    "*.log"
)

show_help() {
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ${SCRIPT_NAME} - ${VERSION} - ${VERSION_DATE}
  Author : ${AUTHOR} <${EMAIL}>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIPTION
  Install Faster-Whisper and dependencies into the project-local .venv.
  install_pip.sh must prepare .venv and requirements.txt first.

USAGE
  ./${SCRIPT_NAME} --help
  ./${SCRIPT_NAME} --prerequis
  ./${SCRIPT_NAME} --simulate
  ./${SCRIPT_NAME} --install
  ./${SCRIPT_NAME} --exec
  ./${SCRIPT_NAME} --purge
  ./${SCRIPT_NAME} --changelog

ACTIONS
  --exec,       -exe   Run installation. Equivalent to --install.
  --simulate,   -s     Show operations without modifying runtime.
  --prerequis,  -pr    Check .venv, requirements and disk space; read-only.
  --install,    -i     Install requirements and validate Faster-Whisper.
  --changelog,  -ch    Display complete internal changelog.
  --purge,      -pu    Remove only project .venv; preserve requirements/logs.
  --help,       -h     Display help and perform no action.

DEFAULTS
  Project directory : ${SCRIPT_DIR}
  Virtualenv        : ${VENV_DIR}
  Requirements      : ${REQUIREMENTS_FILE}
  Git ignore        : ${GITIGNORE_FILE}
  Runtime logs      : ${LOG_DIR}/
  Log naming        : install-${VERSION}-YYYYMMDD-HHMM-SS.log
  Minimum free disk : ${MIN_FREE_MB} MiB
  pip cache         : disabled during installation (--no-cache-dir)

IMPORTANT BEHAVIOR
  - No argument displays help and performs no action.
  - --prerequis and --simulate are read-only and create no logs.
  - Real install/purge actions create timestamped logs under ./logs/.
  - .gitignore is only extended; no existing line or duplicate is removed.
  - Faster-Whisper is installed only inside .venv, never system-wide.
  - Whisper models are not downloaded by this installer.

EXAMPLES
  ./${SCRIPT_NAME} --prerequis
  ./${SCRIPT_NAME} --simulate
  ./${SCRIPT_NAME} --install
  ./${SCRIPT_NAME} --exec
  ./${SCRIPT_NAME} --changelog
  ./${SCRIPT_NAME} --purge
EOF
}

show_changelog() {
    cat <<'EOF'
# install.sh changelog

## V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
- CHANGED: Validation candidate; not a release tag.
- ADDED: Repository-local ./logs/ for real install/purge actions.
- ADDED: Timestamped log naming: install-V1.1.0-dev-YYYYMMDD-HHMM-SS.log.
- ADDED: Automatic additive .gitignore maintenance.
- PRESERVED: Existing .gitignore lines and duplicates are never removed.
- PRESERVED: .venv-only install, --no-cache-dir, pip check and import validation.

## V1.0.0 - 2026-10-09 10:46 UTC - Bruno DELNOZ
- ADDED: Initial Faster-Whisper runtime installer and validation.
EOF
}

print_step() {
    local current="$1" total="$2"
    shift 2
    printf '[%s/%s] %s\n' "$current" "$total" "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

stamp_now() {
    date '+%Y%m%d-%H%M-%S'
}

setup_log() {
    mkdir -p -- "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/install-${VERSION}-$(stamp_now).log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    printf 'LOG FILE: %s\n' "$LOG_FILE"
}

ensure_gitignore() {
    local entry added=0
    if [[ ! -f "$GITIGNORE_FILE" ]]; then
        : > "$GITIGNORE_FILE"
        printf 'Created: %s\n' "$GITIGNORE_FILE"
    fi
    for entry in "${GITIGNORE_REQUIRED[@]}"; do
        if grep -Fqx -- "$entry" "$GITIGNORE_FILE" 2>/dev/null; then
            printf 'Preserved .gitignore rule: %s\n' "$entry"
        else
            printf '%s\n' "$entry" >> "$GITIGNORE_FILE"
            printf 'Added .gitignore rule    : %s\n' "$entry"
            added=$((added + 1))
        fi
    done
    printf '.gitignore additions     : %s\n' "$added"
}

free_mb_for_path() {
    local target="$1"
    df -Pk -- "$target" 2>/dev/null | awk 'NR==2 {printf "%d\n", $4/1024}'
}

filesystem_for_path() {
    local target="$1"
    df -P -- "$target" 2>/dev/null | awk 'NR==2 {print $1}'
}

venv_python_version_ok() {
    "$VENV_PYTHON" - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 9) else 1)
PY
}

check_prerequisites() {
    local failures=0 free_run free_project fs_run fs_project
    printf 'PREREQUISITES\n%s\n' '------------------------------------------------------------'

    for cmd in bash df awk grep tee date; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf 'PRESENT : %-17s: %s\n' "$cmd" "$(command -v "$cmd")"
        else
            printf 'MISSING : %-17s: required by %s\n' "$cmd" "$SCRIPT_NAME"
            failures=$((failures + 1))
        fi
    done

    if [[ -x "$VENV_PYTHON" ]]; then
        printf 'PRESENT : .venv Python      : %s\n' "$("$VENV_PYTHON" --version 2>&1)"
        if venv_python_version_ok; then
            printf 'PRESENT : Python >= 3.9     : compatible\n'
        else
            printf 'MISSING : Python >= 3.9     : rebuild .venv with install_pip.sh\n'
            failures=$((failures + 1))
        fi
    else
        printf 'MISSING : .venv Python      : run ./install_pip.sh --install\n'
        failures=$((failures + 1))
    fi

    if [[ -x "$VENV_PYTHON" ]] && "$VENV_PYTHON" -m pip --version >/dev/null 2>&1; then
        printf 'PRESENT : .venv pip         : %s\n' "$("$VENV_PYTHON" -m pip --version 2>&1)"
    else
        printf 'MISSING : .venv pip         : run ./install_pip.sh --install\n'
        failures=$((failures + 1))
    fi

    if [[ -f "$REQUIREMENTS_FILE" ]]; then
        printf 'PRESENT : requirements.txt  : %s\n' "$REQUIREMENTS_FILE"
        if grep -Eiq '^[[:space:]]*faster-whisper([[:space:]@<>=!~]|$)' "$REQUIREMENTS_FILE"; then
            printf 'PRESENT : faster-whisper req: declared\n'
        else
            printf 'MISSING : faster-whisper req: rerun ./install_pip.sh --install\n'
            failures=$((failures + 1))
        fi
    else
        printf 'MISSING : requirements.txt  : run ./install_pip.sh --install\n'
        failures=$((failures + 1))
    fi

    free_run="$(free_mb_for_path "." || true)"
    fs_run="$(filesystem_for_path "." || true)"
    if [[ "$free_run" =~ ^[0-9]+$ ]] && (( free_run >= MIN_FREE_MB )); then
        printf 'PRESENT : free space on .   : %s MiB on %s\n' "$free_run" "${fs_run:-unknown}"
    else
        printf 'MISSING : free space on .   : %s MiB; %s MiB required\n' "${free_run:-unknown}" "$MIN_FREE_MB"
        failures=$((failures + 1))
    fi

    free_project="$(free_mb_for_path "$SCRIPT_DIR" || true)"
    fs_project="$(filesystem_for_path "$SCRIPT_DIR" || true)"
    if [[ "$SCRIPT_DIR" != "$RUN_DIR" ]] || [[ "$fs_project" != "$fs_run" ]]; then
        if [[ "$free_project" =~ ^[0-9]+$ ]] && (( free_project >= MIN_FREE_MB )); then
            printf 'PRESENT : project free space: %s MiB on %s\n' "$free_project" "${fs_project:-unknown}"
        else
            printf 'MISSING : project free space: %s MiB; %s MiB required\n' "${free_project:-unknown}" "$MIN_FREE_MB"
            failures=$((failures + 1))
        fi
    fi

    if [[ -f "$GITIGNORE_FILE" ]]; then
        printf 'PRESENT : .gitignore        : %s\n' "$GITIGNORE_FILE"
        for entry in "${GITIGNORE_REQUIRED[@]}"; do
            if grep -Fqx -- "$entry" "$GITIGNORE_FILE"; then
                printf 'PRESENT : gitignore rule    : %s\n' "$entry"
            else
                printf 'NOTICE  : gitignore missing : %s (added by real install)\n' "$entry"
            fi
        done
    else
        printf 'NOTICE  : .gitignore        : real install will create/extend it\n'
    fi

    printf '%s\n' '------------------------------------------------------------'
    if (( failures == 0 )); then
        printf 'RESULT  : OK\n'
        return 0
    fi
    printf 'RESULT  : FAIL (%s prerequisite issue(s))\n' "$failures"
    return 1
}

run_install() {
    local total=7
    ensure_gitignore
    setup_log
    printf 'DeepEcho runtime installation started: %s\n' "$(date -Is)"
    check_prerequisites || fail "Prerequisites are not satisfied. Run ./install_pip.sh --install first if needed."

    print_step 1 "$total" "Confirming isolated Python target"
    [[ "$VENV_PYTHON" == "${SCRIPT_DIR}/.venv/bin/python" ]] || fail "Unsafe virtualenv Python path: $VENV_PYTHON"

    print_step 2 "$total" "Extending .gitignore without removing existing lines"
    ensure_gitignore

    print_step 3 "$total" "Installing requirements inside .venv"
    "$VENV_PYTHON" -m pip install --no-cache-dir -r "$REQUIREMENTS_FILE"

    print_step 4 "$total" "Checking installed dependency consistency"
    "$VENV_PYTHON" -m pip check

    print_step 5 "$total" "Validating Faster-Whisper runtime imports"
    "$VENV_PYTHON" - <<'PY'
from importlib.metadata import PackageNotFoundError, version
for package in ("faster-whisper", "ctranslate2", "av"):
    try:
        print(f"{package}: {version(package)}")
    except PackageNotFoundError as exc:
        raise SystemExit(f"Missing package after installation: {package}") from exc
from faster_whisper import WhisperModel
import av
import ctranslate2
print(f"WhisperModel import: OK ({WhisperModel.__name__})")
print(f"CTranslate2 import: OK ({ctranslate2.__version__})")
print(f"PyAV import: OK ({av.__version__})")
PY

    print_step 6 "$total" "Confirming no model download was performed"
    printf 'Models downloaded: NO\n'

    print_step 7 "$total" "Installation validation complete"
    printf '\nINSTALLATION RESULT: OK\n'
    printf 'Virtualenv: %s\n' "$VENV_DIR"
    printf 'Log       : %s\n' "$LOG_FILE"
}

run_simulate() {
    check_prerequisites || true
    cat <<EOF

SIMULATION ONLY - no package/file modification and no log creation.
1. Validate ${VENV_DIR}
2. Validate ${REQUIREMENTS_FILE}
3. Extend ${GITIGNORE_FILE} only with missing runtime exclusions
4. Execute ${VENV_PYTHON} -m pip install --no-cache-dir -r ${REQUIREMENTS_FILE}
5. Execute ${VENV_PYTHON} -m pip check
6. Import/report faster-whisper, ctranslate2 and av
7. A real run would log under ${LOG_DIR}/ with YYYYMMDD-HHMM-SS
8. No Whisper model download is performed by this installer
EOF
}

run_purge() {
    ensure_gitignore
    setup_log
    ensure_gitignore
    [[ "$VENV_DIR" == "${SCRIPT_DIR}/.venv" ]] || fail "Unsafe virtualenv path: $VENV_DIR"
    if [[ ! -e "$VENV_DIR" ]]; then
        printf 'Nothing to purge: %s does not exist.\n' "$VENV_DIR"
    else
        rm -rf -- "$VENV_DIR"
        printf 'PURGED: %s\n' "$VENV_DIR"
    fi
    printf 'Preserved: %s\n' "$REQUIREMENTS_FILE"
    printf 'Preserved: %s\n' "$LOG_DIR"
    printf 'Log      : %s\n' "$LOG_FILE"
    printf 'Rebuild with: ./install_pip.sh --install && ./install.sh --install\n'
}

main() {
    if (( $# == 0 )); then
        show_help
        return 0
    fi
    if (( $# != 1 )); then
        fail "Exactly one control action is accepted. Run ./${SCRIPT_NAME} --help."
    fi
    case "$1" in
        --help|-h) show_help ;;
        --changelog|-ch) show_changelog ;;
        --prerequis|-pr) check_prerequisites ;;
        --simulate|-s) run_simulate ;;
        --install|-i|--exec|-exe) run_install ;;
        --purge|-pu) run_purge ;;
        *) fail "Unknown option: $1. Run ./${SCRIPT_NAME} --help." ;;
    esac
}

main "$@"
