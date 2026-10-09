#!/usr/bin/env bash
# ==============================================================================
# PATH         : ./install_pip.sh
# SCRIPT NAME  : install_pip.sh
# AUTHOR       : Bruno DELNOZ
# EMAIL        : bruno.delnoz@protonmail.com
# TARGET USAGE : Bootstrap the project Python virtual environment and requirements
# VERSION      : v1.0.0
# DATE         : 2026-10-09 10:46 UTC
# ==============================================================================
# CHANGELOG:
#   v1.0.0 – 2026-10-09 10:46 UTC – Bruno DELNOZ
#       ADDED:
#       - Initial Faster-Whisper Python bootstrap installer.
#       - Checks free disk space on the current directory filesystem before work.
#       - Creates the project-local .venv virtual environment.
#       - Upgrades pip, setuptools and wheel inside .venv only.
#       - Creates requirements.txt when absent and ensures faster-whisper is listed (official release 1.2.1).
#       - Uses --no-cache-dir to avoid filling the user pip cache unnecessarily.
#       - Adds SOLO CLI controls: help, exec, prerequis, install, simulate,
#         changelog and purge.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
RUN_DIR="$(pwd -P)"
VERSION="v1.0.0"
VERSION_DATE="2026-10-09 10:46 UTC"
AUTHOR="Bruno DELNOZ"
EMAIL="bruno.delnoz@protonmail.com"
VENV_DIR="${SCRIPT_DIR}/.venv"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
MIN_FREE_MB=4096

show_help() {
    cat <<EOF_HELP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ${SCRIPT_NAME} – ${VERSION} – ${VERSION_DATE}
  Author : ${AUTHOR} <${EMAIL}>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIPTION:
  Bootstrap the Python environment used by DeepEcho_faster_whisper.
  This script must be executed before install.sh.

USAGE:
  ./${SCRIPT_NAME} --help
  ./${SCRIPT_NAME} --prerequis
  ./${SCRIPT_NAME} --simulate
  ./${SCRIPT_NAME} --install
  ./${SCRIPT_NAME} --exec
  ./${SCRIPT_NAME} --purge
  ./${SCRIPT_NAME} --changelog

ACTIONS:
  --exec,       -exe   Run the bootstrap action. Equivalent to --install.
  --simulate,   -s     Show the bootstrap operations without modifying files.
  --prerequis,  -pr    Check prerequisites and free disk space.
  --install,    -i     Create/update .venv and requirements.txt.
  --changelog,  -ch    Display the complete internal changelog.
  --purge,      -pu    Remove only the project .venv created by this script.
  --help,       -h     Display this help.

DEFAULTS:
  Project directory : ${SCRIPT_DIR}
  Virtualenv        : ${VENV_DIR}
  Requirements      : ${REQUIREMENTS_FILE}
  Minimum free disk : ${MIN_FREE_MB} MiB
  Disk check target : current directory (.) = ${RUN_DIR}
  pip cache         : disabled during bootstrap (--no-cache-dir)

FILES GENERATED:
  ${VENV_DIR}/
  ${REQUIREMENTS_FILE}   (created only if absent; preserved otherwise)

IMPORTANT BEHAVIOR:
  - No argument displays this help and performs no installation.
  - --prerequis is read-only.
  - --simulate performs no modification.
  - Faster-Whisper itself is installed later by install.sh.
  - The virtual environment is always project-local and isolated.

EXAMPLES:
  ./${SCRIPT_NAME} --prerequis
  ./${SCRIPT_NAME} --simulate
  ./${SCRIPT_NAME} --install
  ./${SCRIPT_NAME} --exec
  ./${SCRIPT_NAME} --changelog
EOF_HELP
}

show_changelog() {
    cat <<'EOF_CHANGELOG'
# install_pip.sh changelog

## v1.0.0 – 2026-10-09 10:46 UTC – Bruno DELNOZ
- ADDED: Initial Faster-Whisper Python bootstrap installer.
- ADDED: Free-space check on the current directory filesystem.
- ADDED: Project-local .venv creation.
- ADDED: pip/setuptools/wheel bootstrap inside .venv.
- ADDED: requirements.txt creation/preservation with faster-whisper==1.2.1 requirement.
- ADDED: --no-cache-dir to avoid persistent pip cache growth.
- ADDED: --help/-h, --exec/-exe, --prerequis/-pr, --install/-i,
  --simulate/-s, --changelog/-ch and --purge/-pu.
EOF_CHANGELOG
}

print_step() {
    local current="$1"
    local total="$2"
    shift 2
    printf '[%s/%s] %s\n' "$current" "$total" "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
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
    return 0
}

check_prerequisites() {
    local failures=0
    local free_run free_project fs_run fs_project

    printf 'PREREQUISITES\n'
    printf '%s\n' '------------------------------------------------------------'

    if command -v bash >/dev/null 2>&1; then
        printf 'PRESENT : bash              : %s\n' "$(bash --version | head -n1)"
    else
        printf 'MISSING : bash              : install bash\n'
        failures=$((failures + 1))
    fi

    if command -v python3 >/dev/null 2>&1; then
        printf 'PRESENT : python3           : %s\n' "$(python3 --version 2>&1)"
        if python_version_ok; then
            printf 'PRESENT : Python >= 3.9     : compatible\n'
        else
            printf 'MISSING : Python >= 3.9     : Faster-Whisper requires Python 3.9+\n'
            failures=$((failures + 1))
        fi
    else
        printf 'MISSING : python3           : sudo apt install python3\n'
        failures=$((failures + 1))
    fi

    if command -v python3 >/dev/null 2>&1 && check_venv_support; then
        printf 'PRESENT : Python venv       : available\n'
    else
        printf 'MISSING : Python venv       : sudo apt install python3-venv\n'
        failures=$((failures + 1))
    fi

    for cmd in df awk grep sed; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf 'PRESENT : %-17s: %s\n' "$cmd" "$(command -v "$cmd")"
        else
            printf 'MISSING : %-17s: required by %s\n' "$cmd" "$SCRIPT_NAME"
            failures=$((failures + 1))
        fi
    done

    free_run="$(free_mb_for_path "." || true)"
    fs_run="$(filesystem_for_path "." || true)"
    if [[ "$free_run" =~ ^[0-9]+$ ]]; then
        if (( free_run >= MIN_FREE_MB )); then
            printf 'PRESENT : free space on .   : %s MiB on %s\n' "$free_run" "${fs_run:-unknown}"
        else
            printf 'MISSING : free space on .   : %s MiB available; %s MiB required\n' "$free_run" "$MIN_FREE_MB"
            failures=$((failures + 1))
        fi
    else
        printf 'MISSING : free space on .   : unable to determine with df\n'
        failures=$((failures + 1))
    fi

    free_project="$(free_mb_for_path "$SCRIPT_DIR" || true)"
    fs_project="$(filesystem_for_path "$SCRIPT_DIR" || true)"
    if [[ "$SCRIPT_DIR" != "$RUN_DIR" ]] || [[ "$fs_project" != "$fs_run" ]]; then
        if [[ "$free_project" =~ ^[0-9]+$ ]]; then
            if (( free_project >= MIN_FREE_MB )); then
                printf 'PRESENT : project free space: %s MiB on %s\n' "$free_project" "${fs_project:-unknown}"
            else
                printf 'MISSING : project free space: %s MiB available; %s MiB required\n' "$free_project" "$MIN_FREE_MB"
                failures=$((failures + 1))
            fi
        else
            printf 'MISSING : project free space: unable to determine with df\n'
            failures=$((failures + 1))
        fi
    fi

    if [[ -f "${SCRIPT_DIR}/.gitignore" ]]; then
        if grep -Eq '^[[:space:]]*\.venv/?[[:space:]]*$' "${SCRIPT_DIR}/.gitignore"; then
            printf 'PRESENT : .gitignore .venv  : excluded\n'
        else
            printf 'NOTICE  : .gitignore .venv  : .venv/ is not currently excluded\n'
        fi
    else
        printf 'NOTICE  : .gitignore        : not found beside script\n'
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
        cat > "$REQUIREMENTS_FILE" <<'EOF_REQ'
# DeepEcho_faster_whisper runtime requirements
# Installed inside the project-local .venv by install.sh.
faster-whisper==1.2.1
EOF_REQ
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
    local total=5

    check_prerequisites || fail "Prerequisites are not satisfied. Run ./${SCRIPT_NAME} --prerequis for details."

    print_step 1 "$total" "Checking target paths"
    [[ "$VENV_DIR" == "${SCRIPT_DIR}/.venv" ]] || fail "Unsafe virtualenv path: $VENV_DIR"

    print_step 2 "$total" "Creating project virtual environment when absent"
    if [[ -d "$VENV_DIR" ]]; then
        [[ -x "$VENV_DIR/bin/python" ]] || fail "Existing .venv is incomplete: $VENV_DIR/bin/python is missing"
        printf 'Preserved: %s\n' "$VENV_DIR"
    else
        python3 -m venv "$VENV_DIR"
        printf 'Created: %s\n' "$VENV_DIR"
    fi

    print_step 3 "$total" "Bootstrapping pip tooling inside .venv"
    "$VENV_DIR/bin/python" -m pip install --no-cache-dir --upgrade pip setuptools wheel

    print_step 4 "$total" "Creating or preserving requirements.txt"
    ensure_requirements

    print_step 5 "$total" "Validating virtual environment"
    "$VENV_DIR/bin/python" -m pip --version
    "$VENV_DIR/bin/python" - <<'PY'
import sys
print(f"Virtualenv Python: {sys.version.split()[0]}")
print(f"Executable: {sys.executable}")
PY

    printf '\nBOOTSTRAP RESULT: OK\n'
    printf 'Next command: ./install.sh --prerequis\n'
    printf 'Then        : ./install.sh --install\n'
}

run_simulate() {
    check_prerequisites || true
    cat <<EOF_SIM

SIMULATION ONLY — no file will be modified.
1. Validate ${VENV_DIR}
2. Create ${VENV_DIR} with python3 -m venv if absent
3. Upgrade pip/setuptools/wheel inside ${VENV_DIR} with --no-cache-dir
4. Create ${REQUIREMENTS_FILE} if absent
5. Preserve existing requirements and add faster-whisper==1.2.1 only when missing
6. Validate .venv Python and pip
EOF_SIM
}

run_purge() {
    [[ "$VENV_DIR" == "${SCRIPT_DIR}/.venv" ]] || fail "Unsafe virtualenv path: $VENV_DIR"
    if [[ ! -e "$VENV_DIR" ]]; then
        printf 'Nothing to purge: %s does not exist.\n' "$VENV_DIR"
        return 0
    fi
    rm -rf -- "$VENV_DIR"
    printf 'PURGED: %s\n' "$VENV_DIR"
    printf 'Preserved: %s\n' "$REQUIREMENTS_FILE"
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
        --help|-h)
            show_help
            ;;
        --changelog|-ch)
            show_changelog
            ;;
        --prerequis|-pr)
            check_prerequisites
            ;;
        --simulate|-s)
            run_simulate
            ;;
        --install|-i|--exec|-exe)
            run_install
            ;;
        --purge|-pu)
            run_purge
            ;;
        *)
            fail "Unknown option: $1. Run ./${SCRIPT_NAME} --help."
            ;;
    esac
}

main "$@"
