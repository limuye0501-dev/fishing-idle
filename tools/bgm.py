# 原创程序化 BGM《港口小调》：轻快的拨弦 + 柔和贝斯，C 大调 I-vi-IV-V，16 小节无缝循环
# 用法：python3 tools/bgm.py && ffmpeg -i /tmp/bgm.wav -c:a aac -b:a 64k App/Resources/Audio/bgm_harbor.m4a
import numpy as np, wave
sr=22050; bpm=96; beat=60/bpm
def pluck(f,dur,amp=0.3):
    t=np.arange(int(sr*dur))/sr
    env=np.exp(-t*5)*(1-np.exp(-t*200))
    return amp*env*(np.sin(2*np.pi*f*t)+0.35*np.sin(4*np.pi*f*t)+0.12*np.sin(6*np.pi*f*t))
def n(m): return 440*2**((m-69)/12)
chords=[(60,64,67),(57,60,64),(53,57,60),(55,59,62)]
mel=[[72,76,79,76,74,72,74,76],[72,69,72,76,74,72,69,67],[69,72,77,76,74,72,69,72],[71,74,79,77,76,74,71,74]]
bars=16; L=int(sr*beat*4*bars)+sr; out=np.zeros(L)
for b in range(bars):
    ch=chords[b%4]; t0=b*4*beat
    for k in range(8):
        s=int(sr*(t0+k*beat/2)); x=pluck(n(ch[k%3]),1.2,0.12); out[s:s+len(x)]+=x
    x=pluck(n(ch[0]-24),beat*4,0.25); s=int(sr*t0); out[s:s+len(x)]+=x
    if b>=4:
        for k,m in enumerate(mel[b%4]):
            if (b//4)%2==1 and k%2==1: continue
            s=int(sr*(t0+k*beat/2)); x=pluck(n(m),0.9,0.10); out[s:s+len(x)]+=x
loop=int(sr*beat*4*bars); tail=out[loop:]; out=out[:loop]; out[:len(tail)]+=tail
out=out/np.abs(out).max()*0.6
w=wave.open("/tmp/bgm.wav","wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes((out*32767).astype("<i2").tobytes()); w.close()
