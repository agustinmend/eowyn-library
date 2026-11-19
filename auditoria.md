# Contexto del proyecto de rendimiento

## Identidad y alcance

Este es el repositorio oficial que entregó el ingeniero para el proyecto de la rúbrica: **Eowyn Library**. No confundir con `myproject`, que contiene ejercicios de clase usados solo como referencia de estilo. La parte asignada a Agustín es preparar las pruebas de rendimiento con **Gatling**, siguiendo lo practicado en clase con Karate y Scala. Un compañero trabaja la alternativa con k6.

La rúbrica pide automatización, definición justificada de qué se evalúa y con qué parámetros, alcance, y un informe de performance. El informe de referencia incluye información general, objetivo, alcance, tipos de prueba (smoke, carga y estrés), KPIs, resultados, conclusiones y recomendaciones.

## Aplicación observada

- API Node.js/TypeScript con Express y PostgreSQL; no es un frontend de página web.
- Arranque documentado: configurar `.env`, `npm install`, levantar PostgreSQL con Docker Compose si hace falta, `npm run migrate:latest` y `npm run dev`.
- Al iniciar no existían `.env` ni `node_modules`; el usuario instaló las dependencias y se creó `.env` local con puerto 3000, DB PostgreSQL y una clave JWT generada (no registrar sus valores en Git ni en informes).
- Variables requeridas: `PORT`, `PG_URL`, `JWT_SEED`; `TOKEN_EXPIRES_IN` tiene valor predeterminado de 2 h.
- Migraciones iniciales siembran usuario admin `admin@example.com` con contraseña `123456`, usuario `gandalf@example.com` y datos de biblioteca. Son credenciales locales de desarrollo del repositorio; no reutilizar fuera del entorno local.

## Rutas reales

Todas las rutas están bajo `/api`:

| Método | Ruta | Autenticación | Observaciones |
|---|---|---|---|
| POST | `/auth/login` | No | Inicia sesión; devuelve un token JWT. |
| POST | `/auth/register` | No | Crea usuario; modifica datos. |
| GET | `/auth/validate-email/:token` | No | Respuesta simple de validación. |
| GET/POST/PUT/DELETE | `/categories` y `/categories/:id` | JWT | Las escrituras modifican datos. |
| GET/POST/PUT/DELETE | `/books` y `/books/:id` | JWT | Las escrituras modifican datos. |
| POST | `/loans` | JWT | Crea préstamo, reduce inventario y crea datos. |
| PUT | `/loans/:id/return` | JWT | Devuelve préstamo y cambia inventario. |

Las consultas de libros y categorías aceptan `page` y `limit`. La colección usa `limit=30` para libros y `limit=50` para categorías. Las lecturas requieren un token; la colección representa `host` y `token` mediante variables de entorno Postman.

## Hallazgos de la colección y del borrador del informe

- La colección exportada contiene JWT escritos de forma fija en algunas solicitudes. No copiarlos a scripts ni informes; autenticar en el flujo y obtener el token dinámicamente o usar secretos externos.
- Hay expectativas/muestras que requieren validar contra el código. Por ejemplo, el login implementado responde `200`, no `201`; algunos registros estáticos o IDs pueden estar vencidos/no existir.
- La colección envía algunos campos con `x-www-form-urlencoded`; usar el mismo formato en Karate cuando corresponda. `POST /loans` convierte a número/fecha en el controlador, así que sus campos deben enviarse con formato válido y fecha futura.
- El flujo de ejemplo del compañero (`login → products → product detail`) no pertenece a esta API. Los endpoints reales son auth, categories, books y loans.
- Las cifras del borrador (100 usuarios, throughput >40 req/s, límites de CPU/memoria y resultados) no se han medido ni justificado todavía. El ejemplo de percentil indica 1200 ms frente a `<2000 ms` y marca “NO”, lo que es inconsistente. No presentar esos valores como resultados reales.
- Gatling/Karate mide tiempos y tasas HTTP; CPU y memoria requieren medición del host/DB por separado (por ejemplo, Docker/monitor del sistema) y no deben afirmarse a partir del reporte HTTP.

## Estilo de implementación aprendido

En los ejercicios de clase se usó Karate para describir requests y validar status/respuestas, y Scala/Gatling para seleccionar un feature con `karateFeature`, declarar perfiles de inyección y aserciones. Los ejercicios k6 practicaron VUs o stages, `check`, pausas, `BASE_URL` configurable y thresholds. Para este proyecto se mantendrá esa separación: Karate expresa el flujo HTTP y Gatling controla la carga/reportes.

Se mantiene `performance/gatling` como módulo aislado para las tres pruebas del template: smoke, carga y estrés. Los perfiles usan el flujo autenticado de login y consulta de categorías/libros, sin alterar la lógica de la aplicación Express ni escribir datos.

## Progreso y resultados locales

- El host 5432 no conectaba al contenedor PostgreSQL esperado; se cambió el puerto publicado del servicio a 5433 y el `PG_URL` local correspondiente. Se conservó el volumen. La contraseña del rol local `gandalf` se alineó con el valor configurado en Docker Compose, sin borrar datos.
- `npm run migrate:latest` aplicó cuatro migraciones. La API arrancó con `npm run dev` en `http://localhost:3000` y el login más GET de categorías/libros respondieron 200.
- `EowynCatalogSimulation`: smoke de 2 VUs, 66 requests, 0 fallos; media 24 ms, p95 65 ms.
- `EowynLoadSimulation`: Gatling HTTP directo con rampa a 20 flujos/s y 60 s sostenidos; 4,500 requests, 0 fallos; pico observado de 769 usuarios activos; media 6,928 ms, p95 19,510 ms y throughput 41.426 req/s. El tiempo de respuesta está por encima de los números ilustrativos del template.
- `EowynStressSimulation`: Karate-Gatling con niveles hasta 125 VUs; corrida final monitoreada con 2,295 requests, 0 fallos; media 225 ms, p95 764 ms, throughput 16.752 req/s.
- El muestreador capturó 53 muestras de recursos durante la corrida final de estrés: Node/API CPU promedio 0.60% y memoria 100.57 MiB; PostgreSQL CPU promedio 0.80% y memoria 43.12 MiB. Son métricas locales, no extrapolables a QA/producción.
- Los números `<1500 ms` promedio, `<2000 ms` p95, `<1%` errores y `>40 req/s` se tratan como referencias del template, no como requisitos de aprobación. La medición de carga observó más de 40 req/s y latencia elevada; el perfil de estrés observó baja tasa por sus 12 s de think time. El informe describe el estado medido sin convertir estas referencias en gates.
- En las corridas guardadas, las referencias todavía eran aserciones globales, así que Gatling acabó con BUILD FAILURE por latencia aunque se registraron 0 errores HTTP. Ya se quitaron esos gates de los tres scripts; los siguientes reportes muestran el estado sin bloquear por cifras ilustrativas.
- El informe inicial está en `informe-performance.md`; los reportes HTML y CSV se generan bajo `performance/gatling/target/` (ignorado por Git).
- El alcance vigente conserva solo smoke, carga y estrés sobre el flujo de lectura requerido por el template.
- `performance/gatling/scripts/run-performance.ps1` prepara PostgreSQL y la API local y ejecuta los tres perfiles en orden.

## Siguiente trabajo

1. Confirmar con el equipo/docente si el throughput `>40 req/s` del ejemplo aplica como aceptación obligatoria; ajustar y volver a medir si así lo indican.
2. Ejecutar en QA si el equipo obtiene ese ambiente y comparar contra la línea base local.
3. Repetir los perfiles seleccionados con datos y ambiente constantes si se solicita comparar tendencias.
4. Adjuntar reportes HTML/CSV y el informe final conforme al template docente.

## Estado de cambios

La automatización nueva reside bajo `performance/gatling`; no se modifican los scripts de la carpeta de ejercicios de clase ni la lógica de la API para construir el generador de carga.
