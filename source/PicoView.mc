import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Vista completa (solo primer plano; no se carga en el glance ni en segundo plano).
class PicoView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    private function dia(days as Number, es as Boolean) as String {
        var names = es
            ? ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
            : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        return (names as Array<String>)[PicoLogic.weekday(days)];
    }

    // Inicial del día para la fila de próximos días (X = miércoles en español).
    private function inicial(days as Number, es as Boolean) as String {
        return (es ? "LMXJVSD" : "MTWTFSS").substring(PicoLogic.weekday(days), PicoLogic.weekday(days) + 1) as String;
    }

    private function fecha(days as Number, es as Boolean) as String {
        var ymd = PicoLogic.civilFromDays(days);
        var months = es
            ? ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
            : ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return dia(days, es) + " " + ymd[2] + " " + (months as Array<String>)[ymd[1] - 1];
    }

    private function colorFor(st as Number) as Number {
        return (st == PicoLogic.PICO) ? PicoLogic.COLOR_PICO : PicoLogic.COLOR_LIBRE;
    }

    function onUpdate(dc as Dc) as Void {
        var es = PicoLogic.isEs();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var maxW = w * 86 / 100;
        var digit = PicoLogic.plateDigit();
        var oddLow = PicoLogic.oddDaysLow();
        var hoy = PicoLogic.today();
        var st = PicoLogic.status(hoy, digit, oddLow);
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Encabezado
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 12 / 100, Graphics.FONT_SMALL, (es ? "Placa " : "Plate ") + digit, center);
        dc.setColor(PicoLogic.COLOR_GRIS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 20 / 100, Graphics.FONT_XTINY, (es ? "HOY · " : "TODAY · ") + fecha(hoy, es), center);

        // Círculo grande con el estado de hoy
        var cy = h * 43 / 100;
        dc.setColor(colorFor(st), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, h * 18 / 100);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var circle;
        if (st == PicoLogic.PICO) {
            circle = es ? "NO\nSALGAS" : "DON'T\nDRIVE";
        } else {
            circle = es ? "PUEDES\nSALIR" : "OK TO\nDRIVE";
        }
        dc.drawText(cx, cy, Graphics.FONT_TINY, circle, center);

        // Horario / motivo
        var detalle;
        var corto;
        if (st == PicoLogic.PICO) {
            corto = es ? "6:00 a. m. – 9:00 p. m." : "6:00 AM – 9:00 PM";
            detalle = (es ? "Pico y placa " : "Restricted ") + corto;
        } else {
            corto = es ? "Sin pico y placa" : "No restriction";
            if (st == PicoLogic.LEVANTADA) {
                detalle = es ? "Medida levantada hoy" : "Restriction lifted today";
            } else if (st == PicoLogic.FESTIVO) {
                detalle = es ? "Festivo: sin pico y placa" : "Holiday: no restriction";
            } else if (st == PicoLogic.FINDE) {
                detalle = es ? "Fin de semana: sin pico y placa" : "Weekend: no restriction";
            } else {
                detalle = es ? "Hoy no tienes pico y placa" : "No restriction today";
            }
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 66 / 100, Graphics.FONT_XTINY,
            PicoLogic.fit(dc, Graphics.FONT_XTINY, detalle, corto, maxW), center);

        // Mañana
        var stM = PicoLogic.status(hoy + 1, digit, oddLow);
        var txtM;
        if (stM == PicoLogic.PICO) {
            txtM = es ? "Mañana: no salgas" : "Tomorrow: don't drive";
        } else {
            txtM = es ? "Mañana: puedes salir" : "Tomorrow: OK to drive";
        }
        var whyM = PicoLogic.reason(stM, es);
        if (whyM.length() > 0) {
            txtM = PicoLogic.fit(dc, Graphics.FONT_XTINY, txtM + " (" + whyM + ")", txtM, maxW);
        }
        dc.setColor(colorFor(stM), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 725 / 1000, Graphics.FONT_XTINY, txtM, center);

        // Próximos 5 días hábiles después de mañana
        var n = 5;
        var paso = w * 12 / 100;
        var x0 = cx - paso * (n - 1) / 2;
        var dr = h * 45 / 1000;
        var d = hoy + 1;
        for (var i = 0; i < n; i++) {
            d += 1;
            var sd = PicoLogic.status(d, digit, oddLow);
            while (sd == PicoLogic.FINDE || sd == PicoLogic.FESTIVO) {
                d += 1;
                sd = PicoLogic.status(d, digit, oddLow);
            }
            var x = x0 + i * paso;
            dc.setColor(PicoLogic.COLOR_GRIS, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, h * 79 / 100, Graphics.FONT_XTINY, inicial(d, es), center);
            dc.setColor(colorFor(sd), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, h * 86 / 100, dr);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, h * 86 / 100, Graphics.FONT_XTINY, PicoLogic.civilFromDays(d)[2].toString(), center);
        }
    }
}
