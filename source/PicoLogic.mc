import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Lógica de Pico y Placa (Bogotá, particulares). Misma lógica que tools/validate.py.
// Toda la aritmética de fechas usa enteros: días desde 1970-01-01.
// (:background) porque el servicio que descarga las excepciones usa daysFromCivil/today.
(:glance, :background)
module PicoLogic {

    // Estados de un día
    const LIBRE = 0;     // día hábil, la placa circula
    const PICO = 1;      // día hábil, la placa tiene pico y placa
    const FINDE = 2;     // sábado o domingo
    const FESTIVO = 3;   // festivo en Colombia
    const LEVANTADA = 4; // excepción: la Alcaldía levantó la medida ese día

    const COLOR_PICO = 0xD9483B;   // rojo ladrillo: no salgas
    const COLOR_LIBRE = 0x3FA66B;  // verde sobrio: puedes salir
    const COLOR_GRIS = 0xAAAAAA;

    // ---------------------------------------------------------------- ajustes

    function plateDigit() as Number {
        var v = Properties.getValue("plateDigit");
        if (v instanceof Number && v >= 0 && v <= 9) {
            return v;
        }
        return 3;
    }

    function oddDaysLow() as Boolean {
        var v = Properties.getValue("oddDaysLow");
        if (v instanceof Boolean) {
            return v;
        }
        return true;
    }

    // 0 = automático (idioma del reloj), 1 = English, 2 = Español.
    function language() as Number {
        var v = Properties.getValue("language");
        if (v instanceof Number && v >= 0 && v <= 2) {
            return v;
        }
        return 0;
    }

    // true si la app debe mostrarse en español.
    function isEs() as Boolean {
        var l = language();
        if (l == 0) {
            return System.getDeviceSettings().systemLanguage == System.LANGUAGE_SPA;
        }
        return l == 2;
    }

    // ---------------------------------------------------------------- fechas

    // Fecha local de hoy como días desde 1970-01-01.
    function today() as Number {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return daysFromCivil(info.year as Number, info.month as Number, info.day as Number);
    }

    // Algoritmo days_from_civil (Howard Hinnant). Válido para años >= 0.
    function daysFromCivil(y as Number, m as Number, d as Number) as Number {
        if (m <= 2) {
            y -= 1;
        }
        var era = y / 400;
        var yoe = y - era * 400;
        var mp = (m > 2) ? m - 3 : m + 9;
        var doy = (153 * mp + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    // Inverso: devuelve [año, mes, día].
    function civilFromDays(z as Number) as [Number, Number, Number] {
        z += 719468;
        var era = z / 146097;
        var doe = z - era * 146097;
        var yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        var y = yoe + era * 400;
        var doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        var mp = (5 * doy + 2) / 153;
        var d = doy - (153 * mp + 2) / 5 + 1;
        var m = (mp < 10) ? mp + 3 : mp - 9;
        if (m <= 2) {
            y += 1;
        }
        return [y, m, d];
    }

    // 0 = lunes ... 6 = domingo (1970-01-01 fue jueves).
    function weekday(days as Number) as Number {
        return (days + 3) % 7;
    }

    // Domingo de Pascua, algoritmo gregoriano anónimo (Meeus/Jones/Butcher).
    function easter(y as Number) as Number {
        var a = y % 19;
        var b = y / 100;
        var c = y % 100;
        var h = (19 * a + b - b / 4 - (b - (b + 8) / 25 + 1) / 3 + 15) % 30;
        var l = (32 + 2 * (b % 4) + 2 * (c / 4) - h - c % 4) % 7;
        var m = (a + 11 * h + 22 * l) / 451;
        var n = h + l - 7 * m + 114;
        return daysFromCivil(y, n / 31, n % 31 + 1);
    }

    // Ley Emiliani: si no cae en lunes, pasa al lunes siguiente.
    function emiliani(y as Number, m as Number, d as Number) as Number {
        var days = daysFromCivil(y, m, d);
        var w = weekday(days);
        return (w == 0) ? days : days + 7 - w;
    }

    function isHoliday(days as Number, y as Number, m as Number, d as Number) as Boolean {
        // Fijos
        var md = m * 100 + d;
        if (md == 101 || md == 501 || md == 720 || md == 807 || md == 1208 || md == 1225) {
            return true;
        }
        // Emiliani (solo puede caer en lunes)
        if (weekday(days) == 0) {
            if (days == emiliani(y, 1, 6) || days == emiliani(y, 3, 19)
                || days == emiliani(y, 6, 29) || days == emiliani(y, 8, 15)
                || days == emiliani(y, 10, 12) || days == emiliani(y, 11, 1)
                || days == emiliani(y, 11, 11)) {
                return true;
            }
        }
        // Según la Pascua
        var p = days - easter(y);
        return p == -3 || p == -2 || p == 43 || p == 64 || p == 71;
    }

    // ---------------------------------------------------------------- excepciones (v2)

    // Excepciones descargadas por PicoService: {días desde 1970 => máscara de dígitos
    // con restricción}. Máscara 0 = medida levantada. Se cachea; resetCache() al cambiar.
    var _exc as Dictionary<Number, Number>? = null;
    var _excLoaded as Boolean = false;

    function exceptions() as Dictionary<Number, Number>? {
        if (!_excLoaded) {
            var v = Storage.getValue("exc");
            _exc = (v instanceof Dictionary) ? v as Dictionary<Number, Number> : null;
            _excLoaded = true;
        }
        return _exc;
    }

    function resetCache() as Void {
        _excLoaded = false;
    }

    // ---------------------------------------------------------------- textos

    // Motivo por el que no aplica la medida ("" si es día hábil).
    function reason(st as Number, es as Boolean) as String {
        if (st == LEVANTADA) {
            return es ? "medida levantada" : "lifted";
        } else if (st == FESTIVO) {
            return es ? "festivo" : "holiday";
        } else if (st == FINDE) {
            return es ? "fin de semana" : "weekend";
        }
        return "";
    }

    // Devuelve `full` si cabe en `maxW` píxeles; si no, `short`.
    function fit(dc as Graphics.Dc, font as Graphics.FontType, full as String,
                 short as String, maxW as Number) as String {
        return (dc.getTextWidthInPixels(full, font) <= maxW) ? full : short;
    }

    // ---------------------------------------------------------------- regla

    // Estado del día `days` para la placa terminada en `digit`.
    // Las excepciones tienen prioridad sobre todo (incluso fines de semana y festivos).
    function status(days as Number, digit as Number, oddLow as Boolean) as Number {
        var exc = exceptions();
        if (exc != null) {
            var mask = exc.get(days);
            if (mask instanceof Number) {
                if (((mask >> digit) & 1) == 1) {
                    return PICO;
                }
                return (mask == 0) ? LEVANTADA : LIBRE;
            }
        }
        if (weekday(days) >= 5) {
            return FINDE;
        }
        var ymd = civilFromDays(days);
        if (isHoliday(days, ymd[0], ymd[1], ymd[2])) {
            return FESTIVO;
        }
        var low = digit >= 1 && digit <= 5;
        var odd = ymd[2] % 2 == 1;
        var circula = oddLow ? (low == odd) : (low != odd);
        return circula ? LIBRE : PICO;
    }
}
