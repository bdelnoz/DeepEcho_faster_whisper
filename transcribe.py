#!/usr/bin/env python3
################################################################################
# SCRIPT INFORMATION
################################################################################
# Script Name     : transcribe.py
# Full Path       : ./transcribe.py
# Author          : Bruno DELNOZ
# Email           : bruno.delnoz@protonmail.com
# Version         : V1.0.0
# Date / Time     : 2026-10-09 16:45
# Target usage    : Faster-Whisper transcription backend
#
# CHANGELOG
# V1.0.0 - 2026-10-09 16:45 - Bruno DELNOZ
#   - Initial Faster-Whisper transcription backend.
#   - French transcription language by default.
#   - CPU device and int8 compute type by default.
#   - Explicit local model selection from ./models/<model-name>/.
#   - No automatic model download.
#   - Current working/source directory oriented workflow.
#   - Single-file and glob/pattern batch selection.
#   - Multiple --source arguments supported.
#   - MP4 primary input with additional common media extensions accepted.
#   - Raw transcription without editorial rewriting or censorship.
#   - Segment timestamps enabled by default.
#   - Plain Markdown and plain TXT outputs generated for every source.
#   - Optional timestamped Markdown output can be disabled with --no-timestamp.
#   - VAD disabled by default; opt-in with --vad.
#   - Optional FFmpeg normalization and amplification.
#   - --amplify factor and --amplify-db dB are mutually exclusive.
#   - Original media is never modified.
#   - --simulate resolves sources, model and outputs without transcribing.
#   - --prerequis validates the local runtime without modifying it.
#   - No-argument help behavior.
#   - Output overwrite protection with explicit --force.
#   - Runtime log written to the invocation current working directory.
#   - Speaker diarization deliberately not faked in V1.0.0.
################################################################################

from __future__ import annotations

import argparse
import glob
import importlib.metadata
import logging
import os
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

VERSION = "V1.0.0"
DATE_TIME = "2026-10-09 16:45"
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

CHANGELOG = """transcribe.py CHANGELOG

V1.0.0 - 2026-10-09 16:45 - Bruno DELNOZ
  ADDED:
  - Initial Faster-Whisper transcription backend.
  - French language default.
  - CPU/int8 default runtime.
  - Local model lookup under ./models/<model-name>/.
  - Explicit --model selection; no hidden model download.
  - --source, --source-dir and --dest-dir.
  - Single files, repeated sources and glob patterns.
  - Default source pattern *.mp4 when --source is omitted during exec/simulate.
  - Timestamped Markdown, plain Markdown and TXT outputs.
  - --timestamp / --no-timestamp.
  - --vad / --no-vad with VAD disabled by default.
  - --normalize, --amplify and --amplify-db.
  - --device and --compute-type.
  - --models-dir.
  - --force overwrite control.
  - --exec, --simulate, --prerequis, --help and --changelog.
  - Runtime log in the invocation current working directory.
  - Original media protection.
  - Speaker diarization intentionally deferred rather than faked.
"""


@dataclass(frozen=True)
class OutputPaths:
    timestamp_md: Path
    plain_md: Path
    plain_txt: Path


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
                         help="Execute the transcription.")
    control.add_argument("--simulate", "-s", action="store_true",
                         help="Resolve and validate the job without transcribing.")
    control.add_argument("--prerequis", "-pr", action="store_true",
                         help="Check prerequisites only.")
    control.add_argument("--changelog", "-ch", action="store_true",
                         help="Display the complete script changelog.")

    source = parser.add_argument_group("SOURCE / DESTINATION")
    source.add_argument(
        "--source",
        action="append",
        metavar="FILE_OR_GLOB",
        help=(
            "Source file or glob pattern. Repeatable.\n"
            "Examples: video.mp4, '*.mp4', 'Toto*.mp4'.\n"
            "Default for exec/simulate: *.mp4"
        ),
    )
    source.add_argument(
        "--source-dir",
        default=".",
        metavar="PATH",
        help="Base directory used to resolve relative source patterns. Default: .",
    )
    source.add_argument(
        "--dest-dir",
        default=None,
        metavar="PATH",
        help=(
            "Destination directory for transcripts.\n"
            "Default: source file directory (therefore '.' in the normal workflow)."
        ),
    )

    runtime = parser.add_argument_group("MODEL / RUNTIME")
    runtime.add_argument(
        "--model",
        metavar="NAME",
        help=(
            "Downloaded Faster-Whisper model name under models/<NAME>/.\n"
            "Required for --exec and --simulate."
        ),
    )
    runtime.add_argument(
        "--models-dir",
        default=str(default_models_dir()),
        metavar="PATH",
        help="Models directory. Default: <repo>/models",
    )
    runtime.add_argument(
        "--language",
        default=DEFAULT_LANGUAGE,
        metavar="LANG",
        help="Transcription language code. Default: fr. Use 'auto' for detection.",
    )
    runtime.add_argument(
        "--device",
        default=DEFAULT_DEVICE,
        metavar="DEVICE",
        help="CTranslate2 device. Default: cpu.",
    )
    runtime.add_argument(
        "--compute-type",
        default=DEFAULT_COMPUTE_TYPE,
        metavar="TYPE",
        help="CTranslate2 compute type. Default: int8.",
    )

    audio = parser.add_argument_group("AUDIO PROCESSING")
    vad = audio.add_mutually_exclusive_group()
    vad.add_argument(
        "--vad",
        dest="vad",
        action="store_true",
        help="Enable Silero VAD. Default: disabled.",
    )
    vad.add_argument(
        "--no-vad",
        dest="vad",
        action="store_false",
        help="Disable VAD explicitly. This is the default.",
    )
    parser.set_defaults(vad=False)

    audio.add_argument(
        "--normalize",
        action="store_true",
        help="Normalize a temporary audio copy with FFmpeg loudnorm before transcription.",
    )

    amp = audio.add_mutually_exclusive_group()
    amp.add_argument(
        "--amplify",
        type=float,
        metavar="FACTOR",
        help="Multiply temporary audio volume by FACTOR, e.g. --amplify 2.",
    )
    amp.add_argument(
        "--amplify-db",
        type=float,
        metavar="DB",
        help="Amplify temporary audio by DB decibels, e.g. --amplify-db 6.",
    )

    outputs = parser.add_argument_group("OUTPUT")
    timestamps = outputs.add_mutually_exclusive_group()
    timestamps.add_argument(
        "--timestamp",
        dest="timestamps",
        action="store_true",
        help="Generate timestamped Markdown. Default: enabled.",
    )
    timestamps.add_argument(
        "--no-timestamp",
        dest="timestamps",
        action="store_false",
        help="Do not generate the timestamped Markdown file.",
    )
    parser.set_defaults(timestamps=True)

    outputs.add_argument(
        "--force",
        action="store_true",
        help="Allow replacement of transcript files that already exist.",
    )

    parser.epilog = """OUTPUT NAMING
  source.mp4.transcription_timestamps.md
  source.mp4.transcription.md
  source.mp4.transcript.txt

EXAMPLES
  ./transcribe.py --prerequis
  ./transcribe.py --simulate --model tiny --source video.mp4
  ./transcribe.py --exec --model tiny --source video.mp4
  ./transcribe.py --exec --model tiny --source '*.mp4'
  ./transcribe.py --exec --model tiny --source 'Toto*.mp4'
  ./transcribe.py --exec --model tiny --source-dir /media/videos
  ./transcribe.py --exec --model tiny --source video.mp4 --dest-dir /media/results
  ./transcribe.py --exec --model tiny --source video.mp4 --amplify 2
  ./transcribe.py --exec --model tiny --source video.mp4 --amplify-db 6
  ./transcribe.py --exec --model tiny --source video.mp4 --normalize
  ./transcribe.py --exec --model tiny --source video.mp4 --vad

IMPORTANT
  - French is already the default transcription language.
  - VAD, normalization and amplification are OFF unless explicitly requested.
  - Source media is never modified.
  - Missing models are never downloaded automatically.
  - Speaker diarization is not implemented in V1.0.0; no fake speaker labels are generated.
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
    return path.is_dir() and (path / "config.json").is_file() and (path / "model.bin").is_file()


def ffmpeg_required(args: argparse.Namespace) -> bool:
    return bool(args.normalize or args.amplify is not None or args.amplify_db is not None)


def validate_numeric_options(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    if args.amplify is not None and args.amplify <= 0:
        parser.error("--amplify requires a positive factor greater than 0.")


def validate_control(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    if args.help:
        return
    if args.changelog:
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
    print("-" * 72)
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

    if shutil.which("ffmpeg"):
        print(f"PRESENT : ffmpeg               : {shutil.which('ffmpeg')}")
    else:
        print("OPTIONAL: ffmpeg               : missing; required only for normalize/amplify")

    print(f"INFO    : models directory     : {models_dir}")
    if models_dir.exists():
        installed = sorted(
            p.name for p in models_dir.iterdir()
            if p.is_dir() and model_complete(p)
        )
        if installed:
            print(f"PRESENT : local models         : {', '.join(installed)}")
        else:
            print("NOTICE  : local models         : none detected")
    else:
        print("NOTICE  : local models         : models directory does not exist")

    cwd_usage = shutil.disk_usage(Path.cwd())
    print(f"INFO    : free space on .      : {cwd_usage.free // (1024 * 1024)} MiB")

    print("-" * 72)
    print("RESULT  : " + ("OK" if ok else "ERROR"))
    return 0 if ok else 2


def resolve_sources(source_dir: Path, source_specs: Sequence[str] | None) -> list[Path]:
    specs = list(source_specs or ["*.mp4"])
    result: list[Path] = []
    seen: set[str] = set()

    for spec in specs:
        expanded = os.path.expanduser(spec)

        candidate = Path(expanded)
        if candidate.is_absolute():
            pattern = str(candidate)
        else:
            pattern = str(source_dir / expanded)

        has_glob = any(char in expanded for char in "*?[")

        if has_glob:
            matches = [Path(p) for p in glob.glob(pattern, recursive=True)]
        else:
            matches = [Path(pattern)]

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


def output_paths(source: Path, dest_dir: Path | None) -> OutputPaths:
    target_dir = source.parent if dest_dir is None else dest_dir
    base = source.name
    return OutputPaths(
        timestamp_md=target_dir / f"{base}.transcription_timestamps.md",
        plain_md=target_dir / f"{base}.transcription.md",
        plain_txt=target_dir / f"{base}.transcript.txt",
    )


def ensure_output_available(paths: OutputPaths, timestamps: bool, force: bool) -> None:
    candidates = [paths.plain_md, paths.plain_txt]
    if timestamps:
        candidates.append(paths.timestamp_md)

    existing = [p for p in candidates if p.exists()]
    if existing and not force:
        formatted = "\n".join(f"  - {p}" for p in existing)
        raise RuntimeError(
            "Output file(s) already exist. Use --force to replace them:\n" + formatted
        )


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
        raise RuntimeError(
            "FFmpeg is required for --normalize/--amplify/--amplify-db but was not found."
        )

    target = temp_dir / f"{source.name}.deepecho.wav"

    command = [
        ffmpeg,
        "-hide_banner",
        "-loglevel", "error",
        "-y",
        "-i", str(source),
        "-vn",
        "-af", audio_filter,
        "-ac", "1",
        "-ar", "16000",
        "-c:a", "pcm_s16le",
        str(target),
    ]

    subprocess.run(command, check=True)

    if not target.is_file() or target.stat().st_size == 0:
        raise RuntimeError("FFmpeg preprocessing did not produce a valid temporary audio file.")

    return target


def load_model(args: argparse.Namespace):
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

    return WhisperModel(
        str(selected),
        device=args.device,
        compute_type=args.compute_type,
    ), selected


def write_outputs(
    source: Path,
    paths: OutputPaths,
    segments: Iterable,
    timestamps: bool,
    force: bool,
) -> tuple[int, float]:
    ensure_output_available(paths, timestamps=timestamps, force=force)

    paths.plain_md.parent.mkdir(parents=True, exist_ok=True)

    mode = "w"
    encoding = "utf-8"

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

        # Preserve the model's text. Only surrounding whitespace is removed.
        plain_chunks.append(text)
        timestamp_lines.append(
            f"[{format_timestamp(start)} --> {format_timestamp(end)}] {text}"
        )

    plain_text = "\n".join(plain_chunks).rstrip() + ("\n" if plain_chunks else "")

    paths.plain_txt.write_text(plain_text, encoding=encoding, newline="\n")
    paths.plain_md.write_text(plain_text, encoding=encoding, newline="\n")

    if timestamps:
        timestamp_text = "\n".join(timestamp_lines).rstrip()
        if timestamp_text:
            timestamp_text += "\n"
        paths.timestamp_md.write_text(timestamp_text, encoding=encoding, newline="\n")

    return count, last_end


def setup_logger() -> tuple[logging.Logger, Path]:
    stamp = time.strftime("%Y%m%d-%H%M%S")
    log_path = Path.cwd() / f"log.transcribe.{VERSION}.{stamp}.log"

    logger = logging.getLogger("deepecho")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    handler = logging.FileHandler(log_path, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s"))
    logger.addHandler(handler)

    return logger, log_path


def print_plan(
    args: argparse.Namespace,
    sources: Sequence[Path],
    models_dir: Path,
    selected_model: Path,
    dest_dir: Path | None,
) -> None:
    print("TRANSCRIPTION PLAN")
    print("-" * 72)
    print(f"Mode                : {'EXEC' if args.exec else 'SIMULATE'}")
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
    print(f"Overwrite           : {'YES' if args.force else 'NO'}")
    print(f"Source count        : {len(sources)}")
    print(f"Destination override: {dest_dir if dest_dir is not None else 'source file directory'}")
    print("-" * 72)

    for index, source in enumerate(sources, start=1):
        paths = output_paths(source, dest_dir)
        print(f"{index}. SOURCE : {source}")
        if args.timestamps:
            print(f"   OUTPUT : {paths.timestamp_md}")
        print(f"   OUTPUT : {paths.plain_md}")
        print(f"   OUTPUT : {paths.plain_txt}")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    argv = sys.argv[1:] if argv is None else argv

    if not argv:
        print_help(parser)
        return 0

    args = parser.parse_args(argv)
    validate_numeric_options(args, parser)

    if args.help:
        print_help(parser)
        return 0

    if args.changelog:
        print(CHANGELOG.rstrip())
        return 0

    if args.prerequis:
        return run_prerequisites(args)

    validate_control(args, parser)

    source_dir = resolve_path(args.source_dir)
    if not source_dir.is_dir():
        print(f"ERROR: source directory does not exist: {source_dir}", file=sys.stderr)
        return 2

    dest_dir = resolve_path(args.dest_dir) if args.dest_dir is not None else None
    if dest_dir is not None:
        if args.simulate:
            if not dest_dir.exists():
                print(f"NOTICE: destination directory would be created: {dest_dir}")
        else:
            dest_dir.mkdir(parents=True, exist_ok=True)

    sources = resolve_sources(source_dir, args.source)
    if not sources:
        patterns = args.source or ["*.mp4"]
        print(
            f"ERROR: no supported media matched {patterns} in {source_dir}",
            file=sys.stderr,
        )
        return 2

    models_dir = resolve_path(args.models_dir)
    selected_model = model_path(models_dir, args.model)

    if not model_complete(selected_model):
        print(
            f"ERROR: model '{args.model}' is not installed at {selected_model}",
            file=sys.stderr,
        )
        print(
            f"Download it first with: ./getModels.sh --exec --download --model {args.model}",
            file=sys.stderr,
        )
        return 2

    if ffmpeg_required(args) and shutil.which("ffmpeg") is None:
        print(
            "ERROR: FFmpeg is required for normalize/amplify but was not found.",
            file=sys.stderr,
        )
        return 2

    # Refuse accidental overwrites already during simulation/planning.
    try:
        for source in sources:
            ensure_output_available(
                output_paths(source, dest_dir),
                timestamps=args.timestamps,
                force=args.force,
            )
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print_plan(args, sources, models_dir, selected_model, dest_dir)

    if args.simulate:
        print()
        print("SIMULATION RESULT: OK - no transcription executed and no output created.")
        return 0

    logger, log_path = setup_logger()
    logger.info("DeepEcho transcription started")
    logger.info("Version=%s model=%s language=%s device=%s compute_type=%s",
                VERSION, args.model, args.language, args.device, args.compute_type)
    logger.info("Sources=%s", [str(p) for p in sources])

    print()
    print(f"Runtime log         : {log_path}")

    try:
        model, selected_model = load_model(args)
    except Exception as exc:
        logger.exception("Model load failed")
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    language = None if str(args.language).lower() == "auto" else args.language
    overall_rc = 0

    for index, source in enumerate(sources, start=1):
        print()
        print(f"[{index}/{len(sources)}] Transcribing: {source}")
        logger.info("Transcribing source=%s", source)

        paths = output_paths(source, dest_dir)

        try:
            with tempfile.TemporaryDirectory(prefix="deepecho_transcribe_") as temp_name:
                temp_dir = Path(temp_name)
                audio_source = preprocess_audio(source, args, temp_dir)

                segments, info = model.transcribe(
                    str(audio_source),
                    language=language,
                    task="transcribe",
                    vad_filter=args.vad,
                    without_timestamps=False,
                    word_timestamps=False,
                    log_progress=True,
                )

                segment_count, last_end = write_outputs(
                    source=source,
                    paths=paths,
                    segments=segments,
                    timestamps=args.timestamps,
                    force=args.force,
                )

                detected_language = getattr(info, "language", None)
                duration = getattr(info, "duration", None)

                print(f"Segments            : {segment_count}")
                if detected_language:
                    print(f"Language            : {detected_language}")
                if duration is not None:
                    print(f"Duration            : {float(duration):.1f} s")
                print(f"Transcript end      : {last_end:.1f} s")
                if args.timestamps:
                    print(f"Created             : {paths.timestamp_md}")
                print(f"Created             : {paths.plain_md}")
                print(f"Created             : {paths.plain_txt}")
                print("RESULT              : OK")

                logger.info(
                    "Completed source=%s segments=%s detected_language=%s duration=%s",
                    source, segment_count, detected_language, duration,
                )

        except subprocess.CalledProcessError as exc:
            overall_rc = 1
            logger.exception("FFmpeg preprocessing failed for %s", source)
            print(f"ERROR: FFmpeg preprocessing failed for {source}: {exc}", file=sys.stderr)
        except Exception as exc:
            overall_rc = 1
            logger.exception("Transcription failed for %s", source)
            print(f"ERROR: transcription failed for {source}: {exc}", file=sys.stderr)

    print()
    print("TRANSCRIPTION RESULT: " + ("OK" if overall_rc == 0 else "ERROR"))
    print(f"Log                 : {log_path}")
    return overall_rc


if __name__ == "__main__":
    raise SystemExit(main())
