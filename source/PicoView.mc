import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Vista completa. Lleva (:glance) solo porque la clase App (que siempre se carga
// en modo glance) la referencia en getInitialView; nunca se instancia en el glance.
(:glance)
class PicoView extends WatchUi.View {

    private function dia(days as Number) as String {
        return (["lun", "mar", "mié", "jue", "vie", "sáb", "dom"] as Array<String>)[PicoLogic.weekday(days)];
    }

    function initialize() {
        View.initialize();
    }

    private function colorFor(st as Number) as Number {
        return (st == PicoLogic.PICO) ? PicoLogic.COLOR_PICO : PicoLogic.COLOR_LIBRE;
    }

    private function fecha(days as Number) as String {
        var ymd = PicoLogic.civilFromDays(days);
        var meses = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"] as Array<String>;
        return dia(days) + " " + ymd[2] + " " + meses[ymd[1] - 1];
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var digit = PicoLogic.plateDigit();
        var oddLow = PicoLogic.oddDaysLow();
        var hoy = PicoLogic.today();
        var st = PicoLogic.status(hoy, digit, oddLow);
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Encabezado
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 12 / 100, Graphics.FONT_SMALL, "Placa " + digit, center);
        dc.setColor(PicoLogic.COLOR_GRIS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 20 / 100, Graphics.FONT_XTINY, "HOY · " + fecha(hoy), center);

        // Círculo grande con el estado de hoy
        var cy = h * 43 / 100;
        var r = h * 18 / 100;
        dc.setColor(colorFor(st), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_TINY,
            (st == PicoLogic.PICO) ? "NO\nSALGAS" : "PUEDES\nSALIR", center);

        // Horario / motivo
        var detalle = "Hoy no tienes pico y placa";
        if (st == PicoLogic.PICO) {
            detalle = "Pico y placa 6:00 a. m. – 9:00 p. m.";
        } else if (st == PicoLogic.FESTIVO) {
            detalle = "Festivo: sin pico y placa";
        } else if (st == PicoLogic.FINDE) {
            detalle = "Fin de semana: sin pico y placa";
        }
        detalle = PicoLogic.fit(dc, Graphics.FONT_XTINY, detalle,
            (st == PicoLogic.PICO) ? "6:00 a. m. – 9:00 p. m." : "Sin pico y placa", w * 86 / 100);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 66 / 100, Graphics.FONT_XTINY, detalle, center);

        // Mañana
        var stM = PicoLogic.status(hoy + 1, digit, oddLow);
        dc.setColor(colorFor(stM), Graphics.COLOR_TRANSPARENT);
        var txtM = (stM == PicoLogic.PICO) ? "Mañana: no salgas" : "Mañana: puedes salir";
        var whyM = PicoLogic.reason(stM);
        if (whyM.length() > 0) {
            txtM = PicoLogic.fit(dc, Graphics.FONT_XTINY, txtM + " (" + whyM + ")", txtM, w * 86 / 100);
        }
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
            dc.drawText(x, h * 79 / 100, Graphics.FONT_XTINY, dia(d), center);
            dc.setColor(colorFor(sd), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, h * 86 / 100, dr);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, h * 86 / 100, Graphics.FONT_XTINY, PicoLogic.civilFromDays(d)[2].toString(), center);
        }
    }
}
