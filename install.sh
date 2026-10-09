#!/usr/bin/env bash
# ==============================================================================
# PATH         : ./install.sh
# SCRIPT NAME  : install.sh
# AUTHOR       : Bruno DELNOZ
# EMAIL        : bruno.delnoz@protonmail.com
# TARGET USAGE : Install and validate Faster-Whisper inside the project .venv
# VERSION      : v1.0.0
# DATE         : 2026-10-09 10:46 UTC
# ==============================================================================
# CHANGELOG:
#   v1.0.0 – 2026-10-09 10:46 UTC – Bruno DELNOZ
#       ADDED:
#       - Initial Faster-Whisper runtime installer.
#       - Requires the .venv and requirements.txt prepared by install_pip.sh.
#       - Checks free disk space on the current directory filesystem.
#       - Installs requirements strictly inside the project-local .venv.
#       - Uses --no-cache-dir to avoid persistent pip cache growth.
#       - Validates pip dependency consistency and imports Faster-Whisper,
#         CTranslate2 and PyAV after installation.
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
VENV_PYTHON="${VENV_DIR}/bin/python"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
MIN_FREE_MB=4096

show_help() {
    cat <<EOF_HELP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ${SCRIPT_NAME} – ${VERSION} – ${VERSION_DATE}
  Author : ${AUTHOR} <${EMAIL}>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIPTION:
  Install Faster-Whisper and its Python dependencies into the project .venv.
  install_pip.sh must have prepared .venv and requirements.txt first.

USAGE:
  ./${SCRIPT_NAME} --help
  ./${SCRIPT_NAME} --prerequis
  ./${SCRIPT_NAME} --simulate
  ./${SCRIPT_NAME} --install
  ./${SCRIPT_NAME} --exec
  ./${SCRIPT_NAME} --purge
  ./${SCRIPT_NAME} --changelog

ACTIONS:
  --exec,       -exe   Run the installation action. Equivalent to --install.
  --simulate,   -s     Show installation operations without modifying .venv.
  --prerequis,  -pr    Check .venv, requirements and free disk space.
  --install,    -i     Install requirements and validate Faster-Whisper.
  --changelog,  -ch    Display the complete internal changelog.
  --purge,      -pu    Remove only the project .venv runtime environment.
  --help,       -h     Display this help.

DEFAULTS:
  Project directory : ${SCRIPT_DIR}
  Virtualenv        : ${VENV_DIR}
  Requirements      : ${REQUIREMENTS_FILE}
  Minimum free disk : ${MIN_FREE_MB} MiB
  Disk check target : current directory (.) = ${RUN_DIR}
  pip cache         : disabled during installation (--no-cache-dir)

REQUIREMENTS:
  - install_pip.sh --install must have completed successfully.
  - Python 3.9 or newer inside .venv.
  - requirements.txt must contain faster-whisper.

IMPORTANT BEHAVIOR:
  - No argument displays this help and performs no installation.
  - --prerequis is read-only.
  - --simulate performs no modification.
  - Faster-Whisper is installed only inside .venv, never system-wide.
  - System FFmpeg is not required by Faster-Whisper; PyAV bundles FFmpeg libs.
  - Whisper models are not downloaded by this installer.

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
# install.sh changelog

## v1.0.0 – 2026-10-09 10:46 UTC – Bruno DELNOZ
- ADDED: Initial Faster-Whisper runtime installer.
- ADDED: Validation of .venv and requirements.txt from install_pip.sh.
- ADDED: Free-space check on the current directory filesystem.
- ADDED: Faster-Whisper installation inside project-local .venv only.
- ADDED: --no-cache-dir to avoid persistent pip cache growth.
- ADDED: pip check plus Faster-Whisper/CTranslate2/PyAV import/version validation.
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
    local failures=0
    local free_run free_project fs_run fs_project

    printf 'PREREQUISITES\n'
    printf '%s\n' '------------------------------------------------------------'

    for cmd in bash df awk grep; do
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
            printf 'MISSING : Python >= 3.9     : rebuild .venv with ./install_pip.sh --purge then --install\n'
            failures=$((failures + 1))
        fi
    else
        printf 'MISSING : .venv Python      : run ./install_pip.sh --install\n'
        failures=$((failures + 1))
    fi

    if [[ -x "$VENV_PYTHON" ]] && "$VENV_PYTHON" -m pip --version >/dev/null 2>&1; then
        printf 'PRESENT : .venv pip         : %s\n' "$($VENV_PYTHON -m pip --version 2>&1)"
    else
        printf 'MISSING : .venv pip         : run ./install_pip.sh --install\n'
        failures=$((failures + 1))
    fi

    if [[ -f "$REQUIREMENTS_FILE" ]]; then
        printf 'PRESENT : requirements.txt  : %s\n' "$REQUIREMENTS_FILE"
        if grep -Eiq '^[[:space:]]*faster-whisper([[:space:]@<>=!~]|$)' "$REQUIREMENTS_FILE"; then
            printf 'PRESENT : faster-whisper req: declared\n'
        else
            printf 'MISSING : faster-whisper req: run ./install_pip.sh --install\n'
            failures=$((failures + 1))
        fi
    else
        printf 'MISSING : requirements.txt  : run ./install_pip.sh --install\n'
        failures=$((failures + 1))
    fi

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

    printf '%s\n' '------------------------------------------------------------'
    if (( failures == 0 )); then
        printf 'RESULT  : OK\n'
        return 0
    fi

    printf 'RESULT  : FAIL (%s prerequisite issue(s))\n' "$failures"
    return 1
}

run_install() {
    local total=5

    check_prerequisites || fail "Prerequisites are not satisfied. Run ./install_pip.sh --install first if needed."

    print_step 1 "$total" "Confirming isolated Python target"
    [[ "$VENV_PYTHON" == "${SCRIPT_DIR}/.venv/bin/python" ]] || fail "Unsafe virtualenv Python path: $VENV_PYTHON"

    print_step 2 "$total" "Installing requirements inside .venv"
    "$VENV_PYTHON" -m pip install --no-cache-dir -r "$REQUIREMENTS_FILE"

    print_step 3 "$total" "Checking installed dependency consistency"
    "$VENV_PYTHON" -m pip check

    print_step 4 "$total" "Validating Faster-Whisper runtime imports"
    "$VENV_PYTHON" - <<'PY'
from importlib.metadata import PackageNotFoundError, version

packages = ("faster-whisper", "ctranslate2", "av")
for package in packages:
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

    print_step 5 "$total" "Installation validation complete"
    printf '\nINSTALLATION RESULT: OK\n'
    printf 'Virtualenv: %s\n' "$VENV_DIR"
    printf 'Models downloaded: NO\n'
}

run_simulate() {
    check_prerequisites || true
    cat <<EOF_SIM

SIMULATION ONLY — no package will be installed.
1. Validate ${VENV_DIR}
2. Validate ${REQUIREMENTS_FILE}
3. Execute: ${VENV_PYTHON} -m pip install --no-cache-dir -r ${REQUIREMENTS_FILE}
4. Execute: ${VENV_PYTHON} -m pip check
5. Import and report versions for faster-whisper, ctranslate2 and av
6. No Whisper model download is performed by this installer
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
