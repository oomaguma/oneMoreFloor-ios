# raid_balance_sim.py — headless Monte Carlo of RaidScene's combat loop.
#
# Use it to sanity-check raid tuning before playtesting: it answers "how often
# does a hero like this win a raid like that?" for different tap speeds.
# Keep it in sync with RaidScene.swift — if timings, wave sizes, or the
# tuning knobs change there, change them here (or pass them as arguments).
#
#   python3 Tools/raid_balance_sim.py
#
# Calibration (2026-10-29): with the shipped knobs, AUTO-only and ~1 tap/s both
# die in wave 3 at floor 11 — matching two real simulator runs.
# Mirrors the scene's timings: 0.7s intro, enemies walk in staggered 0.8s apart
# over 1.8s, hero swings every 0.9s (a tap swings immediately and resets that
# timer), hits land 0.28s after the swing, enemies swing every 1.6s (boss 2.2s)
# after a random 0.6-1.5s first delay, 1.8s breather between waves.
import random

def enemy_types(zone):
    # (name, hpBase, hpPer, atkBase, atkPer)
    pools = {
        "entrance": [("slime",5,3,1,1), ("skeleton",7,4,2,1)],
        "crypts":   [("skeleton",7,4,2,1), ("archer",6,3,1,2), ("armored",10,5,2,1)],
    }
    boss = {"entrance": ("skeleton",7,4,2,1), "crypts": ("armored",10,5,2,1)}
    return pools[zone], boss[zone]

def run(floor, zone, hero_hp=120, hero_atk=9, hero_def=1, crit=0.05,
        tap_rate=0.0, hp_scale=1.0, atk_scale=1.0, count=lambda w: w + 2,
        breather=0.0, splash=0.0, killheal=0.0, thorns=0.0, seed=None, start_frac=1.0):
    rng = random.Random(seed)
    pool, boss = enemy_types(zone)
    hp = int(hero_hp * start_frac)
    swing_interval = min(0.9, 1.0 / tap_rate) if tap_rate > 0 else 0.9
    dt = 0.02
    for wave in (1, 2, 3):
        n = count(wave)
        enemies = []
        for i in range(n):
            is_boss = (wave == 3 and i == n - 1)
            name, hb, hpp, ab, ap = boss if is_boss else rng.choice(pool)
            ehp = max(1, hb + floor * hpp); eatk = max(1, ab + floor * ap)
            if is_boss: ehp = int(ehp * 2.5); eatk = int(eatk * 1.5)
            ehp = max(1, int(ehp * hp_scale)); eatk = max(1, int(eatk * atk_scale))
            start = 0.35 + 0.8 * i
            target_x = max(95, 155 - 20 * i)
            enemies.append(dict(hp=ehp, atk=eatk, start=start, tx=target_x,
                                arrive=start + 1.8, timer=rng.uniform(0.6, 1.5),
                                interval=2.2 if is_boss else 1.6))
        t = 0.0; swing = 0.0; pending = []   # pending hits: (land_time, enemy, dmg)
        while True:
            t += dt
            def x(e):
                if t < e["start"]: return 290
                f = min(1.0, (t - e["start"]) / 1.8)
                return 290 + (e["tx"] - 290) * f
            alive = [e for e in enemies if e["hp"] > 0]
            if not alive and not pending: break
            # hero swing
            swing -= dt
            inrange = [e for e in alive if x(e) <= 170]
            if swing <= 0 and inrange:
                swing = swing_interval
                tgt = min(inrange, key=x)
                dmg = hero_atk * (2 if rng.random() < crit else 1)
                pending.append((t + 0.28, tgt, dmg))
            # land hits
            for hit in [p for p in pending if p[0] <= t]:
                pending.remove(hit)
                _, e, dmg = hit
                if e["hp"] <= 0: continue
                e["hp"] -= dmg
                if e["hp"] <= 0 and killheal: hp = min(hero_hp, hp + max(1, int(hero_hp * killheal)))
                if splash:
                    others = [o for o in enemies if o is not e and o["hp"] > 0 and x(o) <= 170]
                    if others:
                        o = min(others, key=x); o["hp"] -= max(1, int(dmg * splash))
                        if o["hp"] <= 0 and killheal: hp = min(hero_hp, hp + max(1, int(hero_hp * killheal)))
            # enemy swings
            for e in enemies:
                if e["hp"] <= 0 or t < e["arrive"]: continue
                e["timer"] -= dt
                if e["timer"] <= 0:
                    e["timer"] = e["interval"]
                    d = max(1, e["atk"] - hero_def)
                    hp -= d
                    if thorns and e["hp"] > 1:
                        e["hp"] -= min(e["hp"] - 1, max(1, int(d * thorns)))
                    if hp <= 0: return False, wave
        if wave < 3 and breather:
            hp = min(hero_hp, hp + int(hero_hp * breather))
    return True, 3

def winrate(trials=2000, **kw):
    wins = 0; reached = [0, 0, 0, 0]
    for s in range(trials):
        ok, w = run(seed=s, **kw)
        wins += ok; reached[w] += 1
    return wins / trials



# The shipped tuning (mirror of RaidScene's knobs).
SHIPPED = dict(hp_scale=0.45, atk_scale=0.55, count=lambda w: w + 1, breather=0.15)
BLESSINGS = dict(splash=0.40, killheal=0.08, thorns=0.20)

if __name__ == "__main__":
    print("Fresh Soldier (120 HP / 9 ATK / 1 DEF), shipped raid tuning")
    print(f"{'scenario':32} {'auto':>6} {'tap2/s':>7} {'tap3/s':>7} {'auto+bless':>11}")
    for zone, floor in (("entrance", 10), ("crypts", 11)):
        for start in (1.0, 0.6):
            row = [winrate(floor=floor, zone=zone, tap_rate=r, start_frac=start, **SHIPPED, **(BLESSINGS if b else {}))
                   for r, b in ((0, 0), (2, 0), (3, 0), (0, 1))]
            label = f"{zone} f{floor}, enter at {start:.0%} HP"
            print(f"{label:32} " + " ".join(f"{x:>7.0%}" for x in row[:3]) + f" {row[3]:>11.0%}")
