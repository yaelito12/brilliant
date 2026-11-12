# Brilliant

Juego de tablero en Flutter con cuentas de usuario.

- **App (Flutter)**: carpeta raíz. Pantallas de crear cuenta, iniciar sesión, cerrar sesión y borrar cuenta.
- **Servidor (Dart)**: proyecto aparte en la carpeta hermana `../brilliant_server/` (ver su `README.md`). Ahí se registran los clientes y se juegan las partidas multijugador.
- **Reglas del juego (Dart puro)**: carpeta [`packages/brilliant_reglas/`](packages/brilliant_reglas/). Tipos de zona, tablero, niveles y reglas de cada turno; las usa la app, y el servidor tiene una copia en `brilliant_server/packages/brilliant_reglas` para validar las jugadas con el mismo código. Si cambian las reglas, hay que copiarlas allá también.

## Cómo iniciarlo (Windows, paso a paso)

Lo que hace falta: **Flutter** instalado y en el PATH (trae Dart adentro) y
**Chrome**. Para jugar desde un teléfono no hace falta nada más (se puede entrar
por el navegador; ver el paso 5).

Las dos carpetas tienen que quedar una al lado de la otra, porque la app busca
al servidor como carpeta hermana:

```
Brilliant\
  brilliant\          <- la app (esta carpeta)
  brilliant_server\   <- el servidor
```

**1. Preparar el servidor (una sola vez).** En PowerShell:

```powershell
cd ..\brilliant_server
dart pub get
copy .env.example .env
dart run bin/gen_secret.dart
```

El último comando imprime una clave larga: hay que pegarla en el archivo `.env`,
en la línea `JWT_SECRET=` (queda `JWT_SECRET=<la clave>`). El `.env` no viene en
el repositorio porque guarda ese secreto. La base de datos se crea sola en
`brilliant_server/data/` al arrancar.

**2. Jugar: doble clic en `Jugar.bat`** (está en esta carpeta). Eso solo:

- arranca el servidor en una ventana aparte (la primera vez lo compila),
- sirve el juego en la red local,
- abre el navegador en `http://localhost:5000` cuando está listo.

**La primera vez tarda varios minutos** compilando; no hay que cerrar nada
mientras tanto. Si Windows pregunta por el Firewall, hay que permitir el acceso.

**3. Crear una cuenta** (nametag y contraseña) y ya se puede jugar solo, o entrar
a **Jugar en línea** para una partida con otras personas.

**4. Jugar entre varias computadoras.** Todas tienen que estar en la misma red
Wi‑Fi o cable que la PC que abrió `Jugar.bat`. Esa ventana muestra la dirección
que hay que abrir en las demás, por ejemplo `http://192.168.1.9:5000`. Si el
Firewall las bloquea, en la PC del servidor hay que correr una sola vez, en
PowerShell **como administrador**:

```powershell
New-NetFirewallRule -DisplayName "Brilliant" -Direction Inbound -Protocol TCP -LocalPort 3000,5000 -Action Allow
```

**5. Jugar desde un teléfono Android.** La app ya compilada está en
[`instalador/Brilliant.apk`](instalador/Brilliant.apk): se pasa el archivo al
teléfono (por cable, o se descarga desde GitHub) y se toca para instalar. La
primera vez Android pide permitir instalar apps desde esa fuente.

Al abrirla pide la **dirección del servidor**: se escribe la que muestra la
ventana del servidor, algo como `192.168.1.9:3000`. Queda guardada, y se puede
cambiar después desde el menú de la cuenta → "Servidor".

Sin instalar nada también se puede jugar: abrir `http://192.168.1.9:5000` en el
navegador del teléfono (la misma dirección del paso 4).

Para regenerar el `.apk` después de cambiar algo:

```powershell
flutter build apk --release
copy build\app\outputs\flutter-apk\app-release.apk instalador\Brilliant.apk
```

**6. Para cerrar todo**: se cierran las dos ventanas negras (la del servidor y la
del juego).

### Si algo no arranca

| Qué se ve | Qué pasa |
|---|---|
| `flutter no se reconoce...` | Flutter no está instalado o no está en el PATH. |
| `Falta el archivo .env` | Falta el paso 1. |
| `No se pudo conectar con el servidor` | La ventana del servidor está cerrada, o el teléfono/la otra PC no están en la misma red. |
| El juego se ve viejo (mapas o avisos que ya cambiaron) | El navegador guardó una copia: recargar con `Ctrl+F5`. |
| Otra PC no carga la página | Es el Firewall: ver el paso 4. |

## Cómo ejecutarlo a mano (desarrollo)

1. Servidor (ver `../brilliant_server/README.md` para el detalle):
   ```bash
   cd ../brilliant_server && dart pub get && cp .env.example .env
   dart run bin/gen_secret.dart   # pega el resultado en JWT_SECRET dentro de .env
   dart run bin/server.dart       # http://localhost:3000
   ```
2. App:
   ```bash
   flutter pub get
   flutter run                                                   # escritorio / web / iOS simulator
   flutter build apk --release                                   # Android (la app pregunta la dirección)
   flutter run --dart-define=API_URL=https://api.tudominio.com    # producción (HTTPS)
   ```

### Dónde busca la app el servidor

- **Web**: en el mismo equipo que sirvió la página, puerto 3000. No hay nada que configurar.
- **Escritorio**: `localhost:3000`, y se puede cambiar.
- **Android / iOS**: la app **pregunta la dirección** la primera vez (pantalla
  "Servidor") y la guarda en el teléfono. Se escribe la IP de la PC donde corre
  el servidor, por ejemplo `192.168.1.9` (si no se pone puerto, se usa el 3000);
  esa misma IP la imprime la ventana del servidor al arrancar. El botón "Probar y
  guardar" comprueba que el servidor conteste antes de guardarla. Después se
  cambia desde el menú de la cuenta → "Servidor", o desde el inicio de sesión.
  Al cambiar de servidor se cierra la sesión, porque la cuenta era del otro.
- `--dart-define=API_URL=...` sigue sirviendo para fijar la dirección al
  compilar (producción). En el teléfono, lo que se escriba a mano manda sobre ella.

Si la app dice "No se pudo conectar con el servidor" desde el teléfono: que el
teléfono esté en la misma red Wi‑Fi que la PC (no con datos móviles), que la
ventana del servidor esté abierta y que la dirección sea la IP actual de la PC
(cambia cuando el router la reasigna).

## Jugar en línea

Con la sesión iniciada, en el menú aparece **Jugar en línea**: se crea una sala (o se entra con
un código de 6 letras). Todos juegan el mismo mapa: lo elige quien crea la sala, y solo esa
persona lo puede cambiar. La partida empieza cuando todos (2 a 6) pulsan "Estoy listo". Si se corta la conexión, la app reconecta sola y vuelve a la sala.

En la partida cada uno juega **su propio tablero con los mismos dados**: pone sus 6 números
iniciales (se toca una casilla y luego el número) y en cada ronda coloca un número o pasa (60 s por ronda). El marcador muestra los puntos
y qué está haciendo cada jugador; tocando a alguien se ve su tablero. Se puede **rendir** en
cualquier momento. Al terminar aparecen los resultados y, si todos vuelven a pulsar "listo",
empieza la revancha.

Solo se puede tener **una sesión abierta por cuenta**: si la cuenta está abierta en otro
dispositivo, no deja entrar hasta que se cierre sesión allí. Si ese dispositivo se cerró sin salir
(o se perdió), la cuenta se libera sola en unos 2,5 minutos.

Para probarlo en una sola computadora, con **cuentas distintas** en Chrome y Edge:

```bash
# brilliant_server/.env:  CORS_ORIGINS=http://localhost:5000,http://localhost:5001
cd ../brilliant_server && dart run bin/server.dart   # terminal 1
flutter run -d chrome --web-port 5000            # terminal 2
flutter run -d edge --web-port 5001              # terminal 3
```

Detalles del protocolo en `../brilliant_server/MULTIJUGADOR.md`.

## Pruebas

```bash
cd ../brilliant_server && dart test   # servidor (proyecto aparte): 77 pruebas
cd packages/brilliant_reglas && dart test   # reglas del juego: 12 pruebas
flutter test              # app: incluye test/auth/
```

## Cómo se guarda la sesión en la app

- El *access token* (15 min) vive solo en memoria.
- El *refresh token* se guarda con `flutter_secure_storage` (Keychain / Keystore) y se
  usa para continuar la sesión al reabrir la app. Cada uso lo rota el servidor.
- La contraseña nunca se guarda en el dispositivo.
