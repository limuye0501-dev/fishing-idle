"""Procedurally synthesise ambience/SFX for 船长别回来 (original, released CC0).
Usage: python3 gen.py OUTDIR   (needs numpy + ffmpeg)"""
import numpy as np, subprocess, sys, os, wave
SR = 44100
rng = np.random.default_rng(7)
out = sys.argv[1] if len(sys.argv) > 1 else "out"; os.makedirs(out, exist_ok=True)

def lp(x, a):  # one-pole lowpass, a in (0,1)
    y = np.empty_like(x); acc = 0.0
    # vectorised via cumulative filter approximation
    from scipy.signal import lfilter
    return lfilter([a], [1, a - 1], x)
def hp(x, a): return x - lp(x, a)
def env_smooth(n, rate, lo, hi):
    k = max(2, int(n / SR * rate) + 2)
    pts = rng.uniform(lo, hi, k); xs = np.linspace(0, n, k)
    return np.interp(np.arange(n), xs, pts)
def loopify(x, fade=2.0):
    f = int(fade * SR); head = x[:f].copy(); x = x[f:].copy()
    w = np.linspace(0, 1, f); x[-f:] = x[-f:] * (1 - w) + head * w; return x
def noise(n): return rng.standard_normal(n)
def norm(x, peak=0.6): return x / (np.max(np.abs(x)) + 1e-9) * peak

def surf(n, depth=1.0, period=7.0):
    t = np.arange(n) / SR
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / period + rng.uniform(0, 6)) ** 2
    b = lp(noise(n), 0.02 * depth) * 3 + lp(noise(n), 0.15) * 0.4 * swell
    return b * swell * env_smooth(n, 0.3, 0.7, 1.0)
def gull(n, at):
    t = np.arange(int(0.45 * SR)) / SR
    f = 1500 + 900 * np.exp(-t * 7) * np.sin(2 * np.pi * 5 * t)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4) * (t * 20).clip(0, 1)
    y = np.zeros(n); i = int(at * SR); y[i:i + len(s)] += s[:n - i]; return y
def trill(n, at, base=3200):
    t = np.arange(int(0.35 * SR)) / SR
    f = base + 600 * np.sign(np.sin(2 * np.pi * 22 * t))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6)
    y = np.zeros(n); i = int(at * SR); y[i:i + len(s)] += s[:n - i]; return y
def wind(n):
    g = env_smooth(n, 0.4, 0.2, 1.0)
    w = lp(noise(n), 0.03) * 4
    whistle = lp(noise(n), 0.002) * 30 * np.sin(2 * np.pi * np.cumsum(500 + 200 * g) / SR)
    return (w + 0.15 * whistle) * g
def creak(n, at):
    t = np.arange(int(0.6 * SR)) / SR
    s = np.sin(2 * np.pi * (90 + 40 * t) * t) * (np.sin(2 * np.pi * 30 * t) > 0.6) * np.exp(-t * 4)
    y = np.zeros(n); i = int(at * SR); y[i:i + len(s)] += s[:n - i]; return y
def rain(n):
    hiss = hp(noise(n), 0.2) * 0.5
    drops = (rng.random(n) < 0.0015) * rng.uniform(0.3, 1, n)
    return hiss + lp(drops, 0.3) * 2

def write(name, x, loop=False):
    x = norm(loopify(x) if loop else x)
    wav = f"/tmp/{name}.wav"
    with wave.open(wav, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "aac", "-b:a", "96k", f"{out}/{name}.m4a"], check=True)

L = 32; n = L * SR
c = surf(n); [c.__iadd__(0.25 * gull(n, a)) for a in (3, 11.5, 12.2, 24)]
write("amb_coastal", c, True)
write("amb_atlantic", surf(n, 0.7, 9) + 0.35 * wind(n), True)
tp = surf(n, 1.3, 6) * 0.8; [tp.__iadd__(0.12 * trill(n, a, b)) for a, b in ((2, 3200), (6.3, 3600), (15, 2900), (21, 3400), (27.5, 3100))]
write("amb_tropical", tp, True)
pl = wind(n) + 0.4 * surf(n, 0.5, 11); [pl.__iadd__(0.3 * creak(n, a)) for a in (5, 18, 26)]
write("amb_polar", pl, True)
write("amb_rain", rain(n), True)
# underwater: heavy lowpass of surf + bubbles
uw = lp(surf(n), 0.01) * 4 + lp((rng.random(n) < 0.0008) * 1.0, 0.05) * 3
write("amb_underwater", uw, True)
# SFX
t = np.arange(int(1.4 * SR)) / SR
chime = sum(np.sin(2 * np.pi * f * t) * np.exp(-(t - d).clip(0) * 3) * (t >= d) for f, d in ((1046, 0), (1318, .12), (1568, .24), (2093, .36)))
write("sfx_rare", chime * (1 + 0.3 * np.sin(2 * np.pi * 7 * t)))
t = np.arange(int(0.5 * SR)) / SR
write("sfx_splash", hp(noise(len(t)), 0.3) * np.exp(-t * 9) + lp(noise(len(t)), 0.05) * 3 * np.exp(-t * 6))
t = np.arange(int(1.6 * SR)) / SR
write("sfx_purr", lp(noise(len(t)), 0.01) * (0.5 + 0.5 * np.sin(2 * np.pi * 24 * t)) * np.sin(np.pi * t / 1.6))
t = np.arange(int(0.25 * SR)) / SR
write("sfx_shutter", hp(noise(len(t)), 0.4) * (np.exp(-t * 60) + 0.6 * np.exp(-(t - .09).clip(0) * 70) * (t > .09)))
print("ok")
