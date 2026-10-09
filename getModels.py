#!/usr/bin/env python3
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : getModels.py
# Full Path       : ./getModels.py
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V1.0.1
# Date / Time     : 2026-10-09 15:41
# Target usage    : Faster-Whisper model-management backend
#
# CHANGELOG
# V1.0.1 - 2026-10-09 15:41 - Bruno DELNOZ
#   - Renamed the delivered backend to getModels.py.
#   - Supports the same model-management arguments as getModels.sh.
#   - Lists models through faster_whisper.available_models().
#   - Downloads through faster_whisper.download_model().
#   - Stores models by default below <repo>/models/<model-name>/.
#   - Detects already downloaded model directories.
#   - Reports model-directory free space and Git-ignore state.
#   - No argument displays help and performs no action.
################################################################################

from __future__ import annotations

import argparse
import importlib.metadata
import shutil
import subprocess
import sys
from pathlib import Path

VERSION = "V1.0.1"
DATE_TIME = "2026-10-09 15:41"
AUTHOR = "Bruno DELNOZ"
EMAIL = "bruno.delnoz@protonmail.com"

CHANGELOG = """getModels.py CHANGELOG

V1.0.1 - 2026-10-09 15:41 - Bruno DELNOZ
  ADDED/CHANGED:
  - Final camel-case file name: getModels.py.
  - Same model-management CLI as getModels.sh.
  - faster_whisper.available_models() registry listing.
  - faster_whisper.download_model() explicit download.
  - --exec --list.
  - --exec --download --model <NAME>.
  - --simulate.
  - --prerequis.
  - --changelog.
  - --models-dir.
  - Repository-local models/<model-name>/ storage.
  - Existing-model detection.
  - No-argument help behavior.
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
    control.add_argument("--help", "-h", action="store_true")
    control.add_argument("--exec", "-exe", action="store_true")
    control.add_argument("--simulate", "-s", action="store_true")
    control.add_argument("--prerequis", "-pr", action="store_true")
    control.add_argument("--changelog", "-ch", action="store_true")

    actions = parser.add_argument_group("MODEL ACTIONS")
    actions.add_argument("--list", action="store_true")
    actions.add_argument("--download", action="store_true")
    actions.add_argument("--model", metavar="NAME")

    options = parser.add_argument_group("MODEL OPTIONS")
    options.add_argument(
        "--models-dir",
        metavar="PATH",
        default=str(default_models_dir()),
    )

    parser.epilog = """EXAMPLES
  ./getModels.py --prerequis
  ./getModels.py --exec --list
  ./getModels.py --simulate --download --model tiny
  ./getModels.py --exec --download --model tiny
  ./getModels.py --exec --download --model medium
  ./getModels.py --exec --download --model large-v3
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
    return (
        path.is_dir()
        and (path / "config.json").is_file()
        and (path / "model.bin").is_file()
    )


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
    print("-" * 60)
    print(f"PRESENT : Python             : {sys.version.split()[0]}")

    if sys.version_info < (3, 9):
        print("MISSING : Python >= 3.9      : required")
        ok = False
    else:
        print("PRESENT : Python >= 3.9      : compatible")

    for package in ("faster-whisper", "huggingface-hub", "ctranslate2"):
        version = package_version(package)
        if version == "MISSING":
            print(f"MISSING : {package:<18} : required")
            ok = False
        else:
            print(f"PRESENT : {package:<18} : {version}")

    print(f"INFO    : models directory   : {models_dir}")
    print(f"INFO    : free space         : {free_space_mib(models_dir)} MiB")
    print(f"INFO    : Git ignore         : {git_ignore_state(models_dir)}")

    if package_version("faster-whisper") != "MISSING":
        available_models, _ = load_faster_whisper_api()
        models = list(available_models())
        print(f"PRESENT : model registry     : {len(models)} model names")

    print("-" * 60)
    print("RESULT  : " + ("OK" if ok else "ERROR"))
    return 0 if ok else 2


def validate_business_action(
    args: argparse.Namespace,
    parser: argparse.ArgumentParser,
) -> None:
    if int(args.exec) + int(args.simulate) != 1:
        parser.error("Use exactly one execution gate: --exec or --simulate.")

    if int(args.list) + int(args.download) != 1:
        parser.error("Use exactly one model action: --list or --download.")

    if args.download and not args.model:
        parser.error("--download requires --model <NAME>.")

    if args.list and args.model:
        parser.error("--model is only valid with --download.")


def list_models(models_dir: Path) -> int:
    available_models, _ = load_faster_whisper_api()
    models = list(available_models())

    print("AVAILABLE FASTER-WHISPER MODELS")
    print("-" * 72)

    for index, model_name in enumerate(models, start=1):
        target = model_target(models_dir, model_name)
        status = "INSTALLED" if model_complete(target) else "not installed"
        print(f"{index:2d}. {model_name:<28} {status}")

    print("-" * 72)
    print(f"Total            : {len(models)}")
    print(f"Models directory : {models_dir}")
    return 0


def download_model_action(
    model_name: str,
    models_dir: Path,
    simulate: bool,
) -> int:
    available_models, download_model = load_faster_whisper_api()
    models = list(available_models())

    if model_name not in models:
        print(f"ERROR: unknown model '{model_name}'.", file=sys.stderr)
        print("Use ./getModels.sh --exec --list.", file=sys.stderr)
        return 2

    target = model_target(models_dir, model_name)

    print("MODEL DOWNLOAD")
    print("-" * 60)
    print(f"Model       : {model_name}")
    print(f"Models dir  : {models_dir}")
    print(f"Target      : {target}")
    print(f"Free space  : {free_space_mib(models_dir)} MiB")

    if model_complete(target):
        print("Status      : already downloaded")
        print("RESULT      : OK")
        return 0

    if simulate:
        print("Mode        : SIMULATE")
        print("Action      : no download performed")
        print("RESULT      : OK")
        return 0

    models_dir.mkdir(parents=True, exist_ok=True)

    print("Mode        : EXEC")
    print("Source      : Hugging Face Hub")
    print("Action      : downloading Faster-Whisper CTranslate2 model")
    print("Please wait : download progress may be quiet for some files.")

    try:
        downloaded_path = Path(
            download_model(
                model_name,
                output_dir=str(target),
            )
        )
    except Exception as exc:
        print(f"ERROR: model download failed: {exc}", file=sys.stderr)
        return 1

    if not model_complete(downloaded_path):
        print(
            f"ERROR: download completed but the model looks incomplete: {downloaded_path}",
            file=sys.stderr,
        )
        return 1

    size_bytes = sum(
        item.stat().st_size
        for item in downloaded_path.rglob("*")
        if item.is_file()
    )

    print(f"Downloaded  : {downloaded_path}")
    print(f"Size        : {size_bytes / (1024 ** 2):.1f} MiB")
    print("RESULT      : OK")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    argv = sys.argv[1:] if argv is None else argv

    if not argv:
        print_help(parser)
        return 0

    args = parser.parse_args(argv)

    if args.help:
        print_help(parser)
        return 0

    if args.changelog:
        print(CHANGELOG.rstrip())
        return 0

    models_dir = Path(args.models_dir).expanduser()

    if models_dir.is_absolute():
        models_dir = models_dir.resolve(strict=False)
    else:
        models_dir = (Path.cwd() / models_dir).resolve(strict=False)

    if args.prerequis:
        if any((args.exec, args.simulate, args.list, args.download, args.model)):
            parser.error("--prerequis is a standalone control action.")
        return run_prerequisites(models_dir)

    validate_business_action(args, parser)

    if args.list:
        return list_models(models_dir)

    return download_model_action(
        model_name=args.model,
        models_dir=models_dir,
        simulate=args.simulate,
    )


if __name__ == "__main__":
    raise SystemExit(main())
