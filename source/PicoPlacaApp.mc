import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class PicoPlacaApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new PicoView(), new PicoDelegate()];
    }

    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new PicoGlanceView()];
    }

    // Cambios desde Garmin Connect en el celular
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
