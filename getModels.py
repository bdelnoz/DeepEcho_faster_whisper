#!/usr/bin/env python3
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : getModels.py
# Full Path       : ./getModels.py
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V1.1.0-dev
# Date / Time     : 2026-10-09 18:32 CEST
# Target usage    : Faster-Whisper model-management backend
#
# CHANGELOG
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
import importlib.metadata
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Iterable

VERSION = "V1.1.0-dev"
DATE_TIME = "2026-10-09 18:32 CEST"
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

CHANGELOG = f"""getModels.py CHANGELOG

{VERSION} - {DATE_TIME} - {AUTHOR}
  ADDED/CHANGED:
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

    model_lines = "\n".join(
        f"  {idx:2d}. {name}" for idx, name in enumerate(MODEL_REFERENCE, start=1)
    )
    parser.epilog = f"""AVAILABLE MODEL NAMES (REFERENCE)
{model_lines}

EXAMPLES
  ./getModels.py --prerequis
  ./getModels.py --exec --list
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


def list_models(models_dir: Path) -> int:
    available_models, _ = load_faster_whisper_api()
    models = list(available_models())
    print("AVAILABLE FASTER-WHISPER MODELS")
    print("-" * 76)
    for index, model_name in enumerate(models, start=1):
        target = model_target(models_dir, model_name)
        print(f"{index:2d}. {model_name:<28} {model_status(target)}")
    print("-" * 76)
    print(f"Total            : {len(models)}")
    print(f"Models directory : {models_dir}")
    return 0


def directory_size_mib(path: Path) -> float:
    total = 0
    if not path.exists():
        return 0.0
    for item in path.rglob("*"):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            continue
    return total / (1024 ** 2)


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
        if any((args.exec, args.simulate, args.list, args.download, args.model, args.force)):
            parser.error("--prerequis is a standalone control action.")
        return run_prerequisites(models_dir)

    validate_business_action(args, parser)
    if args.list:
        return list_models(models_dir)
    return download_models_action(
        model_names=args.model,
        models_dir=models_dir,
        simulate=args.simulate,
        force=args.force,
    )


if __name__ == "__main__":
    raise SystemExit(main())
