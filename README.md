# Pico y Placa Bogotá — Garmin Forerunner 965

Widget Connect IQ que muestra de un vistazo si tu carro tiene pico y placa **hoy** en Bogotá.

- **Glance** (lista de glances del reloj): `Placa 3` + qué hacer hoy:
  - **NO SALGAS 6am–9pm** (rojo): tu placa tiene pico y placa hoy.
  - **PUEDES SALIR** (verde): hoy no tienes pico y placa. Si es fin de semana o festivo, lo indica.
- **Vista completa** (al abrir el glance): círculo grande con el estado de hoy, horario,
  estado de mañana y de los próximos 5 días hábiles.
- 100 % offline: sin permisos, sin internet, sin servicio en segundo plano.

## Regla implementada (particulares, 2026)

- Lunes a viernes, 6:00 a. m. a 9:00 p. m.
- Días impares: circulan las placas terminadas en 1–5 (pico y placa para 6, 7, 8, 9, 0).
- Días pares: circulan 6–0 (pico y placa para 1–5).
- No aplica sábados, domingos ni festivos. No se tiene en cuenta el pico y placa regional.
- Los festivos de Colombia se calculan en el reloj para cualquier año: fijos, Ley Emiliani
  y los que dependen de la Pascua.

## Estructura

| Archivo | Contenido |
|---|---|
| `source/PicoLogic.mc` | Fechas (days_from_civil), Pascua, festivos y regla (`(:glance)`) |
| `source/PicoGlanceView.mc` | Vista glance |
| `source/PicoView.mc` | Vista completa |
| `resources/settings/` | Ajustes editables desde Garmin Connect |
| `tools/validate.py` | Misma lógica en Python, con pruebas de 2025–2027 |

## Compilar

Requisitos: Connect IQ SDK (vía SDK Manager), perfil del **Forerunner 965** y Java 17+.

```powershell
# Validar la lógica primero
python tools/validate.py

# SDK actual (ver %APPDATA%\Garmin\ConnectIQ\current-sdk.cfg)
$sdk = "$env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.3.0-2026-10-20-95888f262\bin"

& "$sdk\monkeyc.bat" -d fr965 -f monkey.jungle -o bin/PicoPlaca.prg -y developer_key -l 2
```

La llave `developer_key` no está en git (`.gitignore`). Si no existe, créala:

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt
```

**Importante:** guarda una copia de la llave. Para actualizar la app en el reloj hay que firmar
con la misma llave.

## Probar en el simulador

```powershell
& "$sdk\connectiq.bat"                     # abre el simulador
& "$sdk\monkeydo.bat" bin\PicoPlaca.prg fr965
```

En el simulador, el widget arranca en modo glance. Presiona START (o haz clic en el glance)
para abrir la vista completa. Los ajustes se cambian en *File → Edit Persistent Storage →
Edit Application.Properties data*. Para probar otras fechas usa *Settings → Time*.

## Instalar en el reloj (USB)

1. Conecta el FR965 al PC con el cable USB.
2. Copia `bin/PicoPlaca.prg` a la carpeta `GARMIN/APPS/` del reloj.
3. Desconecta el reloj. El widget aparece en la lista de glances; si no, agrégalo desde
   *Ajustes → Glances*.

> Las apps instaladas por USB (*sideload*) no aparecen en la tienda Connect IQ. Para que los
> ajustes salgan en el celular, ver la nota de abajo.

## Cambiar la placa desde Garmin Connect

En la app **Garmin Connect** del celular: *Dispositivos → Forerunner 965 → Actividades, apps y más →
Glances / Widgets → Pico y Placa → Ajustes*.

- **Último dígito de la placa**: 0–9.
- **Días impares circulan placas 1–5**: activado por defecto. Desactívalo si la Secretaría de
  Movilidad invierte la rotación (no hay que recompilar).

El reloj aplica el cambio de inmediato (`onSettingsChanged`).

Nota: Garmin Connect solo muestra ajustes de apps instaladas desde la tienda Connect IQ (o
subidas como beta privada). Con una instalación por USB, los valores por defecto están en
`resources/settings/properties.xml` (placa 3). Puedes cambiarlos ahí y recompilar.

## Versión 2 (pendiente)

- Un archivo JSON de **excepciones** alojado gratis en GitHub Pages (días en que la Alcaldía
  levanta la medida, cambios de regla u horario), por ejemplo:
  ```json
  { "version": 1, "libres": ["2026-12-24"], "oddDaysLow": true }
  ```
- Un servicio en segundo plano (`(:background)`, `Background.registerForTemporalEvent`) que lo
  descargue una vez al día con `Communications.makeWebRequest` y lo guarde en `Application.Storage`.
- La lógica consultaría esas excepciones antes de aplicar la regla general.
- Requiere los permisos `Background` y `Communications` en el manifest. Hay que vigilar el
  límite de 64 KB del proceso en segundo plano.
