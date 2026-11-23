import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Versión 2: descarga diaria del JSON de excepciones (GitHub Pages).
//
// Formato (ver docs/exceptions.json y README):
//   { "version": 1, "updated": "AAAA-MM-DD",
//     "exceptions": [ { "date": "AAAA-MM-DD", "pico": [6, 7, 8, 9, 0], "note": "..." } ] }
// "pico" = dígitos CON restricción ese día; [] = la Alcaldía levantó la medida.
//
// El servicio guarda en Storage (permitido en segundo plano desde CIQ 3.2):
//   "exc"    => {días desde 1970 => máscara de dígitos}   (solo desde ayer, máx. 60)
//   "syncOk" => segundos epoch de la última descarga correcta
//   "syncAt" => segundos epoch del último intento
// y la app se entera por onStorageChanged / onBackgroundData.

(:background)
class PicoServiceDelegate extends System.ServiceDelegate {

    const URL = "https://mauro014.github.io/pico-placa-bog-ciq/exceptions.json";
    const MAX_EXC = 60;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        Storage.setValue("syncAt", Time.now().value());
        Communications.makeWebRequest(URL, null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        var ok = false;
        if (code == 200 && data instanceof Dictionary) {
            Storage.setValue("exc", compact(data));
            Storage.setValue("syncOk", Time.now().value());
            ok = true;
        }
        Background.exit(ok);
    }

    private function num(s as String, a as Number, b as Number) as Number? {
        var t = s.substring(a, b);
        return (t == null) ? null : t.toNumber();
    }

    // "AAAA-MM-DD" -> días desde 1970, o null si no es válido.
    private function parseDate(s as String) as Number? {
        if (s.length() != 10) {
            return null;
        }
        var y = num(s, 0, 4);
        var m = num(s, 5, 7);
        var d = num(s, 8, 10);
        if (y == null || m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) {
            return null;
        }
        return PicoLogic.daysFromCivil(y, m, d);
    }

    // JSON -> {días => máscara}. Igual que compact() en tools/validate.py.
    private function compact(data as Dictionary) as Dictionary<Storage.KeyType, Storage.ValueType> {
        var res = {} as Dictionary<Storage.KeyType, Storage.ValueType>;
        var items = data.get("exceptions");
        if (!(items instanceof Array)) {
            return res;
        }
        var desde = PicoLogic.today() - 1;
        for (var i = 0; i < items.size(); i++) {
            var it = items[i];
            if (!(it instanceof Dictionary)) {
                continue;
            }
            var date = it.get("date");
            var pico = it.get("pico");
            if (!(date instanceof String) || !(pico instanceof Array)) {
                continue;
            }
            var days = parseDate(date);
            if (days == null || days < desde) {
                continue;
            }
            var mask = 0;
            for (var j = 0; j < pico.size(); j++) {
                var dg = pico[j];
                if (dg instanceof Number && dg >= 0 && dg <= 9) {
                    mask |= 1 << dg;
                }
            }
            res.put(days, mask);
            if (res.size() >= MAX_EXC) {
                break;
            }
        }
        return res;
    }
}

// Programa la próxima descarga (se llama al abrir el glance o la app).
(:glance)
module PicoSync {

    const DAY = 86400;    // una descarga correcta al día
    const RETRY = 3600;   // si falla (sin celular, sin internet), reintenta cada hora

    // force = true: descargar ya (desde el menú).
    function schedule(force as Boolean) as Void {
        var now = Time.now().value();
        var next = now;
        if (!force) {
            var ok = Storage.getValue("syncOk");
            var at = Storage.getValue("syncAt");
            if (ok instanceof Number) {
                next = ok + DAY;
            }
            if (at instanceof Number && at + RETRY > next) {
                next = at + RETRY;
            }
            if (next < now) {
                next = now;
            }
        }
        try {
            Background.registerForTemporalEvent(new Time.Moment(next));
        } catch (e) {
            // Menos de 5 minutos desde el último evento: se intentará la próxima vez.
        }
    }
}
