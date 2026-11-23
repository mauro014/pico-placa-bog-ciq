import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Menú de ajustes en el reloj (START en la vista completa).
// Las clases llevan (:glance) solo porque PicoPlacaApp (cargada siempre en modo
// glance) las referencia a través de getInitialView; nunca se instancian en el glance.

(:glance)
module PicoMenu {

    function endsIn(digit as Number, es as Boolean) as String {
        return (es ? "Termina en " : "Ends in ") + digit;
    }

    function languageName(l as Number, es as Boolean) as String {
        if (l == 1) {
            return "English";
        } else if (l == 2) {
            return "Español";
        }
        return es ? "Automático" : "Auto";
    }

    function open() as Void {
        var es = PicoLogic.isEs();
        var menu = new WatchUi.Menu2({:title => es ? "Ajustes" : "Settings"});
        menu.addItem(new WatchUi.MenuItem(es ? "Placa" : "Plate",
            endsIn(PicoLogic.plateDigit(), es), :digit, null));
        menu.addItem(new WatchUi.ToggleMenuItem(es ? "Rotación" : "Rotation",
            es ? {:enabled => "Impares: 1–5 · Pares: 6–0", :disabled => "Impares: 6–0 · Pares: 1–5"}
               : {:enabled => "Odd: 1–5 · Even: 6–0", :disabled => "Odd: 6–0 · Even: 1–5"},
            :oddLow, PicoLogic.oddDaysLow(), null));
        menu.addItem(new WatchUi.MenuItem(es ? "Idioma" : "Language",
            languageName(PicoLogic.language(), es), :lang, null));
        WatchUi.pushView(menu, new PicoSettingsDelegate(), WatchUi.SLIDE_LEFT);
    }
}

// Delegado de la vista completa: START / toque / MENU abren los ajustes.
(:glance)
class PicoDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        PicoMenu.open();
        return true;
    }

    function onMenu() as Boolean {
        PicoMenu.open();
        return true;
    }
}

// Menú principal de ajustes.
(:glance)
class PicoSettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var es = PicoLogic.isEs();
        var id = item.getId();
        if (item instanceof WatchUi.ToggleMenuItem) {
            Properties.setValue("oddDaysLow", item.isEnabled());
            WatchUi.requestUpdate();
        } else if (id == :digit) {
            var menu = new WatchUi.Menu2({:title => es ? "Placa termina en" : "Plate ends in"});
            for (var i = 0; i <= 9; i++) {
                menu.addItem(new WatchUi.MenuItem(i.toString(), null, i, null));
            }
            menu.setFocus(PicoLogic.plateDigit());
            WatchUi.pushView(menu, new PicoDigitDelegate(item), WatchUi.SLIDE_LEFT);
        } else if (id == :lang) {
            var menu = new WatchUi.Menu2({:title => es ? "Idioma" : "Language"});
            for (var l = 0; l <= 2; l++) {
                menu.addItem(new WatchUi.MenuItem(PicoMenu.languageName(l, es), null, l, null));
            }
            menu.setFocus(PicoLogic.language());
            WatchUi.pushView(menu, new PicoLanguageDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

// Lista de dígitos 0–9.
(:glance)
class PicoDigitDelegate extends WatchUi.Menu2InputDelegate {

    private var _parent as WatchUi.MenuItem;

    function initialize(parent as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _parent = parent;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var digit = item.getId() as Number;
        Properties.setValue("plateDigit", digit);
        _parent.setSubLabel(PicoMenu.endsIn(digit, PicoLogic.isEs()));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// Lista de idiomas: al elegir, vuelve a la vista completa ya traducida.
(:glance)
class PicoLanguageDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Properties.setValue("language", item.getId() as Number);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);   // lista de idiomas
        WatchUi.popView(WatchUi.SLIDE_RIGHT);       // menú de ajustes
        WatchUi.requestUpdate();
    }
}
