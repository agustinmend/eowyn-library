# Gatling para Eowyn Library

Este módulo está separado de la aplicación Node/Express. El smoke y el perfil de concurrencia usan Karate-Gatling, como en los ejercicios de clase. La prueba orientada a throughput usa la DSL HTTP directa de Gatling para no medir el límite de rendimiento del adaptador Karate.

Para pasos detallados, perfiles y explicación de métricas, consulta [GUIA-EJECUCION.md](GUIA-EJECUCION.md).

## Ejecución en un comando

Una vez configurado el `.env` local, abre PowerShell en la raíz del repositorio y ejecuta:

```powershell
.\performance\gatling\scripts\run-full-api.ps1
```

El lanzador lee `host` de `config/eowyn-local.postman_environment.json`, levanta PostgreSQL, aplica migraciones, instala dependencias Node solo si faltan, arranca la API si no está respondiendo, ejecuta la cobertura de las 13 rutas y limpia sus fixtures. Por defecto usa 1 usuario virtual; para probar hasta 20 en la base local, ejecuta el comando con `-WriteUsers 5`. Si inicia la API, la deja ejecutándose y guarda logs en `performance/gatling/target/`. El reporte aparece bajo `performance/gatling/target/gatling/`.

La configuración base de Postman no tenía valor para `host`; el archivo local incluido ya lo fija a `http://localhost:3000`. `token` queda vacío porque el escenario obtiene un JWT nuevo con el endpoint de login. La contraseña corresponde al usuario seed local y se puede cambiar con `-TestEmail` y `-TestPassword`.

## Preparar la API local

Desde la raíz del repositorio, sigue el README principal: configura `.env`, instala dependencias, levanta PostgreSQL, aplica migraciones y arranca la API. La configuración local de este workspace publica PostgreSQL por el puerto `5433` para evitar el servicio que ocupaba el `5432`; el `.env` creado ya apunta al puerto correcto. Para el escenario utiliza el usuario local sembrado por las migraciones (por ejemplo, `admin@example.com`) y su contraseña local. No uses tokens fijos de la colección Postman.

## Ejecutar los perfiles

Requisitos: Java 17 o posterior y Maven. Desde PowerShell:

```powershell
$env:BASE_URL = 'http://localhost:3000'
$env:TEST_EMAIL = 'admin@example.com'
$env:TEST_PASSWORD = '<contraseña local>'
Set-Location performance/gatling
# Ciclo autenticado de todas las rutas, incluida escritura (solo BD local de pruebas)
$env:ENABLE_WRITE_TESTS = 'true'
$env:WRITE_TEST_USERS = '1'
mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynFullApiSimulation'
Remove-Item Env:ENABLE_WRITE_TESTS
# Perfiles de lectura
mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynCatalogSimulation'
# Carga: rampa a 20 flujos/s en 30 s, luego 60 s sostenidos
mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynLoadSimulation'
# Estrés de concurrencia Karate-Gatling: niveles de 25, 50, 75, 100 y 125 usuarios
mvn test-compile gatling:test '-Dgatling.simulationClass=performance.EowynStressSimulation'
```

El smoke usa 2 usuarios con ramp-up de 10 s y 1 usuario/s durante 20 s. La carga directa aumenta hasta 20 flujos/s y sostiene ese ritmo por 60 s; cada flujo autentica y ejecuta dos lecturas (hasta 60 requests/s ofrecidos) con 5 s de pausa final. El estrés Karate-Gatling escala usuarios concurrentes de 25 a 125 con 12 s de pausa final. Los reportes HTML se generan bajo `performance/gatling/target/gatling/`.

## Cobertura de todas las APIs

`EowynFullApiSimulation` automatiza las 13 rutas de auth, categorías, libros y préstamos que aparecen en el repositorio y la colección Postman. El escenario registra un usuario único, inicia sesión para obtener un JWT real, ejecuta la validación de email, CRUD de categoría y libro, crea y devuelve un préstamo, y elimina los recursos creados. Los requests se identifican por endpoint en el reporte de Gatling.

Esta simulación usa concurrencia baja (1 usuario por defecto; máximo 20) y cubre el ciclo de escritura, no reemplaza el perfil sostenido de carga/estrés. El registro no tiene endpoint de borrado, así que se generan cuentas de prueba persistentes con el prefijo `gatling-e2e-`. Ejecutarla solo contra una base local/desechable: requiere habilitar explícitamente `ENABLE_WRITE_TESTS=true`. Tras la corrida, desde la raíz del repositorio, limpia los datos exclusivos del escenario:

```powershell
Get-Content .\performance\gatling\scripts\cleanup-gatling-fixtures.sql -Raw | docker compose exec -T postgres-db psql -U gandalf -d eowyn-library
```

## Carga y criterios

Los valores de promedio (`<1500 ms`), p95 (`<2000 ms`), errores (`<1%`) y throughput (`>40 req/s`) son referencias del template del ingeniero, no requisitos confirmados. Las simulaciones generan reportes y validan status/respuesta; los umbrales se comparan al redactar el estado, sin convertirlos en un gate de build. La [documentación de Karate Gatling 1.5](https://github.com/karatelabs/karate/blob/v1.5.2/karate-gatling/README.md) advierte que la integración puede rondar 30 req/s por defecto; la carga de throughput usa Gatling HTTP directo para separar esa limitación de la capacidad observada del API. `gatling-akka.conf` ajusta el pool para el perfil basado en Karate.

El reporte de Gatling permite evaluar los requests HTTP. Para muestrear recursos durante una prueba desde otra consola PowerShell, ejecuta `performance/gatling/scripts/sample-local-resources.ps1 -DurationSeconds 160`; el CSV queda en `performance/gatling/target/resource-samples.csv`. El informe incluye por separado el método y la fuente de esos datos.
