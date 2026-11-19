# Pruebas de performance de Eowyn Library

La automatización se limita a los tres tipos del template: **smoke, carga y estrés**. El flujo evaluado es login → listado de categorías → listado de libros. Las pruebas usan Gatling y Karate-Gatling; no modifican el código de la API.

## Ejecutar los tres perfiles

Configura `.env` una vez. Desde PowerShell, en la raíz del repositorio, ejecuta:

```powershell
.\performance\gatling\scripts\run-performance.ps1
```

El script levanta PostgreSQL, aplica migraciones, inicia la API si no responde y ejecuta smoke, carga y estrés en orden. Lee `host` desde `config/eowyn-local.postman_environment.json`; el token se obtiene en el login. Requisitos: Docker Desktop, Node.js, Java 17 o posterior y Maven. Si inicia la API, la deja ejecutándose.

Los reportes HTML se generan por separado en `performance/gatling/target/gatling/`. El script imprime las rutas de los tres reportes al finalizar.

## Perfiles

| Perfil | Carga configurada | Propósito |
|---|---|---|
| Smoke | Ramp-up de 2 usuarios en 10 s y 1 usuario/s durante 20 s | Comprobar el flujo y la configuración antes de perfiles mayores. |
| Carga | Rampa de 0 a 8,5 flujos/s en 30 s; luego 8,5 flujos/s durante 60 s. Siete requests por flujo. | Medir respuesta y throughput bajo carga sostenida. |
| Estrés | Niveles concurrentes de 25, 50, 75, 100 y 125 usuarios. Siete requests por flujo. | Observar la respuesta al aumentar la concurrencia. |

Cada flujo inicia sesión y consulta las páginas 1, 2 y 3 tanto de categorías como de libros, con `limit=10` en todas las consultas. Son siete requests por flujo en total.

Durante carga y estrés, el lanzador muestrea automáticamente CPU y memoria del API y PostgreSQL. En la ejecución real el intervalo efectivo fue de aproximadamente 2,7 s por el tiempo que tarda `docker stats`; los CSV quedan en `performance/gatling/target/load-resources-final.csv` y `performance/gatling/target/stress-resources-final.csv`. Los umbrales del informe (promedio <1500 ms, p95 <2000 ms, >40 req/s, error <1%, CPU <75% y memoria <80%) son referencias del template docente, no criterios confirmados de aprobación.
