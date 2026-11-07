import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "raw_audio"
OUT_DIR = ROOT / "processed_audio"
ASSET_DIR = ROOT / "assets" / "audio" / "am"
WORDS_JSON = ROOT / "assets" / "data" / "words.json"

TARGET_LUFS = -14.0
TARGET_TP = -1.0
MIN_SOUND_S = 0.05
LIMIT_LINEAR = 0.794
TOLERANCE_LU = 0.5
MAX_PASSES = 4
SILENCE_DB = -45
PADDING_S = 0.1
SAMPLE_RATE = 48000
BITRATE = "112k"
AUDIO_EXTS = {".m4a", ".mp3", ".wav", ".aac", ".ogg", ".flac", ".opus", ".wma", ".amr", ".3gp"}


def trim_chain():
    one_side = (
        f"silenceremove=start_periods=1:start_threshold={SILENCE_DB}dB:"
        f"start_duration={MIN_SOUND_S}:start_silence={PADDING_S}:detection=peak"
    )
    return f"aformat=channel_layouts=mono,{one_side},areverse,{one_side},areverse"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")


def parse_loudnorm_json(stderr):
    match = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", stderr, re.S)
    if not match:
        raise RuntimeError("could not read loudnorm measurement")
    return json.loads(match.group(0))


def loudness(src, af):
    res = run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(src), "-af", f"{af}loudnorm=print_format=json", "-f", "null", "-"])
    if res.returncode != 0:
        raise RuntimeError(res.stderr.strip().splitlines()[-1] if res.stderr.strip() else "ffmpeg failed")
    m = parse_loudnorm_json(res.stderr)
    return float(m["input_i"]), float(m["input_tp"])


def encode(src, dst, gain_db):
    af = (
        f"{trim_chain()},volume={gain_db:.2f}dB,"
        f"alimiter=limit={LIMIT_LINEAR}:attack=5:release=50:level=disabled"
    )
    res = run([
        "ffmpeg", "-hide_banner", "-nostats", "-y", "-i", str(src), "-af", af,
        "-ac", "1", "-ar", str(SAMPLE_RATE), "-c:a", "libmp3lame", "-b:a", BITRATE,
        "-map_metadata", "-1", str(dst),
    ])
    if res.returncode != 0:
        raise RuntimeError(res.stderr.strip().splitlines()[-1] if res.stderr.strip() else "ffmpeg failed")


def process(src, dst):
    raw_i, _ = loudness(src, f"{trim_chain()},")
    gain = TARGET_LUFS - raw_i
    for _ in range(MAX_PASSES):
        encode(src, dst, gain)
        out_i, out_tp = loudness(dst, "")
        if abs(out_i - TARGET_LUFS) <= TOLERANCE_LU:
            break
        gain += TARGET_LUFS - out_i
    dur = run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(dst),
    ]).stdout.strip()
    return raw_i, out_i, out_tp, float(dur)


def main():
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        sys.exit("ffmpeg/ffprobe not found on PATH")

    data = json.loads(WORDS_JSON.read_text(encoding="utf-8"))
    audio_by_id = {w["id"]: Path(w["audio"]).name for w in data["words"]}
    valid_names = set(audio_by_id.values())

    OUT_DIR.mkdir(exist_ok=True)
    raw_files = sorted(p for p in RAW_DIR.iterdir() if p.is_file() and p.suffix.lower() in AUDIO_EXTS)

    done, failed, skipped = [], [], []
    for src in raw_files:
        out_name = f"{src.stem}.mp3"
        if out_name not in valid_names:
            skipped.append(src.name)
            continue
        dst = OUT_DIR / out_name
        try:
            done.append((out_name, *process(src, dst)))
        except Exception as e:
            failed.append((src.name, str(e)))

    print(f"{'file':<18}{'raw LUFS':>10}{'out LUFS':>10}{'out TP':>9}{'dur s':>8}")
    for name, raw_i, lufs, tp, dur in done:
        print(f"{name:<18}{raw_i:>10.1f}{lufs:>10.1f}{tp:>9.1f}{dur:>8.2f}")

    print(f"\nProcessed: {len(done)}")
    print(f"Failed: {len(failed)}")
    for name, err in failed:
        print(f"  {name}: {err}")
    print(f"Skipped (name not in words.json): {len(skipped)}")
    for name in skipped:
        print(f"  {name}")

    existing = {p.name for p in ASSET_DIR.glob("*.mp3")}
    processed = {p.name for p in OUT_DIR.glob("*.mp3")}
    overlap = sorted(existing & processed)
    missing = [wid for wid, fn in audio_by_id.items() if fn not in existing and fn not in processed]
    print(f"Already in assets/audio/am (will not be overwritten): {len(overlap)}")
    for name in overlap:
        print(f"  {name}")
    print(f"Words still without audio: {len(missing)}")
    for wid in missing:
        print(f"  {wid}")


if __name__ == "__main__":
    main()
