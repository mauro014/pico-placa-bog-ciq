import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// La clase de entrada se carga en los tres procesos: app, glance y segundo plano.
// Las funciones que solo corren en primer plano desactivan el chequeo de ámbito,
// así la vista completa y el menú no se cargan en el glance ni en el servicio.
(:glance, :background)
class PicoPlacaApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        PicoSync.schedule(false);
        return [new PicoView(), new PicoDelegate()];
    }

    (:typecheck(disableBackgroundCheck))
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        PicoSync.schedule(false);
        return [new PicoGlanceView()];
    }

    (:typecheck(disableGlanceCheck))
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new PicoServiceDelegate()];
    }

    // El servicio terminó (con o sin datos nuevos en Storage).
    (:typecheck(disableBackgroundCheck))
    function onBackgroundData(data as Application.PersistableType) as Void {
        PicoLogic.resetCache();
        PicoSync.schedule(false);
        WatchUi.requestUpdate();
    }

    // El servicio escribió en Storage mientras la app estaba abierta.
    (:typecheck(disableBackgroundCheck))
    function onStorageChanged() as Void {
        PicoLogic.resetCache();
        WatchUi.requestUpdate();
    }

    // Cambios desde Garmin Connect en el celular
    (:typecheck(disableBackgroundCheck))
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
