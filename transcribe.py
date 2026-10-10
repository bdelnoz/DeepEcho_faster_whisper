#!/usr/bin/env python3
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : transcribe.py
# Full Path       : ./transcribe.py
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V2.0.0
# Date / Time     : 2026-10-10 04:20 CEST
# Target usage    : Faster-Whisper transcription backend
#
# CHANGELOG
# V2.0.0 - 2026-10-10 04:20 CEST - Bruno DELNOZ
#   - MAJOR RELEASE: version metadata synchronized at V2.0.0.
#   - Preserved V1.1.4-dev behavior; no new runtime features.
# V1.1.4-dev - 2026-10-10 04:00 CEST - Bruno DELNOZ
#   - Added --recursive discovery of MP4 files under current/--source-dir.
#   - Unquoted --source *.mp4 now includes nested MP4 files in recursive mode.
#   - Non-recursive file/glob selection is unchanged; no media staging.
# V1.1.2-dev - 2026-10-09 22:08 CEST - Bruno DELNOZ
#   - Model is shown last in transcription help/examples for fast model swapping.
#   - Normal runtime logs now start with the exact executed command/argv.
#   - Transcript output filenames now include the selected model before the run timestamp.
#   - Added a per-source Processing-Time Markdown benchmark report under .logs/.
#   - Processing-Time reports use one invariant comparison template across all models.
# V1.1.0-dev - 2026-10-09 18:32 CEST - Bruno DELNOZ
#   - Validation candidate; not a release tag.
#   - Added a single run timestamp in YYYYMMDD-HHMM-SS format.
#   - Timestamped Markdown stays beside each source media file.
#   - Plain Markdown and TXT now go to source-local .transcription/ by default.
#   - Runtime logs now go to source-local .logs/ directories.
#   - Multi-directory batches create one run log in every involved source dir.
#   - All generated transcript/log filenames include the same run timestamp.
#   - Automatic timestamp collision avoidance prevents normal overwrites.
#   - Preserved filenames containing spaces and quoted/unquoted glob support.
#   - Preserved PyAV 19+ / Faster-Whisper 1.2.1 metadata_errors workaround.
#   - Preserved French default, CPU/int8 defaults, VAD OFF and explicit audio
#     preprocessing behavior.
# V1.0.1 - 2026-10-09 17:40 - Bruno DELNOZ
#   - Fixed unquoted shell-expanded globs and filenames containing spaces.
#   - Added PyAV 19+ compatibility for Faster-Whisper 1.2.1.
# V1.0.0 - 2026-10-09 16:45 - Bruno DELNOZ
#   - Initial Faster-Whisper transcription backend.
################################################################################

from __future__ import annotations

import argparse
import glob
import importlib.metadata
import logging
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable, Sequence

VERSION = "V2.0.0"
DATE_TIME = "2026-10-10 04:20 CEST"
AUTHOR = "Bruno DELNOZ"
EMAIL = "bruno.delnoz@protonmail.com"

DEFAULT_LANGUAGE = "fr"
DEFAULT_DEVICE = "cpu"
DEFAULT_COMPUTE_TYPE = "int8"

SUPPORTED_MEDIA_EXTENSIONS = {
    ".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm",
    ".m4v", ".3gp", ".ogv", ".ts", ".mts", ".m2ts",
    ".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg", ".opus",
}

CHANGELOG = f"""transcribe.py CHANGELOG

V2.0.0 - 2026-10-10 04:20 CEST - {AUTHOR}
  - MAJOR RELEASE: V2.0.0 synchronized; recursive and other behavior preserved.

V1.1.4-dev - 2026-10-10 04:00 CEST - {AUTHOR}
  ADDED:
  - --recursive recursively discovers MP4 sources under --source-dir (default: current working directory).
  - --source *.mp4 works whether the shell expands the glob or not.
  - One combined sequential run; source-local outputs/logs remain unchanged.
  - Non-recursive source resolution and all processing/output behavior remain unchanged.

{VERSION} - {DATE_TIME} - {AUTHOR}
  ADDED/CHANGED:
  - Model is displayed last in help/examples.
  - Runtime log first record is the exact executed command/argv.
  - Transcript filenames include the selected model before the run timestamp.
  - Added one source-local .logs/<source>-Processing-Time-<model>-<stamp>.md report per source.
  - Processing-Time reports use an invariant field/header order across models.
  - Timing report records model load, preprocessing, transcription/output, total source processing, media duration, real-time factor and processing speed.

V1.1.0-dev - 2026-10-09 18:32 CEST - {AUTHOR}
  ADDED/CHANGED:
  - Validation candidate; not a release tag.
  - One run timestamp: YYYYMMDD-HHMM-SS.
  - Timestamped Markdown remains beside each source file.
  - Plain Markdown/TXT default to <source>/.transcription/.
  - Runtime logs default to <source>/.logs/.
  - Multi-directory batches receive a log in each involved source directory.
  - Every generated transcript/log file uses the same run timestamp.
  - Timestamp collision avoidance prevents normal overwrites.
  - --dest-dir overrides the base for plain Markdown/TXT only; timestamped
    Markdown and runtime logs remain source-local.
  - Preserved glob/space handling and PyAV 19 compatibility workaround.

V1.0.1 - 2026-10-09 17:40 - {AUTHOR}
  FIXED:
  - Unquoted shell-expanded globs after --source.
  - Filenames containing spaces.
  - PyAV 19 metadata_errors incompatibility with Faster-Whisper 1.2.1.

V1.0.0 - 2026-10-09 16:45 - {AUTHOR}
  ADDED:
  - Initial transcription backend, French default, CPU/int8, local models,
    raw transcription, timestamps, VAD controls, normalize/amplify controls.
"""


@dataclass(frozen=True)
class OutputPaths:
    timestamp_md: Path
    plain_md: Path
    plain_txt: Path
    processing_report_md: Path


def script_dir() -> Path:
    return Path(__file__).resolve().parent


def default_models_dir() -> Path:
    return script_dir() / "models"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="transcribe.py",
        add_help=False,
        formatter_class=argparse.RawTextHelpFormatter,
        description=(
            "DeepEcho Faster-Whisper transcription backend.\n"
            "Normal user entry point: ./transcribe.sh"
        ),
    )

    control = parser.add_argument_group("SOLO CONTROL OPTIONS")
    control.add_argument("--help", "-h", action="store_true",
                         help="Display help and perform no action.")
    control.add_argument("--exec", "-exe", action="store_true",
                         help="Execute transcription.")
    control.add_argument("--simulate", "-s", action="store_true",
                         help="Resolve/validate the job without writing files.")
    control.add_argument("--prerequis", "-pr", action="store_true",
                         help="Check prerequisites only.")
    control.add_argument("--changelog", "-ch", action="store_true",
                         help="Display the complete script changelog.")

    source = parser.add_argument_group("SOURCE / DESTINATION")
    source.add_argument(
        "--source",
        action="append",
        nargs="+",
        metavar="FILE_OR_GLOB",
        help=(
            "One or more source files or glob patterns. Repeatable.\n"
            "Supports quoted globs and shell-expanded unquoted globs.\n"
            "Default for exec/simulate: *.mp4"
        ),
    )
    source.add_argument(
        "--source-dir",
        default=".",
        metavar="PATH",
        help="Base directory used for relative source patterns. Default: .",
    )
    source.add_argument(
        "--dest-dir",
        default=None,
        metavar="PATH",
        help=(
            "Override base directory for plain Markdown/TXT outputs.\n"
            "They are placed in <dest-dir>/.transcription/.\n"
            "Default: <source-dir-of-each-file>/.transcription/.\n"
            "Timestamped Markdown and logs always remain source-local."
        ),
    )

    runtime = parser.add_argument_group("RUNTIME")
    runtime.add_argument("--models-dir", default=str(default_models_dir()), metavar="PATH",
                         help="Models directory. Default: <repo>/models")
    runtime.add_argument("--language", default=DEFAULT_LANGUAGE, metavar="LANG",
                         help="Transcription language. Default: fr. Use auto for detection.")
    runtime.add_argument("--device", default=DEFAULT_DEVICE, metavar="DEVICE",
                         help="CTranslate2 device. Default: cpu.")
    runtime.add_argument("--compute-type", default=DEFAULT_COMPUTE_TYPE, metavar="TYPE",
                         help="CTranslate2 compute type. Default: int8.")

    audio = parser.add_argument_group("AUDIO PROCESSING")
    vad = audio.add_mutually_exclusive_group()
    vad.add_argument("--vad", dest="vad", action="store_true",
                     help="Enable Silero VAD. Default: disabled.")
    vad.add_argument("--no-vad", dest="vad", action="store_false",
                     help="Explicitly disable VAD.")
    parser.set_defaults(vad=False)
    audio.add_argument("--normalize", action="store_true",
                       help="Normalize a temporary audio copy with FFmpeg loudnorm.")
    amp = audio.add_mutually_exclusive_group()
    amp.add_argument("--amplify", type=float, metavar="FACTOR",
                     help="Multiply temporary audio volume, e.g. --amplify 2.")
    amp.add_argument("--amplify-db", type=float, metavar="DB",
                     help="Change temporary audio volume in dB, e.g. --amplify-db 6.")

    outputs = parser.add_argument_group("OUTPUT")
    timestamps = outputs.add_mutually_exclusive_group()
    timestamps.add_argument("--timestamp", dest="timestamps", action="store_true",
                            help="Generate timestamped Markdown. Default: enabled.")
    timestamps.add_argument("--no-timestamp", dest="timestamps", action="store_false",
                            help="Do not generate timestamped Markdown.")
    parser.set_defaults(timestamps=True)
    outputs.add_argument("--force", action="store_true",
                         help="Allow replacement only if an exact timestamped target already exists.")

    recursive_group = parser.add_argument_group("RECURSIVE DISCOVERY")
    recursive_group.add_argument(
        "--recursive", "--recursif", "--récursif", "--récursive",
        action="store_true",
        help=(
            "Find all .mp4 files under --source-dir (default: current directory),\n"
            "including subdirectories, in one sequential transcription run.\n"
            "When enabled, --source values are not used to restrict which MP4s are found.\n"
            "Without this flag the original file/glob selection is unchanged."
        ),
    )

    model_group = parser.add_argument_group("MODEL (LAST)")
    model_group.add_argument("--model", metavar="NAME",
                             help="Downloaded local model name; required for exec/simulate. Kept last in help/examples for fast model swapping.")

    parser.epilog = """OUTPUT LAYOUT (DEFAULT)
  source-dir/
  ├── source.mp4
  ├── source.mp4.transcription_timestamps-MODEL-YYYYMMDD-HHMM-SS.md
  ├── .transcription/
  │   ├── source.mp4.transcription-MODEL-YYYYMMDD-HHMM-SS.md
  │   └── source.mp4.transcript-MODEL-YYYYMMDD-HHMM-SS.txt
  └── .logs/
      ├── transcribe-VERSION-YYYYMMDD-HHMM-SS.log
      └── source.mp4-Processing-Time-MODEL-YYYYMMDD-HHMM-SS.md

EXAMPLES
  ./transcribe.py --prerequis
  ./transcribe.py --simulate --source video.mp4 --model tiny
  ./transcribe.py --exec --source video.mp4 --model tiny
  ./transcribe.py --exec --source '*.mp4' --model tiny
  ./transcribe.py --exec --source video1.mp4 'video 2.mp4' --model tiny
  ./transcribe.py --exec --source *.mp4 --recursive --model large-v3
  ./transcribe.py --simulate --source '*.mp4' --recursive --model tiny
  ./transcribe.py --exec --source-dir /media/videos --recursive --model medium
  ./transcribe.py --exec --source-dir /media/videos --model tiny
  ./transcribe.py --exec --source video.mp4 --dest-dir /media/results --model tiny
  ./transcribe.py --exec --source video.mp4 --amplify 2 --model tiny
  ./transcribe.py --exec --source video.mp4 --amplify-db 6 --model tiny
  ./transcribe.py --exec --source video.mp4 --normalize --model tiny
  ./transcribe.py --exec --source video.mp4 --vad --model tiny

IMPORTANT
  - French is already the default language.
  - VAD, normalization and amplification are OFF unless explicitly requested.
  - Source media is never modified.
  - Missing models are never downloaded automatically.
  - Raw model text is preserved; no editorial rewriting or censorship.
  - Processing-Time reports have an invariant structure for side-by-side model comparison.
  - --recursive discovers every MP4 under --source-dir (default: cwd), without following directory symlinks.
  - Speaker diarization is not implemented; no fake speaker labels are generated.
  - SRT, WebVTT and JSON are not generated in this validation build.
"""
    return parser


def print_help(parser: argparse.ArgumentParser) -> None:
    print(f"transcribe.py {VERSION}")
    print(f"Author: {AUTHOR} <{EMAIL}>")
    print()
    parser.print_help()


def package_version(name: str) -> str:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return "MISSING"


def resolve_path(value: str, base: Path | None = None) -> Path:
    path = Path(value).expanduser()
    if path.is_absolute():
        return path.resolve(strict=False)
    anchor = Path.cwd() if base is None else base
    return (anchor / path).resolve(strict=False)


def model_path(models_dir: Path, model_name: str) -> Path:
    return models_dir / model_name.replace("/", "__")


def model_complete(path: Path) -> bool:
    return (
        path.is_dir()
        and (path / "config.json").is_file()
        and (path / "model.bin").is_file()
    )


def pyav_major_version() -> int | None:
    try:
        import av
        raw = str(getattr(av, "__version__", "")).split(".", 1)[0]
        return int(raw)
    except (ImportError, TypeError, ValueError):
        return None


def install_pyav_compatibility() -> bool:
    """Enable Faster-Whisper 1.2.1 / PyAV 19+ metadata_errors compatibility."""
    try:
        import av
        import faster_whisper.audio as fw_audio
    except Exception:
        return False

    major = pyav_major_version()
    if major is None or major < 19:
        return False

    current_open = av.open
    if getattr(current_open, "_deepecho_pyav19_compat", False):
        return True

    original_open = current_open

    def compatible_open(*args, **kwargs):
        kwargs.pop("metadata_errors", None)
        return original_open(*args, **kwargs)

    compatible_open._deepecho_pyav19_compat = True
    av.open = compatible_open
    fw_audio.av.open = compatible_open
    return True


def ffmpeg_required(args: argparse.Namespace) -> bool:
    return bool(args.normalize or args.amplify is not None or args.amplify_db is not None)


def validate_numeric_options(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    if args.amplify is not None and args.amplify <= 0:
        parser.error("--amplify requires a positive factor greater than 0.")


def validate_control(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    if args.help or args.changelog:
        return
    if args.prerequis:
        if args.exec or args.simulate:
            parser.error("--prerequis is a standalone control action.")
        return
    if int(args.exec) + int(args.simulate) != 1:
        parser.error("Use exactly one execution gate: --exec or --simulate.")
    if not args.model:
        parser.error("--exec/--simulate requires --model <NAME>.")


def run_prerequisites(args: argparse.Namespace) -> int:
    ok = True
    models_dir = resolve_path(args.models_dir)
    print("PREREQUISITES")
    print("-" * 76)
    print(f"PRESENT : Python               : {sys.version.split()[0]}")
    if sys.version_info < (3, 9):
        print("MISSING : Python >= 3.9        : required")
        ok = False
    else:
        print("PRESENT : Python >= 3.9        : compatible")

    for package in ("faster-whisper", "ctranslate2", "av"):
        version = package_version(package)
        if version == "MISSING":
            print(f"MISSING : {package:<20} : required")
            ok = False
        else:
            print(f"PRESENT : {package:<20} : {version}")

    pyav_major = pyav_major_version()
    if pyav_major is not None and pyav_major >= 19:
        print("COMPAT  : PyAV >= 19           : metadata_errors workaround active at runtime")
    elif pyav_major is not None:
        print("INFO    : PyAV compatibility   : native Faster-Whisper path")
    else:
        print("NOTICE  : PyAV compatibility   : version could not be determined")

    if shutil.which("ffmpeg"):
        print(f"PRESENT : ffmpeg               : {shutil.which('ffmpeg')}")
    else:
        print("OPTIONAL: ffmpeg               : needed only for normalize/amplify")

    print(f"INFO    : models directory     : {models_dir}")
    if models_dir.exists():
        installed = sorted(p.name for p in models_dir.iterdir() if p.is_dir() and model_complete(p))
        print("PRESENT : local models         : " + (", ".join(installed) if installed else "none detected"))
    else:
        print("NOTICE  : local models         : models directory does not exist")

    cwd_usage = shutil.disk_usage(Path.cwd())
    print(f"INFO    : free space on .      : {cwd_usage.free // (1024 * 1024)} MiB")
    print("-" * 76)
    print("RESULT  : " + ("OK" if ok else "ERROR"))
    return 0 if ok else 2


def flatten_source_specs(source_specs: Sequence[Sequence[str]] | None) -> list[str]:
    if not source_specs:
        return ["*.mp4"]
    flattened: list[str] = []
    for group in source_specs:
        flattened.extend(group)
    return flattened


def resolve_sources(source_dir: Path, source_specs: Sequence[Sequence[str]] | None) -> list[Path]:
    specs = flatten_source_specs(source_specs)
    result: list[Path] = []
    seen: set[str] = set()

    for spec in specs:
        expanded = os.path.expanduser(spec)
        candidate = Path(expanded)
        pattern = str(candidate) if candidate.is_absolute() else str(source_dir / expanded)
        has_glob = any(char in expanded for char in "*?[")
        matches = [Path(p) for p in glob.glob(pattern, recursive=True)] if has_glob else [Path(pattern)]

        for match in sorted(matches, key=lambda p: str(p).lower()):
            try:
                resolved = match.resolve(strict=True)
            except FileNotFoundError:
                continue
            if not resolved.is_file():
                continue
            if resolved.suffix.lower() not in SUPPORTED_MEDIA_EXTENSIONS:
                continue
            key = str(resolved)
            if key not in seen:
                seen.add(key)
                result.append(resolved)
    return result



def resolve_recursive_mp4_sources(source_dir: Path) -> list[Path]:
    """Scan source_dir recursively for .mp4 files, without following directory symlinks.

    Intentional semantics: in recursive mode --source is not a filename filter.
    This also handles --source *.mp4 expanded by the caller's shell.
    No media files are read or copied during discovery.
    """
    result: list[Path] = []
    seen: set[str] = set()

    def on_walk_error(error: OSError) -> None:
        raise error  # Never silently omit an unreadable subtree.

    for directory, dirs, files in os.walk(source_dir, topdown=True, followlinks=False, onerror=on_walk_error):
        dirs[:] = sorted((name for name in dirs if not (Path(directory) / name).is_symlink()), key=str.casefold)
        for filename in sorted(files, key=str.casefold):
            if Path(filename).suffix.lower() != ".mp4":
                continue
            candidate = Path(directory) / filename
            # Reject symlinks, including those which escape the scan root.
            if candidate.is_symlink():
                continue
            resolved = candidate.resolve(strict=True)
            if not resolved.is_file():
                continue
            key = str(resolved)
            if key not in seen:
                seen.add(key)
                result.append(resolved)
    return result


def format_run_stamp(dt: datetime) -> str:
    return dt.strftime("%Y%m%d-%H%M-%S")


def output_paths(source: Path, dest_dir: Path | None, run_stamp: str, model_name: str) -> OutputPaths:
    base = source.name
    transcript_base = source.parent if dest_dir is None else dest_dir
    transcript_dir = transcript_base / ".transcription"
    logs_dir = source.parent / ".logs"
    return OutputPaths(
        timestamp_md=source.parent / f"{base}.transcription_timestamps-{model_name}-{run_stamp}.md",
        plain_md=transcript_dir / f"{base}.transcription-{model_name}-{run_stamp}.md",
        plain_txt=transcript_dir / f"{base}.transcript-{model_name}-{run_stamp}.txt",
        processing_report_md=logs_dir / f"{base}-Processing-Time-{model_name}-{run_stamp}.md",
    )


def log_paths_for_sources(sources: Sequence[Path], run_stamp: str) -> list[Path]:
    unique_dirs = sorted({source.parent for source in sources}, key=lambda p: str(p).lower())
    return [
        directory / ".logs" / f"transcribe-{VERSION}-{run_stamp}.log"
        for directory in unique_dirs
    ]


def candidate_paths(
    sources: Sequence[Path],
    dest_dir: Path | None,
    run_stamp: str,
    timestamps: bool,
    model_name: str,
) -> list[Path]:
    paths: list[Path] = []
    for source in sources:
        out = output_paths(source, dest_dir, run_stamp, model_name)
        paths.extend([out.plain_md, out.plain_txt, out.processing_report_md])
        if timestamps:
            paths.append(out.timestamp_md)
    paths.extend(log_paths_for_sources(sources, run_stamp))
    return paths


def choose_run_stamp(
    sources: Sequence[Path],
    dest_dir: Path | None,
    timestamps: bool,
    force: bool,
    model_name: str,
) -> str:
    now = datetime.now()
    if force:
        return format_run_stamp(now)
    for offset in range(0, 120):
        stamp = format_run_stamp(now + timedelta(seconds=offset))
        if not any(path.exists() for path in candidate_paths(sources, dest_dir, stamp, timestamps, model_name)):
            return stamp
    raise RuntimeError("Unable to allocate a unique timestamped output set within 120 seconds.")


def validate_output_collisions(
    sources: Sequence[Path],
    dest_dir: Path | None,
    run_stamp: str,
    timestamps: bool,
    force: bool,
    model_name: str,
) -> None:
    generated: list[Path] = []
    for source in sources:
        out = output_paths(source, dest_dir, run_stamp, model_name)
        generated.extend([out.plain_md, out.plain_txt, out.processing_report_md])
        if timestamps:
            generated.append(out.timestamp_md)

    duplicates: dict[Path, int] = {}
    for p in generated:
        duplicates[p] = duplicates.get(p, 0) + 1
    duplicate_targets = [p for p, count in duplicates.items() if count > 1]
    if duplicate_targets:
        formatted = "\n".join(f"  - {p}" for p in duplicate_targets)
        raise RuntimeError(
            "Multiple sources resolve to the same output target. "
            "Use separate destination directories or distinct source names:\n" + formatted
        )

    existing = [p for p in generated if p.exists()]
    if existing and not force:
        formatted = "\n".join(f"  - {p}" for p in existing)
        raise RuntimeError("Timestamped output target(s) already exist:\n" + formatted)


def format_timestamp(seconds: float) -> str:
    if seconds < 0:
        seconds = 0
    milliseconds = int(round(seconds * 1000))
    hours, milliseconds = divmod(milliseconds, 3_600_000)
    minutes, milliseconds = divmod(milliseconds, 60_000)
    secs, milliseconds = divmod(milliseconds, 1_000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{milliseconds:03d}"


def build_audio_filter(args: argparse.Namespace) -> str | None:
    filters: list[str] = []
    if args.normalize:
        filters.append("loudnorm")
    if args.amplify is not None:
        filters.append(f"volume={args.amplify}")
    if args.amplify_db is not None:
        filters.append(f"volume={args.amplify_db}dB")
    return ",".join(filters) if filters else None


def preprocess_audio(source: Path, args: argparse.Namespace, temp_dir: Path) -> Path:
    audio_filter = build_audio_filter(args)
    if audio_filter is None:
        return source
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("FFmpeg is required for normalize/amplify but was not found.")

    target = temp_dir / f"{source.name}.deepecho.wav"
    command = [
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(source), "-vn", "-af", audio_filter,
        "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", str(target),
    ]
    subprocess.run(command, check=True)
    if not target.is_file() or target.stat().st_size == 0:
        raise RuntimeError("FFmpeg preprocessing did not produce a valid temporary audio file.")
    return target


def load_model(args: argparse.Namespace):
    compat_active = install_pyav_compatibility()
    try:
        from faster_whisper import WhisperModel
    except Exception as exc:
        raise RuntimeError(
            f"Unable to import faster_whisper. Run ./install.sh --install first. Details: {exc}"
        ) from exc

    models_dir = resolve_path(args.models_dir)
    selected = model_path(models_dir, args.model)
    if not model_complete(selected):
        raise RuntimeError(
            f"Model '{args.model}' is not installed at {selected}. "
            f"Download it first with ./getModels.sh --exec --download --model {args.model}"
        )

    model = WhisperModel(str(selected), device=args.device, compute_type=args.compute_type)
    return model, selected, compat_active


def write_outputs(
    source: Path,
    paths: OutputPaths,
    segments: Iterable,
    timestamps: bool,
) -> tuple[int, float]:
    paths.plain_md.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    last_end = 0.0
    plain_chunks: list[str] = []
    timestamp_lines: list[str] = []

    for segment in segments:
        text = str(segment.text).strip()
        if not text:
            continue
        count += 1
        start = float(segment.start)
        end = float(segment.end)
        last_end = max(last_end, end)
        plain_chunks.append(text)
        timestamp_lines.append(f"[{format_timestamp(start)} --> {format_timestamp(end)}] {text}")

    plain_text = "\n".join(plain_chunks).rstrip() + ("\n" if plain_chunks else "")
    paths.plain_txt.write_text(plain_text, encoding="utf-8", newline="\n")
    paths.plain_md.write_text(plain_text, encoding="utf-8", newline="\n")

    if timestamps:
        timestamp_text = "\n".join(timestamp_lines).rstrip()
        if timestamp_text:
            timestamp_text += "\n"
        paths.timestamp_md.write_text(timestamp_text, encoding="utf-8", newline="\n")
    return count, last_end


def format_wall_clock(dt: datetime | None) -> str:
    if dt is None:
        return "N/A"
    local = dt.astimezone()
    return local.strftime("%Y-%m-%d %H:%M:%S.") + f"{local.microsecond // 1000:03d} " + (local.tzname() or "")


def format_seconds(value: float | None) -> str:
    return "N/A" if value is None else f"{value:.3f}"


def one_line(value: object | None) -> str:
    if value is None:
        return "N/A"
    text = str(value).replace("\r", " ").replace("\n", " ").replace("|", "\\|").strip()
    return text if text else "N/A"


def executed_command(argv: Sequence[str]) -> str:
    forwarded = os.environ.get("DEEPECHO_ORIGINAL_COMMAND")
    if forwarded:
        return forwarded
    return shlex.join([sys.argv[0], *argv])


def write_processing_report(
    path: Path,
    *,
    source: Path,
    args: argparse.Namespace,
    run_stamp: str,
    status: str,
    detected_language: str | None,
    media_duration: float | None,
    model_load_seconds: float | None,
    processing_started: datetime | None,
    processing_finished: datetime | None,
    preprocessing_seconds: float | None,
    transcription_seconds: float | None,
    total_source_seconds: float | None,
    segment_count: int | None,
    transcript_end: float | None,
    error: str | None,
) -> None:
    """Write the invariant benchmark template used for every model/source."""
    path.parent.mkdir(parents=True, exist_ok=True)
    rtf = None
    speed = None
    if media_duration is not None and media_duration > 0 and transcription_seconds is not None:
        rtf = transcription_seconds / media_duration
        if transcription_seconds > 0:
            speed = media_duration / transcription_seconds

    amplify_factor = "OFF" if args.amplify is None else str(args.amplify)
    amplify_db = "OFF" if args.amplify_db is None else str(args.amplify_db)
    rows = [
        "# DeepEcho Processing Time Report",
        "",
        "This file uses the same fixed structure for every model so reports can be compared side by side.",
        "",
        "## 1. Identification",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Source file | `{one_line(source.name)}` |",
        f"| Source path | `{one_line(source)}` |",
        f"| Model | `{one_line(args.model)}` |",
        f"| Run timestamp | `{run_stamp}` |",
        f"| Status | `{one_line(status)}` |",
        "",
        "## 2. Transcription Configuration",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Requested language | `{one_line(args.language)}` |",
        f"| Detected language | `{one_line(detected_language)}` |",
        f"| Device | `{one_line(args.device)}` |",
        f"| Compute type | `{one_line(args.compute_type)}` |",
        f"| VAD | `{'ON' if args.vad else 'OFF'}` |",
        f"| Normalize | `{'ON' if args.normalize else 'OFF'}` |",
        f"| Amplify factor | `{amplify_factor}` |",
        f"| Amplify dB | `{amplify_db}` |",
        f"| Timestamped Markdown | `{'ON' if args.timestamps else 'OFF'}` |",
        "",
        "## 3. Timing",
        "",
        "| Field | Value |",
        "| --- | ---: |",
        f"| Media duration (s) | {format_seconds(media_duration)} |",
        f"| Model load time (s) | {format_seconds(model_load_seconds)} |",
        f"| Processing start | {format_wall_clock(processing_started)} |",
        f"| Processing end | {format_wall_clock(processing_finished)} |",
        f"| Preprocessing time (s) | {format_seconds(preprocessing_seconds)} |",
        f"| Transcription + output processing time (s) | {format_seconds(transcription_seconds)} |",
        f"| Total source processing time (s) | {format_seconds(total_source_seconds)} |",
        f"| Real-time factor (processing / media) | {'N/A' if rtf is None else f'{rtf:.4f} x'} |",
        f"| Processing speed (media / processing) | {'N/A' if speed is None else f'{speed:.4f} x realtime'} |",
        "",
        "## 4. Result",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Segments | {'N/A' if segment_count is None else segment_count} |",
        f"| Transcript end (s) | {format_seconds(transcript_end)} |",
        f"| Error | {one_line(error)} |",
        "",
        "## 5. Comparison Notes",
        "",
        "- Lower real-time factor is faster.",
        "- Higher processing-speed value is faster.",
        "- Headers, field order, units and table structure are invariant across models; only values change.",
        "",
    ]
    path.write_text("\n".join(rows), encoding="utf-8", newline="\n")


def setup_logger(sources: Sequence[Path], run_stamp: str) -> tuple[logging.Logger, list[Path]]:
    log_paths = log_paths_for_sources(sources, run_stamp)
    logger = logging.getLogger("deepecho")
    logger.setLevel(logging.INFO)
    logger.propagate = False
    logger.handlers.clear()
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    for log_path in log_paths:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        handler = logging.FileHandler(log_path, encoding="utf-8")
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    return logger, log_paths


def print_plan(
    args: argparse.Namespace,
    sources: Sequence[Path],
    selected_model: Path,
    dest_dir: Path | None,
    run_stamp: str,
) -> None:
    print("TRANSCRIPTION PLAN")
    print("-" * 76)
    print(f"Mode                : {'EXEC' if args.exec else 'SIMULATE'}")
    print(f"Run timestamp       : {run_stamp}")
    print(f"Model               : {args.model}")
    print(f"Model path          : {selected_model}")
    print(f"Language            : {args.language}")
    print(f"Device              : {args.device}")
    print(f"Compute type        : {args.compute_type}")
    print(f"VAD                 : {'ON' if args.vad else 'OFF'}")
    print(f"Normalize           : {'ON' if args.normalize else 'OFF'}")
    print(f"Amplify factor      : {args.amplify if args.amplify is not None else 'OFF'}")
    print(f"Amplify dB          : {args.amplify_db if args.amplify_db is not None else 'OFF'}")
    print(f"Timestamped MD      : {'ON' if args.timestamps else 'OFF'}")
    print(f"Force exact target  : {'YES' if args.force else 'NO'}")
    print(f"Recursive scan      : {'ON' if args.recursive else 'OFF'}")
    print(f"Source count        : {len(sources)}")
    print(f"Plain output base   : {dest_dir if dest_dir is not None else 'each source directory'}")
    print("-" * 76)

    for index, source in enumerate(sources, start=1):
        paths = output_paths(source, dest_dir, run_stamp, args.model)
        print(f"{index}. SOURCE : {source}")
        if args.timestamps:
            print(f"   OUTPUT : {paths.timestamp_md}")
        print(f"   OUTPUT : {paths.plain_md}")
        print(f"   OUTPUT : {paths.plain_txt}")
        print(f"   REPORT : {paths.processing_report_md}")
        print(f"   LOGDIR : {source.parent / '.logs'}")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    argv = sys.argv[1:] if argv is None else argv
    if not argv:
        print_help(parser)
        return 0

    args = parser.parse_args(argv)
    validate_numeric_options(args, parser)

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
    if args.prerequis:
        if any((args.exec, args.simulate, args.model)):
            parser.error("--prerequis is a standalone control action.")
        return run_prerequisites(args)

    validate_control(args, parser)

    source_dir = resolve_path(args.source_dir)
    if not source_dir.is_dir():
        print(f"ERROR: source directory does not exist: {source_dir}", file=sys.stderr)
        return 2

    dest_dir = resolve_path(args.dest_dir) if args.dest_dir is not None else None
    try:
        sources = (
            resolve_recursive_mp4_sources(source_dir)
            if args.recursive else resolve_sources(source_dir, args.source)
        )
    except (OSError, RuntimeError) as exc:
        print(f"ERROR: source discovery failed: {exc}", file=sys.stderr)
        return 2
    if not sources:
        patterns = "recursive *.mp4" if args.recursive else str(flatten_source_specs(args.source))
        print(f"ERROR: no supported media matched {patterns} in {source_dir}", file=sys.stderr)
        return 2

    models_dir = resolve_path(args.models_dir)
    selected_model = model_path(models_dir, args.model)
    if not model_complete(selected_model):
        print(f"ERROR: model '{args.model}' is not installed at {selected_model}", file=sys.stderr)
        print(f"Download it first with: ./getModels.sh --exec --download --model {args.model}", file=sys.stderr)
        return 2

    if ffmpeg_required(args) and shutil.which("ffmpeg") is None:
        print("ERROR: FFmpeg is required for normalize/amplify but was not found.", file=sys.stderr)
        return 2

    try:
        run_stamp = choose_run_stamp(sources, dest_dir, args.timestamps, args.force, args.model)
        validate_output_collisions(sources, dest_dir, run_stamp, args.timestamps, args.force, args.model)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print_plan(args, sources, selected_model, dest_dir, run_stamp)
    if args.simulate:
        print()
        print("SIMULATION RESULT: OK - no directory, log, transcript or source file was modified.")
        return 0

    if dest_dir is not None:
        dest_dir.mkdir(parents=True, exist_ok=True)

    logger, log_paths = setup_logger(sources, run_stamp)
    command_text = executed_command(argv)
    logger.info("COMMAND: %s", command_text)
    logger.info("DeepEcho transcription started")
    logger.info("Version=%s run_stamp=%s model=%s language=%s device=%s compute_type=%s",
                VERSION, run_stamp, args.model, args.language, args.device, args.compute_type)
    logger.info("Sources=%s", [str(p) for p in sources])

    print()
    print("Runtime log(s):")
    for log_path in log_paths:
        print(f"  {log_path}")

    model_load_t0 = time.perf_counter()
    try:
        model, selected_model, pyav_compat_active = load_model(args)
        model_load_seconds = time.perf_counter() - model_load_t0
    except Exception as exc:
        logger.exception("Model load failed")
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if pyav_compat_active:
        print("PyAV compatibility  : ON (PyAV 19+ metadata_errors workaround)")
        logger.info("PyAV 19+ metadata_errors compatibility shim active")

    language = None if str(args.language).lower() == "auto" else args.language
    overall_rc = 0

    for index, source in enumerate(sources, start=1):
        print()
        print(f"[{index}/{len(sources)}] Transcribing: {source}")
        logger.info("Transcribing source=%s", source)
        paths = output_paths(source, dest_dir, run_stamp, args.model)

        source_started_dt = datetime.now().astimezone()
        source_t0 = time.perf_counter()
        source_finished_dt: datetime | None = None
        preprocessing_seconds: float | None = None
        transcription_seconds: float | None = None
        total_source_seconds: float | None = None
        detected_language: str | None = None
        duration: float | None = None
        segment_count: int | None = None
        last_end: float | None = None
        source_status = "ERROR"
        source_error: str | None = None

        try:
            with tempfile.TemporaryDirectory(prefix="deepecho_transcribe_") as temp_name:
                temp_dir = Path(temp_name)
                preprocess_t0 = time.perf_counter()
                audio_source = preprocess_audio(source, args, temp_dir)
                preprocessing_seconds = time.perf_counter() - preprocess_t0

                transcription_t0 = time.perf_counter()
                segments, info = model.transcribe(
                    str(audio_source),
                    language=language,
                    task="transcribe",
                    vad_filter=args.vad,
                    without_timestamps=False,
                    word_timestamps=False,
                    log_progress=True,
                )
                detected_language = getattr(info, "language", None)
                raw_duration = getattr(info, "duration", None)
                duration = float(raw_duration) if raw_duration is not None else None
                segment_count, last_end = write_outputs(
                    source=source,
                    paths=paths,
                    segments=segments,
                    timestamps=args.timestamps,
                )
                transcription_seconds = time.perf_counter() - transcription_t0
                source_status = "OK"

                print(f"Segments            : {segment_count}")
                if detected_language:
                    print(f"Language            : {detected_language}")
                if duration is not None:
                    print(f"Duration            : {duration:.1f} s")
                print(f"Transcript end      : {last_end:.1f} s")
                if args.timestamps:
                    print(f"Created             : {paths.timestamp_md}")
                print(f"Created             : {paths.plain_md}")
                print(f"Created             : {paths.plain_txt}")
                print(f"Performance report  : {paths.processing_report_md}")
                print("RESULT              : OK")

                logger.info(
                    "Completed source=%s segments=%s detected_language=%s duration=%s outputs=%s",
                    source, segment_count, detected_language, duration,
                    [str(paths.timestamp_md), str(paths.plain_md), str(paths.plain_txt)],
                )
        except subprocess.CalledProcessError as exc:
            overall_rc = 1
            source_error = f"FFmpeg preprocessing failed: {exc}"
            logger.exception("FFmpeg preprocessing failed for %s", source)
            print(f"ERROR: FFmpeg preprocessing failed for {source}: {exc}", file=sys.stderr)
        except Exception as exc:
            overall_rc = 1
            source_error = f"Transcription failed: {exc}"
            logger.exception("Transcription failed for %s", source)
            print(f"ERROR: transcription failed for {source}: {exc}", file=sys.stderr)
        finally:
            source_finished_dt = datetime.now().astimezone()
            total_source_seconds = time.perf_counter() - source_t0
            try:
                write_processing_report(
                    paths.processing_report_md,
                    source=source,
                    args=args,
                    run_stamp=run_stamp,
                    status=source_status,
                    detected_language=detected_language,
                    media_duration=duration,
                    model_load_seconds=model_load_seconds,
                    processing_started=source_started_dt,
                    processing_finished=source_finished_dt,
                    preprocessing_seconds=preprocessing_seconds,
                    transcription_seconds=transcription_seconds,
                    total_source_seconds=total_source_seconds,
                    segment_count=segment_count,
                    transcript_end=last_end,
                    error=source_error,
                )
            except Exception as report_exc:
                overall_rc = 1
                logger.exception("Unable to write Processing-Time report for %s", source)
                print(f"ERROR: unable to write Processing-Time report for {source}: {report_exc}", file=sys.stderr)

    logger.info("DeepEcho transcription finished rc=%s", overall_rc)
    print()
    print("TRANSCRIPTION RESULT: " + ("OK" if overall_rc == 0 else "ERROR"))
    print(f"Run timestamp       : {run_stamp}")
    return overall_rc


if __name__ == "__main__":
    raise SystemExit(main())
