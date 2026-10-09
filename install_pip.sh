#!/usr/bin/env bash
# ==============================================================================
# PATH         : ./install_pip.sh
# SCRIPT NAME  : install_pip.sh
# AUTHOR       : Bruno DELNOZ
# EMAIL        : bruno.delnoz@protonmail.com
# TARGET USAGE : Bootstrap project Python virtual environment and requirements
# VERSION      : V1.1.0-dev
# DATE         : 2026-10-09 18:32 CEST
# ==============================================================================
# CHANGELOG:
#   V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
#       CHANGED:
#       - Validation candidate; not a release tag.
#       - Real bootstrap/purge actions now log to ./logs/ in the repository.
#       - Log names use *-YYYYMMDD-HHMM-SS.log.
#       - Installer now ensures required runtime exclusions exist in .gitignore.
#       - .gitignore handling is additive only: no line is removed or deduplicated.
#       - Existing duplicate .gitignore lines are intentionally preserved.
#       - requirements.txt remains automatically created/preserved by this stage.
#   V1.0.0 - 2026-10-09 10:46 UTC - Bruno DELNOZ
#       - Initial Faster-Whisper Python bootstrap installer.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
RUN_DIR="$(pwd -P)"
VERSION="V1.1.0-dev"
VERSION_DATE="2026-10-09 18:32 CEST"
AUTHOR="Bruno DELNOZ"
EMAIL="bruno.delnoz@protonmail.com"
VENV_DIR="${SCRIPT_DIR}/.venv"
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
  Bootstrap the Python environment used by DeepEcho_faster_whisper.
  This script must be executed before install.sh on a fresh checkout.

USAGE
  ./${SCRIPT_NAME} --help
  ./${SCRIPT_NAME} --prerequis
  ./${SCRIPT_NAME} --simulate
  ./${SCRIPT_NAME} --install
  ./${SCRIPT_NAME} --exec
  ./${SCRIPT_NAME} --purge
  ./${SCRIPT_NAME} --changelog

ACTIONS
  --exec,       -exe   Run the bootstrap action. Equivalent to --install.
  --simulate,   -s     Show bootstrap operations without modifying files.
  --prerequis,  -pr    Check prerequisites and free disk space; read-only.
  --install,    -i     Create/update .venv, .gitignore and requirements.txt.
  --changelog,  -ch    Display the complete internal changelog.
  --purge,      -pu    Remove only the project .venv; preserve requirements/logs.
  --help,       -h     Display this help and perform no action.

DEFAULTS
  Project directory : ${SCRIPT_DIR}
  Virtualenv        : ${VENV_DIR}
  Requirements      : ${REQUIREMENTS_FILE}
  Git ignore        : ${GITIGNORE_FILE}
  Runtime logs      : ${LOG_DIR}/
  Log naming        : install_pip-${VERSION}-YYYYMMDD-HHMM-SS.log
  Minimum free disk : ${MIN_FREE_MB} MiB
  Disk check target : current directory (.) = ${RUN_DIR}
  pip cache         : disabled during bootstrap (--no-cache-dir)

AUTOMATION
  - Real install/exec actions create/update all required local runtime pieces.
  - .gitignore is extended only; existing lines and duplicates are never removed.
  - requirements.txt is created automatically when missing and preserved otherwise.
  - No argument, --help, --prerequis and --simulate do not create logs or files.

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
# install_pip.sh changelog

## V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
- CHANGED: Validation candidate; not a release tag.
- ADDED: Repository-local ./logs/ for real bootstrap and purge actions.
- ADDED: Timestamped log naming: install_pip-V1.1.0-dev-YYYYMMDD-HHMM-SS.log.
- ADDED: Automatic additive .gitignore maintenance.
- PRESERVED: Existing .gitignore lines and duplicate lines are never removed.
- PRESERVED: Automatic requirements.txt creation/preservation.
- PRESERVED: Project-local .venv only; no system-wide pip.

## V1.0.0 - 2026-10-09 10:46 UTC - Bruno DELNOZ
- ADDED: Initial Faster-Whisper Python bootstrap installer.
- ADDED: Free-space check, .venv, pip tooling and requirements.txt management.
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
    LOG_FILE="${LOG_DIR}/install_pip-${VERSION}-$(stamp_now).log"
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

python_version_ok() {
    python3 - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 9) else 1)
PY
}

free_mb_for_path() {
    local target="$1"
    df -Pk -- "$target" 2>/dev/null | awk 'NR==2 {printf "%d\n", $4/1024}'
}

filesystem_for_path() {
    local target="$1"
    df -P -- "$target" 2>/dev/null | awk 'NR==2 {print $1}'
}

check_venv_support() {
    local py_mm pkg_generic pkg_versioned
    py_mm="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
    pkg_generic="python3-venv"
    pkg_versioned="python${py_mm}-venv"

    if command -v dpkg-query >/dev/null 2>&1; then
        if dpkg-query -W -f='${Status}' "$pkg_generic" 2>/dev/null | grep -q '^install ok installed$'; then
            return 0
        fi
        if [[ -n "$py_mm" ]] && dpkg-query -W -f='${Status}' "$pkg_versioned" 2>/dev/null | grep -q '^install ok installed$'; then
            return 0
        fi
    fi

    python3 -c 'import venv' >/dev/null 2>&1 || return 1
    python3 -m venv --help >/dev/null 2>&1 || return 1
}

check_prerequisites() {
    local failures=0 free_run free_project fs_run fs_project
    printf 'PREREQUISITES\n%s\n' '------------------------------------------------------------'

    for cmd in bash python3 df awk grep sed tee date; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf 'PRESENT : %-17s: %s\n' "$cmd" "$(command -v "$cmd")"
        else
            printf 'MISSING : %-17s: required by %s\n' "$cmd" "$SCRIPT_NAME"
            failures=$((failures + 1))
        fi
    done

    if command -v python3 >/dev/null 2>&1; then
        printf 'PRESENT : python3           : %s\n' "$(python3 --version 2>&1)"
        if python_version_ok; then
            printf 'PRESENT : Python >= 3.9     : compatible\n'
        else
            printf 'MISSING : Python >= 3.9     : required\n'
            failures=$((failures + 1))
        fi
    fi

    if command -v python3 >/dev/null 2>&1 && check_venv_support; then
        printf 'PRESENT : Python venv       : available\n'
    else
        printf 'MISSING : Python venv       : sudo apt install python3-venv\n'
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
        printf 'NOTICE  : .gitignore        : missing; real install will create/extend it\n'
    fi

    printf '%s\n' '------------------------------------------------------------'
    if (( failures == 0 )); then
        printf 'RESULT  : OK\n'
        return 0
    fi
    printf 'RESULT  : FAIL (%s prerequisite issue(s))\n' "$failures"
    return 1
}

ensure_requirements() {
    if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
        cat > "$REQUIREMENTS_FILE" <<'EOF'
# DeepEcho_faster_whisper runtime requirements
# Installed inside the project-local .venv by install.sh.
faster-whisper==1.2.1
EOF
        printf 'Created: %s\n' "$REQUIREMENTS_FILE"
        return 0
    fi

    if grep -Eiq '^[[:space:]]*faster-whisper([[:space:]@<>=!~]|$)' "$REQUIREMENTS_FILE"; then
        printf 'Preserved: %s (faster-whisper already present)\n' "$REQUIREMENTS_FILE"
        return 0
    fi

    printf '\n# Added by install_pip.sh %s\nfaster-whisper==1.2.1\n' "$VERSION" >> "$REQUIREMENTS_FILE"
    printf 'Updated: %s (added faster-whisper==1.2.1)\n' "$REQUIREMENTS_FILE"
}

run_install() {
    local total=7
    ensure_gitignore
    setup_log
    printf 'DeepEcho bootstrap started: %s\n' "$(date -Is)"
    check_prerequisites || fail "Prerequisites are not satisfied. Run ./${SCRIPT_NAME} --prerequis for details."

    print_step 1 "$total" "Checking target paths"
    [[ "$VENV_DIR" == "${SCRIPT_DIR}/.venv" ]] || fail "Unsafe virtualenv path: $VENV_DIR"

    print_step 2 "$total" "Extending .gitignore without removing existing lines"
    ensure_gitignore

    print_step 3 "$total" "Creating project virtual environment when absent"
    if [[ -d "$VENV_DIR" ]]; then
        [[ -x "$VENV_DIR/bin/python" ]] || fail "Existing .venv is incomplete: $VENV_DIR/bin/python is missing"
        printf 'Preserved: %s\n' "$VENV_DIR"
    else
        python3 -m venv "$VENV_DIR"
        printf 'Created: %s\n' "$VENV_DIR"
    fi

    print_step 4 "$total" "Bootstrapping pip tooling inside .venv"
    "$VENV_DIR/bin/python" -m pip install --no-cache-dir --upgrade pip setuptools wheel

    print_step 5 "$total" "Creating or preserving requirements.txt"
    ensure_requirements

    print_step 6 "$total" "Validating virtual environment"
    "$VENV_DIR/bin/python" -m pip --version
    "$VENV_DIR/bin/python" - <<'PY'
import sys
print(f"Virtualenv Python: {sys.version.split()[0]}")
print(f"Executable: {sys.executable}")
PY

    print_step 7 "$total" "Bootstrap validation complete"
    printf '\nBOOTSTRAP RESULT: OK\n'
    printf 'Log         : %s\n' "$LOG_FILE"
    printf 'Next command: ./install.sh --prerequis\n'
    printf 'Then        : ./install.sh --install\n'
}

run_simulate() {
    check_prerequisites || true
    cat <<EOF

SIMULATION ONLY - no file will be modified and no log will be created.
1. Validate target paths and free space
2. Extend ${GITIGNORE_FILE} only with missing required runtime exclusions
3. Create ${VENV_DIR} if absent
4. Upgrade pip/setuptools/wheel inside ${VENV_DIR} with --no-cache-dir
5. Create/preserve ${REQUIREMENTS_FILE} and ensure faster-whisper==1.2.1
6. Validate .venv Python and pip
7. A real run would log under ${LOG_DIR}/ with YYYYMMDD-HHMM-SS
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
