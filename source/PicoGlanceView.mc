import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance mínimo: "Placa 3" / "Plate 3" + qué hacer hoy, con color.
(:glance)
class PicoGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var es = PicoLogic.isEs();
        var digit = PicoLogic.plateDigit();
        var st = PicoLogic.status(PicoLogic.today(), digit, PicoLogic.oddDaysLow());
        var h = dc.getHeight();
        var w = dc.getWidth();
        var font = Graphics.FONT_TINY;
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h / 4, font, (es ? "Placa " : "Plate ") + digit, just);

        // Barra indicadora en el medio (roja o verde), visible al pasar por la lista
        var color = (st == PicoLogic.PICO) ? PicoLogic.COLOR_PICO : PicoLogic.COLOR_LIBRE;
        var t = h / 16;
        if (t < 4) {
            t = 4;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(0, h / 2 - t / 2, w * 9 / 10, t, t / 2);

        var txt;
        if (st == PicoLogic.PICO) {
            dc.setColor(PicoLogic.COLOR_PICO, Graphics.COLOR_TRANSPARENT);
            txt = es ? "NO SALGAS" : "DON'T DRIVE";
            txt = PicoLogic.fit(dc, font, txt + " 6am–9pm", txt, w);
        } else {
            dc.setColor(PicoLogic.COLOR_LIBRE, Graphics.COLOR_TRANSPARENT);
            txt = es ? "PUEDES SALIR" : "OK TO DRIVE";
            var why = PicoLogic.reason(st, es);
            if (why.length() > 0) {
                txt = PicoLogic.fit(dc, font, txt + " · " + why, txt, w);
            }
        }
        dc.drawText(0, h * 3 / 4, font, txt, just);
    }
}
