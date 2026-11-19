# Guía breve de ejecución Gatling

## Ejecutar

1. Configura `.env` a partir de `.env.template` para la base local.
2. Abre PowerShell en la raíz del repositorio y ejecuta:

```powershell
.\performance\gatling\scripts\run-performance.ps1
```

El lanzador prepara PostgreSQL, corre las migraciones pendientes, verifica o inicia la API y ejecuta los tres perfiles. Necesitas Docker Desktop, Node.js, Java 17 o posterior y Maven. El usuario por defecto es el seed local (`admin@example.com` / `123456`); se puede cambiar con `-TestEmail` y `-TestPassword`.

Al finalizar, el script imprime el `index.html` de smoke, carga y estrés. Los reportes quedan bajo `performance/gatling/target/gatling/`. Si el script inicia `npm run dev`, deja la API ejecutándose.

## Qué se prueba

Los tres perfiles usan el flujo `POST /api/auth/login` → páginas 1, 2 y 3 de `GET /api/categories?limit=10` → páginas 1, 2 y 3 de `GET /api/books?limit=10`. El token JWT se obtiene en cada login. Cada flujo realiza siete requests. Se seleccionó este recorrido autenticado de lectura porque representa la consulta del catálogo y puede repetirse sin crear ni cambiar registros.

| Prueba | Parámetros | Qué responde |
|---|---|---|
| Smoke (`EowynCatalogSimulation`) | 2 usuarios en rampa de 10 s; después 1 usuario/s durante 20 s. | ¿Responden el login y las consultas con el entorno recién iniciado? |
| Carga (`EowynLoadSimulation`) | Rampa de 0 a 8,5 flujos/s en 30 s y 8,5 flujos/s durante 60 s. Cada flujo ejecuta siete requests y pausa 5 s. La oferta nominal es ≈59,5 requests/s. | ¿Cómo cambian latencia, errores y throughput bajo una tasa sostenida? |
| Estrés (`EowynStressSimulation`) | Rampas y mesetas en 25, 50, 75, 100 y 125 usuarios; siete requests por flujo y pausa de 12 s. | ¿Cómo responde el servicio cuando aumentan las sesiones concurrentes? |

Registro, validación de correo, operaciones CRUD de escritura, préstamos/devoluciones, seguridad y bases de datos externas quedan fuera del alcance de estas pruebas. Las escrituras requieren un escenario y datos aislados para no contaminar las mediciones.

## Métricas y lectura del informe

Gatling reporta media, p95, throughput y requests fallidos. El lanzador recolecta CPU y memoria automáticamente durante carga y estrés; en la última ejecución el intervalo efectivo fue aproximadamente 2,7 s debido al tiempo de consulta de Docker. Los archivos `target/load-resources-final.csv` y `target/stress-resources-final.csv` contienen las muestras; los promedios y máximos se resumen en el informe. La memoria del API se expresa en MiB y como porcentaje de la RAM física del equipo; PostgreSQL se expresa en MiB y porcentaje reportado por Docker. El porcentaje del API representa su fracción de la RAM total del host, no un límite asignado al proceso. Los valores del template —media <1500 ms, p95 <2000 ms, throughput >40 req/s, errores <1%, CPU <75% y memoria <80%— son referencias porque el docente no los confirmó como criterios de aceptación.

Resultados reales y limitaciones de las corridas: [informe-performance.md](../../informe-performance.md).
