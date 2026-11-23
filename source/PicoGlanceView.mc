import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance mínimo: "Placa 7" + estado de hoy con color.
(:glance)
class PicoGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var digit = PicoLogic.plateDigit();
        var st = PicoLogic.status(PicoLogic.today(), digit, PicoLogic.oddDaysLow());
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h / 4, Graphics.FONT_TINY, "Placa " + digit,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var txt;
        if (st == PicoLogic.PICO) {
            dc.setColor(PicoLogic.COLOR_PICO, Graphics.COLOR_TRANSPARENT);
            txt = PicoLogic.fit(dc, Graphics.FONT_TINY, "NO SALGAS 6am–9pm", "NO SALGAS", dc.getWidth());
        } else {
            dc.setColor(PicoLogic.COLOR_LIBRE, Graphics.COLOR_TRANSPARENT);
            var why = PicoLogic.reason(st);
            txt = (why.length() == 0) ? "PUEDES SALIR"
                : PicoLogic.fit(dc, Graphics.FONT_TINY, "PUEDES SALIR · " + why, "PUEDES SALIR", dc.getWidth());
        }
        dc.drawText(0, h * 3 / 4, Graphics.FONT_TINY, txt,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
