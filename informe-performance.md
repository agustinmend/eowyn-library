# Informe de pruebas de performance — Eowyn Library

> Resultados reales de pruebas locales ejecutadas el 17–18/11/2026. No se reutilizan resultados ficticios del ejemplo de clase.

## 1. Información general

| Campo | Valor |
|---|---|
| Proyecto | Eowyn Library |
| Sistema bajo prueba | API REST Express/TypeScript y PostgreSQL |
| URL base | `http://localhost:3000` |
| Fecha | 17–18/11/2026 (hora local) |
| Responsable | Agustín Mendoza |
| Tipos de prueba | Smoke, cobertura full API, carga por tasa y estrés por concurrencia |
| Herramientas | Gatling, Karate-Gatling, Scala, Maven |
| Entorno | Desarrollo local en Windows 11; API en host local y PostgreSQL 15.3 en Docker |
| Runtime | Java 21.0.7, Node.js 22.15.0, Karate 1.5.0, Gatling 3.9.5 |

## 2. Objetivo

Evaluar el estado actual de las APIs de Eowyn Library desde dos perspectivas. Primero, verificar en un recorrido controlado que las 13 rutas disponibles funcionen en un flujo dependiente de registro, autenticación, catálogo, préstamo/devolución y limpieza de datos. Segundo, medir tiempos de respuesta, fallos y throughput del flujo autenticado de lectura bajo carga sostenida y concurrencia creciente. El recorrido de 13 rutas confirma cobertura funcional; los perfiles sostenidos muestran cómo se comporta el sistema ante carga. Se eligieron ambos porque las escrituras son dependientes y mutan datos, mientras que las lecturas permiten repetir tráfico sin alterar el estado del catálogo.

## 3. Alcance

| Método | Endpoint | Evaluación |
|---|---|---|
| POST | `/api/auth/register` | Registrar usuario aislado para el flujo de prueba |
| POST | `/api/auth/login` | Obtener JWT dinámicamente; también integra los perfiles sostenidos |
| GET | `/api/auth/validate-email/:token` | Verificar respuesta del endpoint actual |
| POST, GET, PUT, DELETE | `/api/categories` y `/api/categories/:id` | Crear, consultar, actualizar y borrar una categoría aislada |
| POST, GET, PUT, DELETE | `/api/books` y `/api/books/:id` | Crear, consultar, actualizar y borrar un libro aislado |
| POST | `/api/loans` | Crear préstamo del libro de prueba |
| PUT | `/api/loans/:id/return` | Devolver el préstamo y restituir disponibilidad |

Las 13 rutas se ejecutan una vez por usuario en el recorrido de cobertura completa. El recorrido de carga sostenida y estrés reutiliza login, listado de categorías y listado de libros con Bearer token extraído del login. La colección Postman contenía variables/tokens de ejemplo; Gatling no reutiliza tokens estáticos.

**Exclusiones:** pruebas de seguridad, validación real con proveedor de correo externo, carga sobre base de datos externa y pruebas en QA/producción. Las operaciones de escritura se validan con un recorrido de baja concurrencia y datos únicos; no se someten al perfil sostenido porque el registro no tiene endpoint de borrado y las mutaciones cambian el estado compartido.

## 4. Diseño de las pruebas

| Prueba | Modelo y perfil | Think time | Propósito |
|---|---|---|---|
| Cobertura completa de API | Karate-Gatling; 1 usuario simultáneo, una iteración, 13 requests secuenciales | Sin pausa adicional | Cubrir todas las rutas y validar el flujo dependiente de escritura con datos únicos. Se mantiene bajo para no generar acumulación ni competir sobre inventario compartido. |
| Smoke | Karate-Gatling; 2 usuarios en ramp-up de 10 s y 1 usuario/s durante 20 s | Sin pausa adicional | Validar autenticación, endpoints, aserciones y reportería |
| Carga por tasa | Gatling HTTP directo; rampa de 0 a 20 flujos/s en 30 s y 20 flujos/s durante 60 s | 5 s después del flujo de tres requests | Medir throughput y localizar degradación bajo una tasa alta |
| Estrés por concurrencia | Karate-Gatling; rampa y mesetas de 25, 50, 75, 100 y 125 usuarios concurrentes | 12 s después del flujo | Observar el comportamiento al superar 100 sesiones concurrentes |

La carga por tasa ofrece nominalmente hasta 60 requests/s (20 flujos/s × 3 requests). El modelo es abierto, así que la concurrencia real depende de cuánto tarda cada flujo. Gatling registró 1,500 flujos iniciados y un máximo de 769 usuarios activos en esa ejecución, debido al tiempo que tardaban las respuestas. Se eligió un modelo abierto para fijar la tasa de llegada y observar la degradación cuando el servicio tarda; el perfil cerrado de concurrencia se usa aparte para observar el comportamiento con grupos de sesiones que permanecen activas.

La pausa del perfil de concurrencia es de Gatling y no bloquea hilos. La carga HTTP directa se separó del adaptador Karate-Gatling porque la documentación de Karate-Gatling 1.5 indica que su configuración predeterminada puede rondar 30 req/s.

## 5. Indicadores y criterios

Los valores del formato compartido por el ingeniero (promedio `<1500 ms`, p95 `<2000 ms`, errores `<1%`, throughput `>40 req/s`, CPU `<75%` y memoria `<80%`) se usan como referencias para describir el estado. No se tratan como requisitos que el sistema tenga que aprobar. Las simulaciones de carga validan status y estructura de respuestas; el informe compara las mediciones con esos valores ilustrativos. La cobertura full API genera una sola observación por ruta, por lo que sus promedio/p95 globales solo sirven como resumen de esa ejecución, no como estimación estable por endpoint.

| KPI | Umbral |
|---|---:|
| Tiempo medio de respuesta | `<1500 ms` |
| Percentil 95 | `<2000 ms` |
| Tasa de requests fallidos | `<1%` |
| Throughput medio | `>40 req/s` |
| CPU | `<75%` |
| Memoria | `<80%` de memoria visible al host Docker; no se fijó límite por contenedor |

## 6. Resultados

### Resumen

| Ejecución | Flujo / usuarios | Requests | Fallos | Media | p95 | Máximo | Throughput medio | Resultado |
|---|---|---:|---:|---:|---:|---:|---:|---|
| Cobertura full API | 1 ciclo completo, 1 usuario | 13 | 0 (0%) | 42 ms | 176 ms | 215 ms | 4.333 req/s | 13/13 rutas exitosas; una muestra por ruta, no es carga sostenida |
| Smoke | 22 flujos, perfil mínimo | 66 | 0 (0%) | 24 ms | 65 ms | 72 ms | 2.276 req/s | 0 fallos; endpoints y respuestas validados |
| Carga por tasa | 1,500 flujos; pico observado 769 activos | 4,500 | 0 (0%) | 6,928 ms | 19,510 ms | 21,917 ms | 41.426 req/s | 0 HTTP KO; latencias sobre los valores de referencia |
| Estrés por concurrencia | Hasta 125 usuarios | 2,295 | 0 (0%) | 225 ms | 764 ms | 1,086 ms | 16.752 req/s | 0 HTTP KO; valores dependen del think time de este perfil |

### Cobertura y latencia observada por ruta en el ciclo full API

El recorrido secuencial con un usuario virtual envió una petición a cada endpoint y validó el estado y los campos de respuesta esperados. La duración de cada fila es una sola muestra, no una estadística de rendimiento por ruta.

| Método y endpoint | Requests | Tiempo observado | Fallos |
|---|---:|---:|---:|
| `POST /api/auth/register` | 1 | 215 ms | 0 |
| `POST /api/auth/login` | 1 | 150 ms | 0 |
| `GET /api/auth/validate-email/:token` | 1 | 6 ms | 0 |
| `POST /api/categories` | 1 | 29 ms | 0 |
| `GET /api/categories` | 1 | 15 ms | 0 |
| `PUT /api/categories/:id` | 1 | 20 ms | 0 |
| `DELETE /api/categories/:id` | 1 | 10 ms | 0 |
| `POST /api/books` | 1 | 16 ms | 0 |
| `GET /api/books` | 1 | 12 ms | 0 |
| `PUT /api/books/:id` | 1 | 16 ms | 0 |
| `DELETE /api/books/:id` | 1 | 12 ms | 0 |
| `POST /api/loans` | 1 | 27 ms | 0 |
| `PUT /api/loans/:id/return` | 1 | 17 ms | 0 |

Se escogió este recorrido porque cubre las rutas que dependen unas de otras: una categoría válida permite crear un libro; ese libro permite crear y devolver un préstamo; luego se pueden borrar los datos de prueba en orden. El perfil de un usuario limita las escrituras y evita conflictos de inventario. Para medir carga sostenida, se mantienen los perfiles de lectura separados, ya que pueden repetirse sin registrar usuarios ni cambiar inventario en cada iteración.

### Detalle por endpoint

| Perfil | Endpoint | Requests | Media | p95 | Fallos |
|---|---|---:|---:|---:|---:|
| Carga por tasa | `POST /api/auth/login` | 1,500 | 5,031 ms | 11,267 ms | 0 |
| Carga por tasa | `GET /api/categories` | 1,500 | 9,152 ms | 20,635 ms | 0 |
| Carga por tasa | `GET /api/books` | 1,500 | 6,600 ms | 19,889 ms | 0 |
| Estrés concurrencia | `POST /api/auth/login` | 765 | 286 ms | 748 ms | 0 |
| Estrés concurrencia | `GET /api/categories` | 765 | 292 ms | 904 ms | 0 |
| Estrés concurrencia | `GET /api/books` | 765 | 98 ms | 422 ms | 0 |

### Recursos durante el estrés de concurrencia

Muestreo continuo de 53 observaciones, aproximadamente cada 2.6 s, desde el inicio hasta el cierre. CPU API calculada desde el proceso Node que atiende el puerto 3000, normalizada sobre los procesadores lógicos visibles; PostgreSQL se midió con `docker stats`.

| Componente | CPU promedio | CPU máximo | Memoria promedio | Memoria máxima |
|---|---:|---:|---:|---:|
| Proceso Node/API | 0.60% | 1.97% | 100.57 MiB | 101.64 MiB |
| PostgreSQL Docker | 0.80% | 3.22% | 43.12 MiB | 44.25 MiB |

PostgreSQL usó en promedio 0.56% y como máximo 0.57% de la memoria visible al host Docker. No hay límite de memoria configurado para el contenedor; el porcentaje se refiere al host, no a un límite propio de PostgreSQL.

### Comparación con valores ilustrativos del template

En las ejecuciones registradas, los límites globales del template todavía estaban configurados como aserciones de Gatling; por eso la carga por tasa terminó con `BUILD FAILURE` al exceder los límites de media y p95. La prueba registró 0 fallos HTTP y generó el HTML completo. Después de aclarar que esos números son solo un template, se retiraron las aserciones globales de las simulaciones; ahora se reportan como comparación, sin bloquear la ejecución.

| Criterio | Carga por tasa | Estrés por concurrencia |
|---|---|---|
| Media de referencia `<1500 ms` | 6,928 ms; por encima | 225 ms; por debajo |
| p95 de referencia `<2000 ms` | 19,510 ms; por encima | 764 ms; por debajo |
| Error de referencia `<1%` | 0%; por debajo | 0%; por debajo |
| Throughput de referencia `>40 req/s` | 41.426 req/s; por encima | No comparable: perfil de concurrencia con 12 s de pausa |
| CPU de referencia `<75%` | No medido en carga por tasa | API 0.60%, PostgreSQL 0.80% promedio |
| Memoria de referencia `<80%` | No medido en carga por tasa | API máx. 101.64 MiB; PostgreSQL máx. 44.25 MiB, sin límite por contenedor |

## 7. Conclusiones

En el perfil de tasa, el estado observado fue 41.426 req/s sin respuestas fallidas, con promedio de 6.9 s y p95 de 19.5 s. `GET /api/categories` tuvo el mayor tiempo medio y p95, seguido por libros y login. Esto describe degradación bajo la tasa configurada en este ambiente local, aunque los status HTTP continuaron siendo exitosos. Los límites del template solo sirven como referencia para expresar esta diferencia; no significan que el proyecto haya incumplido requisitos aprobados.

En el perfil Karate-Gatling de concurrencia, el servicio atendió hasta 125 usuarios activos con 0 fallos y p95 de 764 ms, pero el think time de 12 s mantuvo el throughput en 16.752 req/s. Ese perfil describe concurrencia de sesiones y no busca demostrar capacidad de 40 req/s.

Los resultados describen una sola máquina local, con datos iniciales de las migraciones. No se deben extrapolar a QA/producción ni a operaciones de escritura. El borrador que marcaba un p95 de 1200 ms contra `<2000 ms` como “NO” tenía el veredicto invertido; aquí se compararon los valores con sus límites reales.

## 8. Recomendaciones

1. Confirmar con el docente si los valores de la plantilla son criterios obligatorios o ejemplos.
2. Investigar el p95 alto de categorías y libros, y la serialización/consultas de base de datos bajo la tasa sostenida; repetir después de cualquier mejora.
3. Repetir en QA con el mismo perfil, misma cantidad de datos y recursos del generador documentados.
4. Añadir escrituras solo con datos aislados, IDs/ISBN únicos y una estrategia de limpieza.
5. Adjuntar los reportes HTML y CSV de recursos al entregable final si el LMS los solicita.

## 9. Evidencias

- Smoke Karate-Gatling: `performance/gatling/target/gatling/eowyncatalogsimulation-20261118004729414/index.html`
- Carga directa Gatling: `performance/gatling/target/gatling/eowynloadsimulation-20261118012219536/index.html`
- Estrés Karate-Gatling: `performance/gatling/target/gatling/eowynstresssimulation-20261118010844263/index.html`
- Cobertura de las 13 rutas: `performance/gatling/target/gatling/eowynfullapisimulation-20261119003214086/index.html`
- CSV de CPU/memoria del estrés: `performance/gatling/target/stress-resources-final.csv`
- Los reportes bajo `target/` son artefactos generados e ignorados por Git.

## 10. Cobertura complementaria añadida

Después de las corridas anteriores se ejecutó `EowynFullApiSimulation`, que cubre las 13 rutas del API: registro/login y validación de email; POST, GET, PUT y DELETE de categorías y libros; creación y devolución de préstamos. El recorrido registra una cuenta única, genera una categoría y un libro, presta y devuelve el libro, y borra libro y categoría.

La ejecución del 18/11/2026 generó 13 requests, 13 exitosos y 0 fallidos; media 42 ms, p95 176 ms, máximo 215 ms y throughput 4.333 req/s. Se ejecutó con 1 usuario virtual y una sola iteración; estos datos validan el ciclo completo y **no son comparables** con la carga sostenida de 4,500 requests o el estrés de concurrencia de las secciones anteriores. El script limpió los fixtures automáticamente: eliminó un préstamo, un libro, una categoría y la cuenta temporal. El reporte HTML quedó en `performance/gatling/target/gatling/eowynfullapisimulation-20261119003214086/index.html`.

La cobertura completa requiere una base local/desechable y tiene concurrencia configurable de 1 a 20 usuarios. Para obtener resultados de carga/estrés comparables con los anteriores, ejecutar además `EowynLoadSimulation` y `EowynStressSimulation`; la cobertura de ciclo completo por sí sola es un smoke de escritura de baja concurrencia.
