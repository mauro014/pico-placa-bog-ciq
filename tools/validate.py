"""Validador de la lógica de Pico y Placa (misma lógica que source/PicoLogic.mc
y source/PicoService.mc).

Uso:
    python tools/validate.py                 # pruebas + valida docs/exceptions.json
    python tools/validate.py otro.json       # valida otro archivo de excepciones
"""
import datetime as dt
import json
import os
import re
import sys


def days_from_civil(y, m, d):
    """Días desde 1970-01-01 (algoritmo de Howard Hinnant), solo enteros."""
    if m <= 2:
        y -= 1
    era = (y if y >= 0 else y - 399) // 400
    yoe = y - era * 400
    mp = m - 3 if m > 2 else m + 9
    doy = (153 * mp + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


def civil_from_days(z):
    z += 719468
    era = (z if z >= 0 else z - 146096) // 146097
    doe = z - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    y = yoe + era * 400
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    d = doy - (153 * mp + 2) // 5 + 1
    m = mp + 3 if mp < 10 else mp - 9
    return (y + 1 if m <= 2 else y), m, d


def weekday(days):
    """0 = lunes ... 6 = domingo (1970-01-01 fue jueves)."""
    return (days + 3) % 7


def easter(y):
    """Domingo de Pascua (algoritmo gregoriano anónimo / Meeus)."""
    a = y % 19
    b = y // 100
    c = y % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = (h + l - 7 * m + 114) % 31 + 1
    return days_from_civil(y, month, day)


def next_monday(days):
    w = weekday(days)
    return days if w == 0 else days + (7 - w)


def holidays(y):
    fixed = [(1, 1), (5, 1), (7, 20), (8, 7), (12, 8), (12, 25)]
    emiliani = [(1, 6), (3, 19), (6, 29), (8, 15), (10, 12), (11, 1), (11, 11)]
    p = easter(y)
    out = [days_from_civil(y, m, d) for m, d in fixed]
    out += [next_monday(days_from_civil(y, m, d)) for m, d in emiliani]
    out += [p - 3, p - 2, p + 43, p + 64, p + 71]
    return sorted(set(out))


def is_holiday(days):
    y, _, _ = civil_from_days(days)
    return days in holidays(y)


def is_business_day(days):
    return weekday(days) < 5 and not is_holiday(days)


def circulates(digit, day_of_month, odd_days_low=True):
    """True si la placa puede circular ese día (ignorando fines de semana/festivos)."""
    low = 1 <= digit <= 5
    odd = day_of_month % 2 == 1
    return (low == odd) if odd_days_low else (low != odd)


def has_pico(digit, days, odd_days_low=True):
    if not is_business_day(days):
        return False
    _, _, d = civil_from_days(days)
    return not circulates(digit, d, odd_days_low)


# ---------------------------------------------------------------- excepciones (v2)
# Estados (iguales a PicoLogic)
LIBRE, PICO, FINDE, FESTIVO, LEVANTADA = 0, 1, 2, 3, 4
MAX_EXC = 60  # máximo de fechas que guarda el reloj


def parse_date(text):
    """'AAAA-MM-DD' -> días desde 1970, o None si el formato no es válido."""
    if not isinstance(text, str) or len(text) != 10 or text[4] != "-" or text[7] != "-":
        return None
    try:
        y, m, d = int(text[0:4]), int(text[5:7]), int(text[8:10])
    except ValueError:
        return None
    if not (1 <= m <= 12 and 1 <= d <= 31):
        return None
    return days_from_civil(y, m, d)


def compact(data, today):
    """Igual que PicoService.compact: {días: máscara de dígitos con restricción}.
    Solo fechas desde ayer, máximo MAX_EXC."""
    res = {}
    items = data.get("exceptions") if isinstance(data, dict) else None
    if not isinstance(items, list):
        return res
    for it in items:
        if not isinstance(it, dict):
            continue
        days = parse_date(it.get("date"))
        pico = it.get("pico")
        if days is None or days < today - 1 or not isinstance(pico, list):
            continue
        mask = 0
        for dgt in pico:
            if isinstance(dgt, int) and 0 <= dgt <= 9:
                mask |= 1 << dgt
        res[days] = mask
        if len(res) >= MAX_EXC:
            break
    return res


def status(days, digit, odd_days_low=True, exc=None):
    """Igual que PicoLogic.status (con excepciones)."""
    if exc and days in exc:
        mask = exc[days]
        if (mask >> digit) & 1:
            return PICO
        return LEVANTADA if mask == 0 else LIBRE
    if weekday(days) >= 5:
        return FINDE
    if is_holiday(days):
        return FESTIVO
    _, _, d = civil_from_days(days)
    return LIBRE if circulates(digit, d, odd_days_low) else PICO


def validate_json(path):
    """Valida el archivo de excepciones publicado. Devuelve lista de errores."""
    errors = []
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        return [f"no se pudo leer {path}: {e}"]
    if not isinstance(data, dict):
        return ["la raíz debe ser un objeto"]
    if data.get("version") != 1:
        errors.append('"version" debe ser 1')
    if parse_date(data.get("updated")) is None:
        errors.append('"updated" debe ser una fecha AAAA-MM-DD')
    items = data.get("exceptions")
    if not isinstance(items, list):
        return errors + ['"exceptions" debe ser una lista']
    seen = set()
    for i, it in enumerate(items):
        where = f"exceptions[{i}]"
        if not isinstance(it, dict):
            errors.append(f"{where}: debe ser un objeto")
            continue
        date = it.get("date")
        days = parse_date(date)
        if days is None or civil_from_days(days) != tuple(int(x) for x in date.split("-")):
            errors.append(f"{where}: fecha inválida {date!r}")
        elif date in seen:
            errors.append(f"{where}: fecha repetida {date}")
        seen.add(date)
        pico = it.get("pico")
        if not isinstance(pico, list) or any(
                not isinstance(x, int) or isinstance(x, bool) or not 0 <= x <= 9 for x in pico):
            errors.append(f"{where}: \"pico\" debe ser una lista de dígitos 0-9")
        elif len(set(pico)) != len(pico):
            errors.append(f"{where}: dígitos repetidos en \"pico\"")
        if "note" in it and not isinstance(it["note"], str):
            errors.append(f"{where}: \"note\" debe ser texto")
    if len(items) > MAX_EXC:
        errors.append(f"más de {MAX_EXC} excepciones: el reloj solo guarda {MAX_EXC}")
    return errors


# ---------------------------------------------------------------- pruebas
def fmt(days):
    y, m, d = civil_from_days(days)
    return f"{y:04d}-{m:02d}-{d:02d}"


def check(cond, msg):
    if not cond:
        print("FALLO:", msg)
        sys.exit(1)


def main():
    # days_from_civil / civil_from_days / weekday contra datetime
    base = dt.date(1970, 1, 1)
    for y in range(1990, 2101):
        for m, d in [(1, 1), (2, 28), (3, 1), (12, 31)]:
            dd = dt.date(y, m, d)
            n = days_from_civil(y, m, d)
            check(n == (dd - base).days, f"days_from_civil {dd}")
            check(civil_from_days(n) == (y, m, d), f"civil_from_days {dd}")
            check(weekday(n) == dd.weekday(), f"weekday {dd}")

    expected = {
        2026: ["01-01", "01-12", "03-23", "04-02", "04-03", "05-01", "05-18",
               "06-08", "06-15", "06-29", "07-20", "08-07", "08-17", "10-12",
               "11-02", "11-16", "12-08", "12-25"],
        # 2025 y 2027 según el calendario oficial de festivos de Colombia
        2025: ["01-01", "01-06", "03-24", "04-17", "04-18", "05-01", "06-02",
               "06-23", "06-30", "06-30",  # 2025: San Pedro y Sagrado Corazón coinciden
               "07-20", "08-07", "08-18", "10-13",
               "11-03", "11-17", "12-08", "12-25"],
        2027: ["01-01", "01-11", "03-22", "03-25", "03-26", "05-01", "05-10",
               "05-31", "06-07", "07-05", "07-20", "08-07", "08-16", "10-18",
               "11-01", "11-15", "12-08", "12-25"],
    }
    for y, exp in expected.items():
        got = [fmt(h)[5:] for h in holidays(y)]
        exp_set = sorted(set(exp))
        print(f"{y} ({len(got)}): {', '.join(got)}")
        check(got == exp_set, f"festivos {y}: esperado {exp_set}")

    # Casos de rotación
    v13 = days_from_civil(2026, 3, 13)
    l16 = days_from_civil(2026, 3, 16)
    check(weekday(v13) == 4 and weekday(l16) == 0, "13-mar viernes, 16-mar lunes")
    check([d for d in range(10) if not has_pico(d, v13)] == [1, 2, 3, 4, 5],
          "13-mar-2026 circulan 1-5")
    check([d for d in range(10) if not has_pico(d, l16)] == [0, 6, 7, 8, 9],
          "16-mar-2026 circulan 6-0")
    # Rotación invertida
    check([d for d in range(10) if not has_pico(d, v13, False)] == [0, 6, 7, 8, 9],
          "13-mar-2026 invertido circulan 6-0")
    # Fines de semana y festivos: nadie tiene pico y placa
    for day in (days_from_civil(2026, 3, 14), days_from_civil(2026, 3, 23)):
        check(all(not has_pico(d, day) for d in range(10)), f"libre {fmt(day)}")

    # Excepciones
    hoy = days_from_civil(2026, 11, 23)
    data = {"version": 1, "updated": "2026-11-23", "exceptions": [
        {"date": "2026-11-20", "pico": []},                   # pasada: se descarta
        {"date": "2026-11-24", "pico": []},                   # medida levantada
        {"date": "2026-11-25", "pico": [6, 7, 8, 9, 0]},      # rotación cambiada
        {"date": "2026-11-28", "pico": [3]},                  # sábado con restricción
        {"date": "2026-13-01", "pico": []},                   # inválida
        {"date": "2026-11-26", "pico": [1, 2, 99, "x"]},      # ignora basura
    ]}
    exc = compact(data, hoy)
    check(days_from_civil(2026, 11, 20) not in exc, "excepción pasada descartada")
    check(len(exc) == 4, f"4 excepciones válidas, hay {len(exc)}")
    check(exc[days_from_civil(2026, 11, 26)] == 0b110, "máscara ignora valores inválidos")
    d24, d25, d28 = (days_from_civil(2026, 11, x) for x in (24, 25, 28))
    check(status(d24, 3) == PICO and status(d24, 3, exc=exc) == LEVANTADA, "24-nov levantada")
    check(status(d24, 7, exc=exc) == LEVANTADA, "24-nov levantada para todos")
    check(status(d25, 3) == LIBRE and status(d25, 3, exc=exc) == LIBRE, "25-nov placa 3 libre")
    check(status(d25, 7, exc=exc) == PICO, "25-nov placa 7 pico (excepción)")
    check(status(d28, 3, exc=exc) == PICO, "28-nov sábado con excepción")
    check(status(d28, 4, exc=exc) == LIBRE, "28-nov placa 4 libre")
    check(status(days_from_civil(2026, 11, 27), 7, exc=exc) == PICO, "sin excepción: regla normal")
    check(len(compact({"exceptions": [{"date": f"2027-01-{i:02d}", "pico": []} for i in range(1, 32)]
                       + [{"date": f"2027-02-{i:02d}", "pico": []} for i in range(1, 29)]
                       + [{"date": f"2027-03-{i:02d}", "pico": []} for i in range(1, 32)]},
                      hoy)) == MAX_EXC, "tope de excepciones")
    # El reloj acepta 2026-02-30 (no valida días por mes); validate_json sí lo rechaza.
    check(parse_date("2026-02-30") is not None, "parse_date laxo como en el reloj")

    # Archivo publicado
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "docs", "exceptions.json")
    errs = validate_json(path)
    for e in errs:
        print("FALLO JSON:", e)
    check(not errs, f"{path} inválido")
    print(f"JSON OK: {os.path.normpath(path)}")

    print("OK: todas las validaciones pasaron.")


if __name__ == "__main__":
    main()
