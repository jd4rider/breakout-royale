#!/usr/bin/env python3
"""Synthesise every sound in Breakout Royale 3D.

    python3 Tools/audio.py

Standard library only: the WAVs are written sample by sample so the repository
holds no opaque audio downloads. Re-running is deterministic.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "Assets", "Audio", "SFX")
MUSIC_DIR = os.path.join(ROOT, "Assets", "Audio", "Music")
RATE = 22050


def write(path: str, samples: list[float], peak: float = 0.82) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = bytearray()
    for value in samples:
        clamped = max(-1.0, min(1.0, value * peak))
        data += struct.pack("<h", int(clamped * 32767))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(bytes(data))
    print("wrote", os.path.relpath(path, ROOT), f"{len(samples) / RATE:.2f}s")


def tone(freq: float, seconds: float, decay: float = 8.0, kind: str = "sine") -> list[float]:
    out = []
    count = int(RATE * seconds)
    for i in range(count):
        t = i / RATE
        env = math.exp(-decay * t)
        phase = math.tau * freq * t
        if kind == "square":
            value = 1.0 if math.sin(phase) >= 0 else -1.0
            value *= 0.55
        elif kind == "saw":
            value = 2.0 * ((freq * t) % 1.0) - 1.0
        else:
            value = math.sin(phase)
        out.append(value * env)
    return out


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(track) for track in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, value in enumerate(track):
            out[i] += value
    return out


def concat(*tracks: list[float]) -> list[float]:
    out: list[float] = []
    for track in tracks:
        out.extend(track)
    return out


def sweep(start: float, end: float, seconds: float, decay: float = 5.0) -> list[float]:
    out = []
    count = int(RATE * seconds)
    phase = 0.0
    for i in range(count):
        t = i / RATE
        freq = start + (end - start) * (i / count)
        phase += math.tau * freq / RATE
        out.append(math.sin(phase) * math.exp(-decay * t))
    return out


def noise(seconds: float, decay: float = 12.0, seed: int = 1) -> list[float]:
    rng = random.Random(seed)
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        out.append((rng.random() * 2.0 - 1.0) * math.exp(-decay * t))
    return out


def sfx() -> None:
    write(os.path.join(SFX_DIR, "ui_click.wav"), tone(880, 0.07, 40), 0.5)
    write(os.path.join(SFX_DIR, "ui_back.wav"), tone(520, 0.1, 26), 0.45)
    write(os.path.join(SFX_DIR, "paddle.wav"), mix(tone(420, 0.1, 30), tone(840, 0.08, 40)), 0.6)
    write(os.path.join(SFX_DIR, "wall.wav"), tone(300, 0.07, 45), 0.45)
    write(os.path.join(SFX_DIR, "brick.wav"), mix(tone(660, 0.09, 34), noise(0.05, 60, 3)), 0.55)
    write(os.path.join(SFX_DIR, "brick_break.wav"),
          mix(sweep(900, 260, 0.22, 10), noise(0.16, 18, 7)), 0.7)
    write(os.path.join(SFX_DIR, "steel.wav"), mix(tone(180, 0.14, 22, "square"), noise(0.06, 40, 5)), 0.5)
    write(os.path.join(SFX_DIR, "launch.wav"), sweep(220, 880, 0.24, 6), 0.55)
    write(os.path.join(SFX_DIR, "power.wav"),
          concat(tone(660, 0.08, 18), tone(880, 0.08, 18), tone(1320, 0.16, 12)), 0.55)
    write(os.path.join(SFX_DIR, "hazard.wav"), sweep(520, 150, 0.3, 7), 0.55)
    write(os.path.join(SFX_DIR, "life_lost.wav"),
          mix(sweep(400, 90, 0.5, 5), noise(0.35, 9, 11)), 0.65)
    write(os.path.join(SFX_DIR, "boss_hit.wav"), mix(tone(140, 0.2, 14), noise(0.12, 24, 13)), 0.6)
    write(os.path.join(SFX_DIR, "boss_shot.wav"), sweep(760, 380, 0.16, 14), 0.45)
    write(os.path.join(SFX_DIR, "level_clear.wav"),
          concat(tone(523, 0.12, 8), tone(659, 0.12, 8), tone(784, 0.12, 8), tone(1046, 0.42, 4)), 0.6)
    write(os.path.join(SFX_DIR, "level_fail.wav"),
          concat(tone(392, 0.16, 8), tone(311, 0.16, 8), tone(233, 0.5, 5)), 0.6)
    write(os.path.join(SFX_DIR, "combo.wav"), concat(tone(988, 0.06, 24), tone(1318, 0.1, 18)), 0.4)
    write(os.path.join(SFX_DIR, "boss_die.wav"),
          mix(sweep(320, 60, 0.9, 3), noise(0.7, 5, 17)), 0.75)


CHORDS = [
    [220.00, 261.63, 329.63],
    [196.00, 246.94, 293.66],
    [174.61, 220.00, 261.63],
    [196.00, 246.94, 329.63],
]


def music(name: str, seconds: float, lead: bool) -> None:
    """A slow pad with a pulse bass and, in-game, an arpeggio on top."""
    beat = 0.5
    bars = int(seconds / (beat * 4))
    length = int(RATE * seconds)
    out = [0.0] * length
    for bar in range(bars):
        chord = CHORDS[bar % len(CHORDS)]
        start = bar * beat * 4
        for note_index, freq in enumerate(chord):
            for i in range(int(RATE * beat * 4)):
                t = i / RATE
                attack = min(1.0, t / 0.25)
                release = min(1.0, (beat * 4 - t) / 0.4)
                phase = math.tau * freq * (start + t)
                value = math.sin(phase) * 0.11 + math.sin(phase * 2.0) * 0.03
                index = int(RATE * start) + i
                if 0 <= index < length:
                    out[index] += value * attack * release
        for step in range(8):
            t0 = start + step * beat * 0.5
            freq = chord[0] * (2.0 if step % 2 else 0.5)
            for i in range(int(RATE * beat * 0.5)):
                t = i / RATE
                env = math.exp(-9.0 * t)
                index = int(RATE * t0) + i
                if 0 <= index < length:
                    out[index] += math.sin(math.tau * freq * t) * env * 0.16
        if lead:
            for step in range(8):
                t0 = start + step * beat * 0.5
                freq = chord[step % 3] * 2.0
                for i in range(int(RATE * beat * 0.4)):
                    t = i / RATE
                    env = math.exp(-14.0 * t)
                    index = int(RATE * t0) + i
                    if 0 <= index < length:
                        out[index] += math.sin(math.tau * freq * t) * env * 0.07
    write(os.path.join(MUSIC_DIR, name + ".wav"), out, 0.7)


if __name__ == "__main__":
    sfx()
    music("menu", 16.0, False)
    music("game", 16.0, True)
    print("audio build complete")
