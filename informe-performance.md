# Informe de Pruebas de Performance

## 1. Información general

| Campo | Información |
|---|---|
| Proyecto | Eowyn Library |
| Página de pruebas | API REST — `http://localhost:3000` |
| Fecha de ejecución | 19/11/2026 (hora local) |
| Responsable | Agustín Mendoza — pruebas Gatling |
| Tipo de prueba | Smoke test, prueba de carga y prueba de estrés |
| Herramienta utilizada | Gatling 3.9.5 y Karate-Gatling 1.5.0 |
| Entorno | Desarrollo local: Windows 11, API en host local y PostgreSQL 15.3 en Docker |
| Objetivo principal | Evaluar el flujo crítico autenticado y observar el comportamiento de la API bajo carga gradual y concurrencia creciente. |

## 2. Objetivo de la prueba

Medir tiempos de respuesta, percentil 95, throughput y tasa de fallos del flujo `login → consulta de categorías → consulta de libros`. El perfil de estrés escala hasta 125 usuarios concurrentes para observar la respuesta por encima de los 100 usuarios de referencia del template. Los umbrales del ejemplo se usan para comparar resultados; no se consideran criterios de aceptación confirmados.

## 3. Alcance

**Endpoints del flujo de carga y estrés:**

| Método | Endpoint |
|---|---|
| POST | `/api/auth/login` |
| GET | `/api/categories?page=1,2,3&limit=10` |
| GET | `/api/books?page=1,2,3&limit=10` |

El smoke y los perfiles de carga/estrés evalúan el mismo flujo crítico de lectura. **Exclusiones:** registro, validación de correo, operaciones CRUD de escritura, préstamos/devoluciones, pruebas de seguridad, base de datos externa y ambiente QA/producción. Se priorizaron login y consultas del catálogo como flujo representativo y repetible, sin modificar el inventario en cada iteración.

## 4. Tipos de prueba ejecutadas

| Tipo de prueba | Descripción y parámetros | Propósito |
|---|---|---|
| Smoke test | Karate-Gatling; 2 usuarios en rampa de 10 s y 1 usuario/s durante 20 s. Cada flujo hace login y consulta tres páginas de categorías y tres de libros (7 requests). | Comprobar configuración, autenticación y respuestas del flujo antes de carga mayor. |
| Prueba de carga | Gatling HTTP: rampa de 0 a 8,5 flujos/s en 30 s y 8,5 flujos/s durante 60 s. Cada flujo hace login, seis consultas paginadas y pausa 5 s; oferta nominal cercana a 59,5 req/s. | Observar estabilidad y latencia bajo una tasa sostenida y controlada. |
| Prueba de estrés | Karate-Gatling: rampas de 10 s y mesetas de 15 s en 25, 50, 75, 100 y 125 usuarios concurrentes. Cada flujo hace 7 requests y pausa 12 s. | Observar el comportamiento al aumentar la concurrencia por encima de 100 usuarios. |

Se seleccionó el flujo de login y lectura para representar el acceso al catálogo y poder repetirlo sin insertar registros ni cambiar inventario en cada iteración. En cada flujo se consultan las páginas 1 a 3 de ambas listas con 10 registros por página. Registro y CRUD no forman parte de estas pruebas. La tasa de 8,5 flujos/s es un perfil experimental que mantiene una oferta nominal cercana a 60 requests/s; no proviene de estadísticas de tráfico de producción.

## 5. Indicadores de Desempeño (KPIs)

Los umbrales son los valores de referencia proporcionados en el template docente.

| Indicador | Descripción | Fórmula / unidad | Umbral de referencia | Observación |
|---|---|---|---|---|
| Tiempo promedio | Tiempo medio de respuesta. | Suma de tiempos / requests (ms) | < 1500 ms | Incluye timeouts registrados por Gatling. |
| Percentil 95 | Tiempo bajo el que termina el 95% de las respuestas. | p95 (ms) | < 2000 ms | Refleja la cola de latencia. |
| Throughput | Solicitudes procesadas por segundo. | Requests / segundo | > 40 req/s | Depende del perfil y del tiempo de espera. |
| Tasa de error | Porcentaje de requests fallidos. | Errores / total × 100 | < 1% | KO de Gatling incluye timeouts; el flujo se detiene si falla el login. |
| CPU / memoria | Uso de recursos del API y PostgreSQL durante la prueba. | CPU %; memoria MiB y % de RAM | CPU < 75%; memoria < 80% | Muestreo durante carga y estrés; intervalo efectivo promedio ≈2,7 s. API RAM como porcentaje del host; PostgreSQL según Docker. |

## 6. Resultados

| Indicador | Carga por tasa | Estrés por concurrencia | Umbral | Resultado frente a referencia |
|---|---:|---:|---:|---|
| Requests | 4 459 (4 459 OK, 0 KO) | 3 745 (3 745 OK, 0 KO) | — | Smoke: 154 (154 OK, 0 KO). Cada flujo completó las 7 solicitudes: 100 % en los tres perfiles. |
| Tiempo promedio | 4 968 ms | 1 342 ms | < 1500 ms | Carga: no alcanza; estrés: alcanza. Smoke: 24 ms. |
| Percentil 95 | 18 081 ms | 7 895 ms | < 2000 ms | Carga y estrés superan la referencia. Smoke: 133 ms. |
| Throughput | 40.171 req/s | 24.638 req/s | > 40 req/s | Carga supera por poco la referencia; estrés no. Smoke: 5.310 req/s (baja carga). |
| Tasa de error | 0% | 0% | < 1% | No se registraron KO; 100 % de flujos completados. |
| CPU promedio / máximo | API 1.43% / 2.17%; PostgreSQL 1.99% / 18.09% | API 0.81% / 1.99%; PostgreSQL 1.57% / 13.83% | < 75% | API está normalizado a capacidad total del host; véase la nota de conversión. |
| Memoria promedio / máximo | API 69.94 / 90.91 MiB (0.44% / 0.57% RAM host); PostgreSQL 49.08 / 53.27 MiB (0.63% / 0.69% Docker) | API 91.40 / 92.46 MiB (0.57% / 0.58% RAM host); PostgreSQL 52.33 / 53.10 MiB (0.67% / 0.69% Docker) | < 80% | Promedios y máximos porcentuales bajo referencia; se informa también memoria en MiB. |

El CPU del API está normalizado sobre los 20 procesadores lógicos del equipo (porcentaje de capacidad total del host). Para aproximarlo al porcentaje por núcleo presentado por k6, se multiplica por 20: carga, promedio 28,6 % y máximo 43,4 %; estrés, promedio 16,2 % y máximo 39,8 %. No se capturó el CPU total de la máquina. Los promedios cubren el perfil completo y no equivalen a los valores individuales por escalón de k6. El muestreador produjo 46 muestras en carga y 60 en estrés; por el tiempo que demora `docker stats`, el intervalo observado fue de unos 2,7 segundos, no exactamente uno.

El smoke generó 154 requests con 0 fallos, media de 24 ms, p95 de 133 ms y máximo de 282 ms. Recursos no muestreados en smoke porque su objetivo es verificar el flujo funcional con carga mínima.

### 6.3 Desglose de tiempos por endpoint

Los reportes HTML de Gatling también contienen media y p95 por request. Estos valores se añaden para compararlos con las referencias por endpoint anotadas en la sección de k6. En carga, los tiempos incluyen las solicitudes KO por timeout; los percentiles por endpoint están afectados por esos timeouts.

| Smoke test | Solicitudes (OK/KO) | Media | p95 | Throughput |
|---|---:|---:|---:|---:|
| `POST /api/auth/login` | 22 (22/0) | 134 ms | 149 ms | 0,759 req/s |
| `GET /api/categories` (3 páginas) | 66 (66/0) | 6 ms | 11 ms | 2,276 req/s |
| `GET /api/books` (3 páginas) | 66 (66/0) | 5 ms | 9 ms | 2,276 req/s |

| Prueba de carga | Solicitudes (OK/KO) | Media | p95 | Throughput |
|---|---:|---:|---:|---:|
| `POST /api/auth/login` | 637 (637/0) | 4.707 ms | 11.130 ms | 5,739 req/s |
| `GET /api/categories` (3 páginas) | 1.911 (1.911/0) | 6.762 ms | 19.126 ms | 17,216 req/s |
| `GET /api/books` (3 páginas) | 1.911 (1.911/0) | 3.262 ms | 16.374 ms | 17,216 req/s |

| Prueba de estrés | Solicitudes (OK/KO) | Media | p95 | Throughput |
|---|---:|---:|---:|---:|
| `POST /api/auth/login` | 535 (535/0) | 3.590 ms | 10.570 ms | 3,520 req/s |
| `GET /api/categories` (3 páginas) | 1.605 (1.605/0) | 1.625 ms | 8.812 ms | 10,559 req/s |
| `GET /api/books` (3 páginas) | 1.605 (1.605/0) | 310 ms | 583 ms | 10,559 req/s |

Al contrastar con las referencias por endpoint del documento (media: login <400 ms, lecturas <150 ms; p95: login <800 ms, lecturas <300 ms), el smoke queda dentro. Carga y estrés superan los p95 por endpoint; el p95 de libros en estrés fue 583 ms. Son referencias indicadas en el documento del grupo.

Gatling ahora consulta las páginas 1, 2 y 3 de categorías y libros con `limit=10`, alineado con el tamaño de página solicitado. Los escalones de estrés siguen siendo de 25 a 125 usuarios y difieren de los escalones E50 a E400 descritos para k6; por eso la comparación de estrés por nivel de concurrencia no es equivalente.

## 7. Conclusiones

Con tres páginas de 10 registros por endpoint de lectura, smoke, carga y estrés completaron el 100 % de sus flujos, sin KO. La carga alcanzó 40,171 req/s, por encima de 40 req/s, pero el p95 global fue 18.081 ms y la media 4.968 ms. Estrés completó 535 flujos a 125 usuarios; la media global fue 1.342 ms, pero el p95 7.895 ms. Los umbrales de p95 global y por endpoint no se cumplen en carga ni estrés. El smoke sí quedó dentro de las referencias de p95 por endpoint. Los recursos se mantuvieron por debajo de los umbrales porcentuales. Resultados del entorno local, no extrapolables a producción.

## 8. Recomendaciones

- Revisar la capacidad del API y PostgreSQL bajo la carga sostenida; reducir inicialmente la tasa ofrecida y aumentarla gradualmente en nuevas corridas.
- Repetir el perfil de carga después de revisar los timeouts y comparar latencia y tasa de KO.
- Confirmar con el docente si los umbrales del template son criterios obligatorios.
- Repetir las pruebas con el mismo perfil y datos en QA, si el equipo dispone de ese entorno.
