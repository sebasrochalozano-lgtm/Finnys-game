"""Rebuild the original Finny SFX (Python 3 standard library; no samples)."""
from pathlib import Path
import array
import math
import random
import sys
import wave

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(427)


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def note(buf, start, duration, frequency, gain=0.3, brass=False):
    for i in range(int(duration * RATE)):
        j = int(start * RATE) + i
        if j >= len(buf):
            break
        t = i / RATE
        attack = min(1, t / 0.015)
        tail = min(1, (duration - t) / 0.1)
        env = attack * tail * math.exp(-t * (1.2 if brass else 4.0))
        phase = 2 * math.pi * frequency * t
        if brass:
            tone = sum(math.sin(phase * h) / h**1.4 for h in range(1, 8))
        else:
            tone = math.sin(phase) + 0.34 * math.sin(phase * 2.76) + 0.12 * math.sin(phase * 4.1)
        buf[j] += tone * env * gain


def thump(buf, start, gain=0.7):
    for i in range(int(0.22 * RATE)):
        j = int(start * RATE) + i
        if j >= len(buf):
            break
        t = i / RATE
        env = min(1, t / 0.004) * math.exp(-t * 24)
        buf[j] += gain * env * (math.sin(2 * math.pi * 74 * t) + RNG.uniform(-0.2, 0.2))


def save(name, values):
    # Remove DC, normalize safely and fade edges to avoid clicks.
    mean = sum(values) / len(values)
    values = [v - mean for v in values]
    peak = max(abs(v) for v in values) or 1
    frames = array.array("h")
    for i, value in enumerate(values):
        fade = min(1, i / 450, (len(values) - 1 - i) / 900)
        frames.append(round(value / peak * 0.72 * fade * 32767))
    if sys.byteorder != "little":
        frames.byteswap()
    with wave.open(str(OUT / (name + ".wav")), "wb") as wav:
        wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        wav.writeframes(frames.tobytes())
    print(name, len(values) / RATE, "seconds")


treasure = silence(2.2)
for i, hz in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5, 1568]):
    note(treasure, i * 0.19, 1.0, hz, 0.25)
for i in range(8):
    note(treasure, 0.15 + i * 0.17, 0.22, 1900 + i * 113, 0.06)
save("treasure", treasure)

chest = silence(1.4)
low_noise = 0.0
for i in range(len(chest)):
    t = i / RATE
    low_noise = 0.92 * low_noise + 0.08 * RNG.uniform(-1, 1)
    env = math.sin(math.pi * min(t / 1.1, 1)) ** 2
    squeak = math.sin(2 * math.pi * (175 * t + 72 * t * t) + 1.2 * math.sin(29 * t))
    chest[i] = env * (0.3 * squeak + low_noise)
thump(chest, 1.1, 0.7)
save("chest", chest)

sad = silence(1.8)
for i, hz in enumerate([392, 349.23, 261.63, 196]):
    note(sad, i * 0.25, 0.9, hz, 0.3, True)
save("disappointment", sad)

royal = silence(3.1)
for when in [0.0, 0.35, 0.7, 1.05]:
    thump(royal, when)
for when, hz, duration in [(0.65, 261.63, 0.3), (0.98, 261.63, 0.3), (1.32, 392, 0.42), (1.78, 523.25, 1.0)]:
    note(royal, when, duration, hz, 0.35, True)
    note(royal, when, duration, hz * 0.75, 0.12, True)
save("royal", royal)

idea = silence(1.5)
for i, hz in enumerate([659.25, 783.99, 1046.5]):
    note(idea, i * 0.13, 1.1, hz, 0.3)
save("idea", idea)

fire = silence(0.72)
smooth = 0.0
for i in range(len(fire)):
    t = i / RATE
    n = RNG.uniform(-1, 1)
    smooth = 0.82 * smooth + 0.18 * n
    env = (1 - math.exp(-t * 75)) * math.exp(-t * 5.6)
    rumble = math.sin(2 * math.pi * (140 * t - 55 * t * t))
    air = 0.32 * n + 1.9 * smooth
    fire[i] = env * (air + 0.35 * rumble) * (0.88 + 0.12 * math.sin(2 * math.pi * 37 * t))
save("fire", fire)
