"""Validador de la lógica de Pico y Placa (misma lógica que source/PicoLogic.mc).

Uso: python tools/validate.py
"""
import datetime as dt
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

    print("OK: todas las validaciones pasaron.")


if __name__ == "__main__":
    main()
