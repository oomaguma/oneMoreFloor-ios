# process_sounds.py — how the hy_* and ui_* files in Sounds/ were made.
#
#   python3 -I Tools/process_sounds.py <scratch dir>
#
# Reads the source packs from ~/Downloads (paths below; they're not in the
# repo — 3.8 GB of 96 kHz WAVs), and writes into oneMoreFloor/Sounds/. Edit the
# PICKS lists to swap a family or change its target loudness, then rerun.
#
# Turns the picked takes into small game-ready files: mono, trailing silence
# trimmed (with a 30 ms fade so nothing clicks), peak-normalized to a target
# level per role, then AAC at 44.1 kHz via afconvert. Pure Python, no numpy.
import wave, struct, subprocess, os, sys, array
COMBAT = "/Users/joshua/Downloads/Helton Yan's Pixel Combat - Single Files"
UI     = "/Users/joshua/Downloads/Ogg"
OUT    = "/Users/joshua/GitHub/oneMoreFloor-ios/oneMoreFloor/oneMoreFloor/Sounds"
TMP    = sys.argv[1]

# (output stem, source family, takes, target peak dBFS)
COMBAT_PICKS = [
    ("hy_sword_slash",    "DSGNMisc_MELEE-Sword Slash",      range(1,7), -2),
    ("hy_smack",          "FGHTImpt_HIT-Smack",              range(1,7), -3),
    ("hy_gut_punch",      "FGHTImpt_MELEE-Gut Punch",        range(1,7), -3),
    ("hy_sword_critical", "DSGNTonl_MELEE-Sword Critical",   range(1,7), -2),
    ("hy_bit_bomb",       "DSGNImpt_EXPLOSION-Bit Bomb",     range(1,7), -6),
    ("hy_energy_riser",   "MAGSpel_CAST-Energy Riser",       range(1,7), -6),
    ("hy_whoosh",         "WHSH_MOVEMENT-Simple Whoosh",     range(1,7), -6),
    ("hy_sword_parry",    "DSGNMisc_MELEE-Sword Parry",      range(1,7), -3),
    ("hy_simple_heal",    "MAGAngl_BUFF-Simple Heal",        range(1,4), -12),
    ("hy_skill_ready",    "MAGSpel_CAST-Skill Ready",        range(1,4), -14),
    ("hy_magic_item",     "DSGNTonl_USABLE-Magic Item",      range(1,4), -4),
    ("hy_sparkly_star",   "DSGNTonl_SKILL IMPACT-Sparkly Star", range(1,4), -4),
    ("hy_bass_hit",       "DSGNImpt_EXPLOSION-Bass Hit",     range(1,4), -3),
    # Per-floor gold: a quick quiet tink instead of the 1.3 s coin_collect jingle.
    ("hy_coin_zap",       "DSGNTonl_USABLE-Coin Zap",        range(1,7), -16),
]
UI_PICKS = [   # ObsydianX interface tones (CC0), one style each for a cohesive set
    ("ui_confirm", "Confirm_tones/style1/confirm_style_1_00{k}.ogg", range(1,4), -12),
    ("ui_back",    "Back_tones/style1/back_style_1_00{k}.ogg",       range(1,3), -14),
    ("ui_tab",     "Cursor_tones/cursor_style_1.ogg",                range(1,2), -16),
]

def read_mono(path):
    w = wave.open(path); n = w.getnframes(); ch = w.getnchannels(); sw = w.getsampwidth(); sr = w.getframerate()
    raw = w.readframes(n); fr = ch*sw; full = float(2**(8*sw-1))
    out = array.array("f")
    for i in range(n):
        s = 0.0
        for c in range(ch):
            o = i*fr + c*sw
            s += int.from_bytes(raw[o:o+sw], "little", signed=True) / full
        out.append(s / ch)
    return out, sr

def process(src_wav, dst, target_db):
    x, sr = read_mono(src_wav)
    pk = max(abs(v) for v in x) or 1e-9
    thr = pk * 0.01                                   # -40 dB below its own peak
    last = max(i for i,v in enumerate(x) if abs(v) > thr)
    end = min(len(x), last + int(0.03*sr))
    x = x[:end]
    fade = int(0.03*sr)
    for i in range(min(fade, len(x))):                # 30 ms fade-out, no click
        x[len(x)-1-i] *= i / fade
    gain = (10 ** (target_db/20)) / pk
    pcm = array.array("h", (max(-32767, min(32767, int(v*gain*32767))) for v in x))
    mid = os.path.join(TMP, "proc.wav")
    w = wave.open(mid, "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(pcm.tobytes()); w.close()
    subprocess.run(["afconvert","-f","m4af","-d","aac@44100",mid,dst], check=True, capture_output=True)
    return len(x)/sr

for stem, fam, takes, tgt in COMBAT_PICKS:
    for k in takes:
        d = process(f"{COMBAT}/{fam}_HY_PC-00{k}.wav", f"{OUT}/{stem}_{k}.m4a", tgt)
        print(f"{stem}_{k}.m4a  {d:.2f}s")
for stem, pat, takes, tgt in UI_PICKS:
    for k in takes:
        dec = os.path.join(TMP, "dec.wav")
        subprocess.run(["afconvert","-f","WAVE","-d","LEI16@44100", f"{UI}/{pat.format(k=k)}", dec], check=True, capture_output=True)
        d = process(dec, f"{OUT}/{stem}_{k}.m4a", tgt)
        print(f"{stem}_{k}.m4a  {d:.2f}s")
