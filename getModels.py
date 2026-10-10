#!/usr/bin/env python3
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : getModels.py
# Full Path       : ./getModels.py
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V2.0.0
# Date / Time     : 2026-10-10 04:20 CEST
# Target usage    : Faster-Whisper model-management backend
#
# CHANGELOG
# V2.0.0 - 2026-10-10 04:20 CEST - Bruno DELNOZ
#   - MAJOR RELEASE: version metadata synchronized at V2.0.0.
#   - Preserved V1.1.4-dev behavior; no new runtime features.
# V1.1.1-dev - 2026-10-09 21:05 CEST - Bruno DELNOZ
#   - Added --size for live remote download-size reporting with --list.
#   - --exec --list --size queries Hugging Face file metadata before download.
#   - Reported size matches the Faster-Whisper download payload patterns rather
#     than blindly using the whole repository size.
#   - Added local on-disk size beside live remote size for diagnosis.
#   - Size lookup is read-only and does not download model payloads.
#   - Preserved multi-model, skip, incomplete/corrupt and --force behavior.
# V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
#   - Validation candidate; not a release tag.
#   - Added complete 19-model reference to help.
#   - Added multi-model downloads with --model NAME [NAME ...].
#   - Added --force for explicit replacement/redownload of requested models.
#   - Existing complete models are skipped by default.
#   - Existing incomplete model directories are reported as corrupt/incomplete
#     and require --force before replacement.
#   - --exec --list now reports INSTALLED / INCOMPLETE / not installed.
#   - Invalid model names are reported while valid requested models continue.
#   - Preserved repository-local models/<model-name>/ storage.
# V1.0.1 - 2026-10-09 15:41 - Bruno DELNOZ
#   - Initial getModels.py model-management backend.
################################################################################

from __future__ import annotations

import argparse
import fnmatch
import importlib.metadata
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Iterable

VERSION = "V2.0.0"
DATE_TIME = "2026-10-10 04:20 CEST"
AUTHOR = "Bruno DELNOZ"
EMAIL = "bruno.delnoz@protonmail.com"

MODEL_REFERENCE = (
    "tiny.en",
    "tiny",
    "base.en",
    "base",
    "small.en",
    "small",
    "medium.en",
    "medium",
    "large-v1",
    "large-v2",
    "large-v3",
    "large",
    "distil-large-v2",
    "distil-medium.en",
    "distil-small.en",
    "distil-large-v3",
    "distil-large-v3.5",
    "large-v3-turbo",
    "turbo",
)

# Official Faster-Whisper aliases and their Hugging Face repositories.
# Runtime mapping from faster_whisper.utils._MODELS is preferred when available;
# this table is the stable fallback for the 19 names documented by this project.
MODEL_REPOSITORIES = {
    "tiny.en": "Systran/faster-whisper-tiny.en",
    "tiny": "Systran/faster-whisper-tiny",
    "base.en": "Systran/faster-whisper-base.en",
    "base": "Systran/faster-whisper-base",
    "small.en": "Systran/faster-whisper-small.en",
    "small": "Systran/faster-whisper-small",
    "medium.en": "Systran/faster-whisper-medium.en",
    "medium": "Systran/faster-whisper-medium",
    "large-v1": "Systran/faster-whisper-large-v1",
    "large-v2": "Systran/faster-whisper-large-v2",
    "large-v3": "Systran/faster-whisper-large-v3",
    "large": "Systran/faster-whisper-large-v3",
    "distil-large-v2": "Systran/faster-distil-whisper-large-v2",
    "distil-medium.en": "Systran/faster-distil-whisper-medium.en",
    "distil-small.en": "Systran/faster-distil-whisper-small.en",
    "distil-large-v3": "Systran/faster-distil-whisper-large-v3",
    "distil-large-v3.5": "distil-whisper/distil-large-v3.5-ct2",
    "large-v3-turbo": "mobiuslabsgmbh/faster-whisper-large-v3-turbo",
    "turbo": "mobiuslabsgmbh/faster-whisper-large-v3-turbo",
}

# Exact patterns requested by Faster-Whisper download_model().
MODEL_DOWNLOAD_PATTERNS = (
    "config.json",
    "preprocessor_config.json",
    "model.bin",
    "tokenizer.json",
    "vocabulary.*",
)

CHANGELOG = f"""getModels.py CHANGELOG

{VERSION} - {DATE_TIME} - {AUTHOR}
  ADDED/CHANGED:
  - --size list modifier for live remote model download sizes.
  - --exec --list --size uses Hugging Face files_metadata without downloading models.
  - Remote size sums the same file patterns Faster-Whisper download_model() requests.
  - Local directory size is shown alongside remote size for installed/incomplete models.
  - Size query failures are reported explicitly instead of inventing values.
  - Validation candidate; not a release tag.
  - Complete 19-model reference in --help.
  - --model accepts one or more model names for --download.
  - --force replaces every requested local model before redownloading it.
  - Complete local models are skipped by default.
  - Incomplete/corrupt model directories require --force.
  - --list reports INSTALLED / INCOMPLETE / not installed.
  - Invalid model names are reported without silently discarding valid models.

V1.0.1 - 2026-10-09 15:41 - {AUTHOR}
  ADDED/CHANGED:
  - Model listing through faster_whisper.available_models().
  - Explicit downloads through faster_whisper.download_model().
  - Repository-local models/<model-name>/ storage.
  - --exec, --simulate, --prerequis, --changelog.
"""


def script_dir() -> Path:
    return Path(__file__).resolve().parent


def default_models_dir() -> Path:
    return script_dir() / "models"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="getModels.py",
        add_help=False,
        formatter_class=argparse.RawTextHelpFormatter,
        description=(
            "Faster-Whisper model-management backend.\n"
            "Normal user entry point: ./getModels.sh"
        ),
    )

    control = parser.add_argument_group("SOLO CONTROL OPTIONS")
    control.add_argument("--help", "-h", action="store_true",
                         help="Display help and perform no action.")
    control.add_argument("--exec", "-exe", action="store_true",
                         help="Execute the selected model action.")
    control.add_argument("--simulate", "-s", action="store_true",
                         help="Resolve/validate the action without downloading or deleting.")
    control.add_argument("--prerequis", "-pr", action="store_true",
                         help="Check the model-management runtime only.")
    control.add_argument("--changelog", "-ch", action="store_true",
                         help="Display the complete script changelog.")

    actions = parser.add_argument_group("MODEL ACTIONS")
    actions.add_argument("--list", action="store_true",
                         help="List all models exposed by installed Faster-Whisper and local status.")
    actions.add_argument("--download", action="store_true",
                         help="Download one or more models. Requires --model.")

    options = parser.add_argument_group("MODEL OPTIONS")
    options.add_argument(
        "--model",
        nargs="+",
        metavar="NAME",
        help="One or more model names, e.g. --model base small medium.",
    )
    options.add_argument(
        "--models-dir",
        metavar="PATH",
        default=str(default_models_dir()),
        help="Override model storage. Default: <repo>/models",
    )
    options.add_argument(
        "--force",
        action="store_true",
        help="With --download, remove and redownload every requested local model.",
    )
    options.add_argument(
        "--size",
        action="store_true",
        help=(
            "With --list, query live Hugging Face metadata and show the expected "
            "Faster-Whisper download size for every model."
        ),
    )

    model_lines = "\n".join(
        f"  {idx:2d}. {name}" for idx, name in enumerate(MODEL_REFERENCE, start=1)
    )
    parser.epilog = f"""AVAILABLE MODEL NAMES (REFERENCE)
{model_lines}

EXAMPLES
  ./getModels.py --prerequis
  ./getModels.py --exec --list
  ./getModels.py --exec --list --size
  ./getModels.py --simulate --download --model tiny
  ./getModels.py --exec --download --model tiny
  ./getModels.py --exec --download --model base small medium
  ./getModels.py --simulate --download --model base small medium --force
  ./getModels.py --exec --download --model base small medium --force
  ./getModels.py --exec --download --model large-v3 --models-dir /data/models
"""
    return parser


def print_help(parser: argparse.ArgumentParser) -> None:
    print(f"getModels.py {VERSION}")
    print(f"Author: {AUTHOR} <{EMAIL}>")
    print()
    parser.print_help()
    print()
    print("DEFAULT STORAGE")
    print(f"  {default_models_dir()}/<model-name>/")


def package_version(name: str) -> str:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return "MISSING"


def load_faster_whisper_api():
    try:
        from faster_whisper import available_models, download_model
    except Exception as exc:
        print(f"ERROR: faster-whisper import failed: {exc}", file=sys.stderr)
        print("Run ./install_pip.sh --install and then ./install.sh --install.", file=sys.stderr)
        raise SystemExit(2)
    return available_models, download_model


def free_space_mib(path: Path) -> int:
    probe = path
    while not probe.exists() and probe.parent != probe:
        probe = probe.parent
    return shutil.disk_usage(probe).free // (1024 * 1024)


def model_target(models_dir: Path, model_name: str) -> Path:
    return models_dir / model_name.replace("/", "__")


def model_complete(path: Path) -> bool:
    if not path.is_dir():
        return False
    config = path / "config.json"
    model = path / "model.bin"
    tokenizer = path / "tokenizer.json"
    if not (config.is_file() and model.is_file() and tokenizer.is_file()):
        return False
    try:
        return config.stat().st_size > 0 and model.stat().st_size > 0 and tokenizer.stat().st_size > 0
    except OSError:
        return False


def model_status(path: Path) -> str:
    if model_complete(path):
        return "INSTALLED"
    if path.exists():
        return "INCOMPLETE"
    return "not installed"


def git_ignore_state(models_dir: Path) -> str:
    repo = script_dir()
    if not (repo / ".git").exists():
        return "NOT_APPLICABLE"
    try:
        relative = models_dir.resolve(strict=False).relative_to(repo.resolve())
    except ValueError:
        return "OUTSIDE_REPOSITORY"
    if shutil.which("git") is None:
        return "UNKNOWN_GIT_MISSING"
    probe = str(relative / ".deepecho_gitignore_probe")
    result = subprocess.run(
        ["git", "-C", str(repo), "check-ignore", "--no-index", "-q", "--", probe],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return "IGNORED" if result.returncode == 0 else "NOT_IGNORED"


def human_size(size_bytes: int | None) -> str:
    if size_bytes is None:
        return "UNAVAILABLE"
    value = float(size_bytes)
    units = ("B", "KiB", "MiB", "GiB", "TiB")
    unit = units[0]
    for unit in units:
        if value < 1024.0 or unit == units[-1]:
            break
        value /= 1024.0
    if unit in ("B", "KiB"):
        return f"{value:.0f} {unit}"
    return f"{value:.2f} {unit}"


def directory_size_bytes(path: Path) -> int:
    total = 0
    if not path.exists():
        return 0
    for item in path.rglob("*"):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            continue
    return total


def model_repository_map() -> dict[str, str]:
    mapping = dict(MODEL_REPOSITORIES)
    try:
        from faster_whisper.utils import _MODELS
        mapping.update({str(name): str(repo) for name, repo in dict(_MODELS).items()})
    except Exception:
        pass
    return mapping


def remote_model_size_bytes(model_name: str, cache: dict[str, int]) -> int:
    repo_id = model_repository_map().get(model_name)
    if not repo_id:
        raise RuntimeError(f"no Hugging Face repository mapping for {model_name}")
    if repo_id in cache:
        return cache[repo_id]

    try:
        from huggingface_hub import HfApi
    except Exception as exc:
        raise RuntimeError(f"huggingface_hub import failed: {exc}") from exc

    try:
        info = HfApi().model_info(repo_id=repo_id, files_metadata=True)
    except TypeError:
        # Compatibility fallback for versions that do not accept keyword repo_id.
        info = HfApi().model_info(repo_id, files_metadata=True)

    total = 0
    matched = 0
    missing_metadata: list[str] = []
    for sibling in getattr(info, "siblings", ()) or ():
        filename = str(getattr(sibling, "rfilename", ""))
        if not any(fnmatch.fnmatch(filename, pattern) for pattern in MODEL_DOWNLOAD_PATTERNS):
            continue
        size = getattr(sibling, "size", None)
        if size is None:
            missing_metadata.append(filename)
            continue
        total += int(size)
        matched += 1

    if matched == 0:
        raise RuntimeError(f"no downloadable Faster-Whisper payload metadata returned for {repo_id}")
    if missing_metadata:
        raise RuntimeError(
            f"incomplete size metadata for {repo_id}: {', '.join(missing_metadata)}"
        )

    cache[repo_id] = total
    return total


def run_prerequisites(models_dir: Path) -> int:
    ok = True
    print("PREREQUISITES")
    print("-" * 72)
    print(f"PRESENT : Python               : {sys.version.split()[0]}")
    if sys.version_info < (3, 9):
        print("MISSING : Python >= 3.9        : required")
        ok = False
    else:
        print("PRESENT : Python >= 3.9        : compatible")

    for package in ("faster-whisper", "huggingface-hub", "ctranslate2"):
        version = package_version(package)
        if version == "MISSING":
            print(f"MISSING : {package:<20} : required")
            ok = False
        else:
            print(f"PRESENT : {package:<20} : {version}")

    print(f"INFO    : models directory     : {models_dir}")
    print(f"INFO    : free space           : {free_space_mib(models_dir)} MiB")
    print(f"INFO    : Git ignore           : {git_ignore_state(models_dir)}")

    if package_version("faster-whisper") != "MISSING":
        available_models, _ = load_faster_whisper_api()
        models = list(available_models())
        print(f"PRESENT : model registry       : {len(models)} model names")

    print("-" * 72)
    print("RESULT  : " + ("OK" if ok else "ERROR"))
    return 0 if ok else 2


def validate_business_action(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    if int(args.exec) + int(args.simulate) != 1:
        parser.error("Use exactly one execution gate: --exec or --simulate.")
    if int(args.list) + int(args.download) != 1:
        parser.error("Use exactly one model action: --list or --download.")
    if args.download and not args.model:
        parser.error("--download requires --model NAME [NAME ...].")
    if args.list and args.model:
        parser.error("--model is only valid with --download.")
    if args.list and args.force:
        parser.error("--force is only valid with --download.")
    if args.download and args.size:
        parser.error("--size is a list modifier. Use --exec --list --size.")


def list_models(models_dir: Path, show_size: bool) -> int:
    available_models, _ = load_faster_whisper_api()
    models = list(available_models())

    print("AVAILABLE FASTER-WHISPER MODELS")
    if not show_size:
        print("-" * 76)
        for index, model_name in enumerate(models, start=1):
            target = model_target(models_dir, model_name)
            print(f"{index:2d}. {model_name:<28} {model_status(target)}")
        print("-" * 76)
        print(f"Total            : {len(models)}")
        print(f"Models directory : {models_dir}")
        return 0

    print("Size source       : live Hugging Face metadata")
    print("Size scope        : files actually requested by Faster-Whisper download_model()")
    print("No model payload is downloaded by --list --size.")
    print("-" * 100)
    print(f"{'#':>2}  {'MODEL':<28} {'STATUS':<14} {'DOWNLOAD SIZE':>15} {'LOCAL SIZE':>15}")
    print("-" * 100)

    cache: dict[str, int] = {}
    size_errors: list[tuple[str, str]] = []
    for index, model_name in enumerate(models, start=1):
        target = model_target(models_dir, model_name)
        try:
            remote_bytes = remote_model_size_bytes(model_name, cache)
            remote_text = human_size(remote_bytes)
        except Exception as exc:
            remote_text = "UNAVAILABLE"
            size_errors.append((model_name, str(exc)))

        local_bytes = directory_size_bytes(target) if target.exists() else 0
        local_text = human_size(local_bytes) if target.exists() else "-"
        print(
            f"{index:2d}. {model_name:<28} {model_status(target):<14} "
            f"{remote_text:>15} {local_text:>15}"
        )

    print("-" * 100)
    print(f"Total            : {len(models)}")
    print(f"Models directory : {models_dir}")
    if size_errors:
        print(f"Size errors       : {len(size_errors)}", file=sys.stderr)
        for model_name, detail in size_errors:
            print(f"  - {model_name}: {detail}", file=sys.stderr)
        print("RESULT           : PARTIAL - one or more remote sizes unavailable", file=sys.stderr)
        return 1

    print("RESULT           : OK")
    return 0


def directory_size_mib(path: Path) -> float:
    return directory_size_bytes(path) / (1024 ** 2)


def download_one_model(
    model_name: str,
    models_dir: Path,
    download_model,
    simulate: bool,
    force: bool,
) -> int:
    target = model_target(models_dir, model_name)
    status = model_status(target)

    print()
    print(f"MODEL: {model_name}")
    print(f"Target: {target}")
    print(f"Local : {status}")

    if status == "INSTALLED" and not force:
        print("Action: SKIP - complete local model already exists")
        return 0

    if status == "INCOMPLETE" and not force:
        print("ERROR : local model directory is incomplete/corrupt; use --force to replace it", file=sys.stderr)
        return 2

    if simulate:
        if target.exists() and force:
            print("Action: SIMULATE - would remove existing target and redownload")
        else:
            print("Action: SIMULATE - would download model")
        return 0

    models_dir.mkdir(parents=True, exist_ok=True)
    if force and target.exists():
        print("Action: FORCE - removing existing local target")
        shutil.rmtree(target)

    print("Action: downloading Faster-Whisper CTranslate2 model")
    try:
        downloaded_path = Path(download_model(model_name, output_dir=str(target)))
    except Exception as exc:
        print(f"ERROR: download failed: {exc}", file=sys.stderr)
        return 1

    if not model_complete(downloaded_path):
        print(f"ERROR: downloaded model looks incomplete: {downloaded_path}", file=sys.stderr)
        return 1

    print(f"Downloaded: {downloaded_path}")
    print(f"Size      : {directory_size_mib(downloaded_path):.1f} MiB")
    print("RESULT    : OK")
    return 0


def download_models_action(
    model_names: Iterable[str],
    models_dir: Path,
    simulate: bool,
    force: bool,
) -> int:
    available_models, download_model = load_faster_whisper_api()
    available = set(available_models())
    requested = list(dict.fromkeys(model_names))

    print("MODEL DOWNLOAD")
    print("-" * 72)
    print(f"Mode       : {'SIMULATE' if simulate else 'EXEC'}")
    print(f"Models dir : {models_dir}")
    print(f"Requested  : {', '.join(requested)}")
    print(f"Force      : {'YES' if force else 'NO'}")
    print(f"Free space : {free_space_mib(models_dir)} MiB")

    overall_rc = 0
    for model_name in requested:
        if model_name not in available:
            print()
            print(f"MODEL: {model_name}")
            print("ERROR: unknown model name", file=sys.stderr)
            overall_rc = max(overall_rc, 2)
            continue
        rc = download_one_model(
            model_name=model_name,
            models_dir=models_dir,
            download_model=download_model,
            simulate=simulate,
            force=force,
        )
        overall_rc = max(overall_rc, rc)

    print()
    print("-" * 72)
    print("DOWNLOAD RESULT: " + ("OK" if overall_rc == 0 else "ERROR"))
    return overall_rc


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    argv = sys.argv[1:] if argv is None else argv
    if not argv:
        print_help(parser)
        return 0

    args = parser.parse_args(argv)
    if args.help:
        if len(argv) != 1:
            parser.error("--help must be used alone.")
        print_help(parser)
        return 0
    if args.changelog:
        if len(argv) != 1:
            parser.error("--changelog must be used alone.")
        print(CHANGELOG.rstrip())
        return 0

    models_dir = Path(args.models_dir).expanduser()
    models_dir = (
        models_dir.resolve(strict=False)
        if models_dir.is_absolute()
        else (Path.cwd() / models_dir).resolve(strict=False)
    )

    if args.prerequis:
        if any((args.exec, args.simulate, args.list, args.download, args.model, args.force, args.size)):
            parser.error("--prerequis is a standalone control action.")
        return run_prerequisites(models_dir)

    validate_business_action(args, parser)
    if args.list:
        return list_models(models_dir, show_size=args.size)
    return download_models_action(
        model_names=args.model,
        models_dir=models_dir,
        simulate=args.simulate,
        force=args.force,
    )


if __name__ == "__main__":
    raise SystemExit(main())
