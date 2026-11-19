# Guía de ejecución y lectura — Gatling

Esta guía es para correr las pruebas de Eowyn Library desde PowerShell y entender qué mide cada perfil. La automatización está bajo `performance/gatling/`; no modifica la lógica de la API.

## Ejecución completa en un comando

Después de configurar `.env` una vez, abre PowerShell en la raíz del repositorio y ejecuta:

```powershell
.\performance\gatling\scripts\run-full-api.ps1
```

El script lee la URL `host` del environment Postman local, levanta PostgreSQL, aplica las migraciones, instala dependencias Node si faltan, inicia la API si no responde, ejecuta las 13 rutas con un usuario virtual y limpia los datos generados. Para ajustar concurrencia hasta 20 usuarios, añade `-WriteUsers 5` al comando. Si el script tuvo que arrancar la API, la deja ejecutándose; los logs quedan bajo `performance/gatling/target/` y el reporte Gatling se genera en `performance/gatling/target/gatling/`.

Requisitos ya instalados en el equipo: Docker Desktop, Node.js, Java 17 o posterior y Maven. El `.env` debe existir y contener la configuración local de PostgreSQL. La contraseña default del usuario seed puede cambiarse pasando `-TestEmail` y `-TestPassword` al script.

## 1. Archivos importantes

| Archivo | Para qué sirve |
|---|---|
| `pom.xml` | Dependencias y compilación Maven de Scala, Karate-Gatling y Gatling HTTP |
| `src/test/java/features/catalog.feature` | Flujo Karate: login, extraer JWT, consultar categorías y libros; verifica respuestas |
| `src/test/java/features/full-api-lifecycle.feature` | Recorrido con datos aislados: registro/login, validación de email, categorías, libros y préstamos |
| `src/test/scala/performance/EowynCatalogSimulation.scala` | Smoke basado en Karate-Gatling |
| `src/test/scala/performance/EowynFullApiSimulation.scala` | Cobertura de las 13 rutas; opt-in obligatorio porque crea datos |
| `src/test/scala/performance/EowynLoadSimulation.scala` | Carga por tasa con DSL HTTP directa de Gatling |
| `src/test/scala/performance/EowynStressSimulation.scala` | Estrés por usuarios concurrentes con Karate-Gatling |
| `src/test/java/karate-config.js` | Lee `BASE_URL`, `TEST_EMAIL`, `TEST_PASSWORD` para las features Karate |
| `src/test/java/gatling-akka.conf` | Aumenta el pool de hilos para los perfiles que ejecutan Karate-Gatling |
| `scripts/sample-local-resources.ps1` | Muestrea CPU y memoria del proceso Node y del contenedor PostgreSQL |
| `scripts/cleanup-gatling-fixtures.sql` | Elimina solo los datos creados por el recorrido full API |
| `../../informe-performance.md` | Perfil usado, resultados reales y límites de interpretación |

## 2. Preparar o arrancar la API

Ya se creó `.env` local y se instalaron las dependencias npm. El `.env` está ignorado por Git. Su configuración apunta a la API en `localhost:3000` y PostgreSQL en el puerto host `5433` (el contenedor escucha dentro en `5432`). No reemplaces el `.env` por el template vacío sin volver a completar sus valores.

Si los servicios no están activos, abre una consola PowerShell en la raíz del repositorio:

```powershell
docker compose up -d postgres-db
npm run migrate:latest
npm run dev
```

Deja `npm run dev` ejecutándose en esa consola. Las migraciones crean las tablas y datos iniciales. Entre ellos existe `admin@example.com` con contraseña local `123456`; son credenciales de desarrollo del seed y no deben usarse fuera de la máquina local.

Si ya aplicaste las migraciones y la API está ejecutándose, no inicies otra copia. El usuario de la API y la contraseña de PostgreSQL que aparecen en `.env` son distintos de `TEST_EMAIL` y `TEST_PASSWORD`, que se usan para iniciar sesión en el escenario.

## 3. Ejecutar una simulación

En otra consola PowerShell, desde la raíz del repositorio:

```powershell
$env:BASE_URL = 'http://localhost:3000'
$env:TEST_EMAIL = 'admin@example.com'
$env:TEST_PASSWORD = '123456'
Set-Location .\performance\gatling
```

### Recorrido de todas las APIs

El recorrido registra un usuario nuevo, así que crea una cuenta persistente además de una categoría, un libro y un préstamo temporales. Usa una base de datos local/desechable. Por defecto simula un usuario; el máximo permitido es 20. Ejecuta primero esta simulación cuando quieras evaluar las rutas con escritura:

```powershell
$env:ENABLE_WRITE_TESTS = 'true'
$env:WRITE_TEST_USERS = '1' # se puede subir hasta 20 en una BD de pruebas
mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynFullApiSimulation'
Remove-Item Env:ENABLE_WRITE_TESTS
```

Cada usuario crea sus propios datos con nombres, ISBN y correo únicos. El orden del ciclo evita conflictos de claves foráneas: al final se devuelve el préstamo y se borran el libro y la categoría. La cuenta no se puede borrar por API; limpia las cuentas `gatling-e2e-*` y sus datos asociados desde la raíz del repositorio:

```powershell
Get-Content .\performance\gatling\scripts\cleanup-gatling-fixtures.sql -Raw | docker compose exec -T postgres-db psql -U gandalf -d eowyn-library
```

La colección Postman incluye cuerpos y rutas de ejemplo, pero algunos IDs y fechas son estáticos o ya no válidos. El escenario Gatling genera sus propios valores para que cada ejecución tenga datos válidos y únicos. No uses la simulación de escritura sobre QA compartido o producción.

Ejecuta **un perfil a la vez**:

```powershell
# Smoke: comprueba autenticación y lecturas con carga mínima
mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynCatalogSimulation'

# Carga por tasa: mide throughput y respuesta con solicitudes continuas
mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynLoadSimulation'

# Estrés por concurrencia: escala sesiones hasta 125 usuarios
mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynStressSimulation'
```

Requisitos para el módulo Gatling: Java 17 o posterior y Maven. El entorno usado para los resultados de este informe fue Java 21 y Maven 3.9.15.

## 4. Qué prueba cada perfil y por qué

### Cobertura funcional de APIs — `EowynFullApiSimulation`

Una ejecución cubre todas las rutas: `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/validate-email/:token`, `POST/GET/PUT/DELETE /api/categories`, `POST/GET/PUT/DELETE /api/books` y `POST /api/loans` más `PUT /api/loans/:id/return`. Usa un usuario registrado en el escenario, extrae el JWT del login y lo envía en las rutas protegidas. Crea categoría y libro únicos, presta y devuelve ese libro, y después borra libro y categoría. El reporte Gatling tendrá una serie por request.

El perfil utiliza un usuario virtual por defecto para cubrir las rutas sin producir una tasa alta de escrituras ni acumular muchos registros. El correo de registro queda persistido porque la aplicación no ofrece eliminación de usuarios; el script SQL elimina solo cuentas con prefijo reservado y sus fixtures. Para medir carga sostenida de escrituras, ejecutar el mismo flujo contra una base aislada y aumentar `WRITE_TEST_USERS` de manera controlada, limpiando tras la prueba.

### Smoke — `EowynCatalogSimulation`

Llama el feature Karate. Cada usuario virtual:

1. Envía `POST /api/auth/login` con formulario y comprueba HTTP 200 y que el JWT sea texto.
2. Usa ese JWT en `GET /api/categories?page=1&limit=50`; comprueba HTTP 200 y que `categories` sea una lista.
3. Usa el mismo JWT en `GET /api/books?page=1&limit=30`; comprueba HTTP 200 y que `books` sea una lista.

Se hace primero para comprobar que la API, autenticación, datos y configuración funcionan antes de someterlas a carga. No crea ni borra datos.

### Carga por tasa — `EowynLoadSimulation`

Usa Gatling HTTP directamente. La rampa sube de 0 a 20 flujos de usuario por segundo en 30 segundos y mantiene 20 flujos/s durante 60 segundos. Cada flujo contiene tres requests (login, categorías y libros) y termina con 5 segundos de pausa. La tasa ofrecida puede alcanzar 60 requests/s.

Es un **modelo abierto**: fija cuántos flujos nuevos intenta iniciar, y la concurrencia observada aumenta si las respuestas tardan. En la corrida informada empezó 1,500 flujos, registró un máximo de 769 usuarios activos y produjo 41.426 req/s. El promedio de respuesta fue 6.928 ms y el p95 19.510 ms, con cero fallos HTTP. Eso describe degradación de latencia local al sostener esa tasa; no significa que el template sea un requisito incumplido.

Se usa HTTP directo para separar la tasa que puede generar Gatling del límite que la integración Karate-Gatling documenta para su configuración predeterminada. La automatización funcional equivalente se valida en el smoke Karate.

### Estrés por concurrencia — `EowynStressSimulation`

Reutiliza el mismo feature Karate, con una pausa de 12 segundos después de cada flujo. La rampa mantiene niveles de 25, 50, 75, 100 y 125 usuarios concurrentes, con 15 segundos en cada nivel y rampas de 10 segundos.

Este perfil responde cómo se comportan sesiones concurrentes cuando el usuario lee el catálogo. La pausa representa tiempo de lectura y hace que su throughput sea menor que el perfil de carga por tasa. En la corrida informada llegó a 125 usuarios, completó 2,295 requests sin fallos HTTP, con media 225 ms y p95 764 ms; observó 16.752 req/s.

## 5. Qué significan las métricas

- **Tiempo de respuesta:** duración de un request HTTP individual. El reporte separa media, mediana y percentiles (p95/p99); el p95 indica que el 95% de requests respondió en ese tiempo o menos.
- **Throughput:** requests completados por segundo durante la ventana medida. No es lo mismo que flujos de usuario por segundo; cada flujo aquí envía tres requests.
- **Fallos:** requests que no cumplieron el status/check configurado. Un p95 alto puede coexistir con 0 fallos HTTP: el servicio todavía responde, pero tarda mucho.
- **Usuarios activos:** virtual users ejecutando o esperando dentro del escenario. En el modelo abierto dependen de la latencia; no son un límite fijo.
- **CPU/memoria:** el muestreador externo registra recursos del proceso Node que escucha en el puerto 3000 y del contenedor PostgreSQL. Gatling no los deduce del tiempo de respuesta.

Los valores `<1500 ms`, `<2000 ms`, `<1%`, `>40 req/s`, CPU `<75%` y memoria `<80%` venían del template del ingeniero. Son puntos de comparación para describir el estado; los scripts ya no los usan como aserciones globales que detengan Maven.

## 6. Muestrear CPU y memoria

Mientras ejecutas un perfil en la consola Gatling, inicia desde la raíz del repositorio una tercera consola PowerShell:

```powershell
.\performance\gatling\scripts\sample-local-resources.ps1 -DurationSeconds 160
```

El CSV se guarda en `performance/gatling/target/resource-samples.csv`. La carpeta `target` está ignorada por Git. Si cambias el nombre del contenedor o puerto de la API, pasa `-ContainerName` o `-ApiPort` al script.

## 7. Dónde ver resultados

Cada ejecución crea una carpeta nueva bajo:

```text
performance/gatling/target/gatling/<nombre-simulacion>-<fecha-hora>/index.html
```

Abre el `index.html` de la carpeta más reciente de la simulación ejecutada. El informe escrito está en `informe-performance.md`; incluye los resultados usados, el alcance y las limitaciones. No borres `target` antes de guardar/copiar los HTML que necesites entregar.

## 8. Cuidado al interpretar

- El resultado actual es de la máquina local, con Node en el host y PostgreSQL en Docker; no representa QA ni producción.
- La carga y el estrés actuales solo leen después del login. No miden registro, CRUD, préstamos, devoluciones, correo ni seguridad.
- No agregues tokens estáticos de la colección Postman. El token se obtiene en cada flujo a partir del login.
- Una respuesta lenta no debe ocultarse por el hecho de que el status sea 200. Registra ambas cosas en el informe.
- Si cambias tasa, duración, usuarios o think time, documenta esos nuevos parámetros porque las métricas dejarán de ser comparables con las corridas actuales.
