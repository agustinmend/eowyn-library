# Informe de Pruebas de Performance

## 1. Información general

| Campo | Información |
|---|---|
| Proyecto | Eowyn Library |
| Página de pruebas | API REST — `http://localhost:3000` |
| Fecha de ejecución | 18/11/2026 (hora local) |
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
| GET | `/api/categories?page=1&limit=50` |
| GET | `/api/books?page=1&limit=30` |

El smoke y los perfiles de carga/estrés evalúan el mismo flujo crítico de lectura. **Exclusiones:** registro, validación de correo, operaciones CRUD de escritura, préstamos/devoluciones, pruebas de seguridad, base de datos externa y ambiente QA/producción. Se priorizaron login y consultas del catálogo como flujo representativo y repetible, sin modificar el inventario en cada iteración.

## 4. Tipos de prueba ejecutadas

| Tipo de prueba | Descripción y parámetros | Propósito |
|---|---|---|
| Smoke test | Karate-Gatling; 2 usuarios en rampa de 10 s y 1 usuario/s durante 20 s. Cada flujo hace login y dos consultas. | Comprobar configuración, autenticación y respuestas del flujo antes de carga mayor. |
| Prueba de carga | Gatling HTTP: rampa de 0 a 20 flujos/s en 30 s y 20 flujos/s durante 60 s. Cada flujo envía tres requests y termina con una pausa de 5 s; oferta nominal de hasta 60 req/s. | Observar estabilidad y latencia bajo una tasa sostenida y controlada. |
| Prueba de estrés | Karate-Gatling: rampas de 10 s y mesetas de 15 s en 25, 50, 75, 100 y 125 usuarios concurrentes. Pausa de 12 s entre flujos. | Observar el comportamiento al aumentar la concurrencia por encima de 100 usuarios. |

Se seleccionó el flujo de login y lectura para representar el acceso al catálogo y poder repetirlo sin insertar registros ni cambiar inventario en cada iteración. Registro y CRUD no forman parte de estas pruebas. La tasa de 20 flujos/s es un perfil experimental; no proviene de estadísticas de tráfico de producción.

## 5. Indicadores de Desempeño (KPIs)

Los umbrales son los valores de referencia proporcionados en el template docente.

| Indicador | Descripción | Fórmula / unidad | Umbral de referencia | Observación |
|---|---|---|---|---|
| Tiempo promedio | Tiempo medio de respuesta. | Suma de tiempos / requests (ms) | < 1500 ms | Incluye timeouts registrados por Gatling. |
| Percentil 95 | Tiempo bajo el que termina el 95% de las respuestas. | p95 (ms) | < 2000 ms | Refleja la cola de latencia. |
| Throughput | Solicitudes procesadas por segundo. | Requests / segundo | > 40 req/s | Depende del perfil y del tiempo de espera. |
| Tasa de error | Porcentaje de requests fallidos. | Errores / total × 100 | < 1% | KO de Gatling incluye timeouts; el flujo se detiene si falla el login. |
| CPU / memoria | Uso de recursos del API y PostgreSQL durante la prueba. | CPU %; memoria MiB y % de RAM | CPU < 75%; memoria < 80% | Muestreo cada segundo en carga y estrés. El porcentaje de memoria del API se calcula sobre la RAM física del host; el de PostgreSQL es el informado por Docker. |

## 6. Resultados

| Indicador | Carga por tasa | Estrés por concurrencia | Umbral | Resultado frente a referencia |
|---|---:|---:|---:|---|
| Requests | 3 194 (1 999 OK, 1 195 KO) | 1 671 (1 671 OK) | — | Smoke: 66 (66 OK, 0 KO). |
| Tiempo promedio | 37 774 ms | 2 719 ms | < 1500 ms | Carga y estrés superan la referencia. Smoke: 49 ms. |
| Percentil 95 | 60 014 ms | 9 451 ms | < 2000 ms | Carga y estrés superan la referencia. Smoke: 140 ms. |
| Throughput | 20.344 req/s | 11.291 req/s | > 40 req/s | Ninguno supera la referencia. Smoke: 2.276 req/s (baja carga). |
| Tasa de error | 37.41% | 0% | < 1% | Los 1 195 KO de carga fueron timeouts de 60 s; un login fallido detiene el flujo. |
| CPU promedio / máximo | API 1.62% / 2.29%; PostgreSQL 0.80% / 9.20% | API 0.84% / 2.02%; PostgreSQL 0.77% / 9.58% | < 75% | Valores promedio y pico bajo la referencia en ambos perfiles. |
| Memoria promedio / máximo | API 101.03 / 119.08 MiB (0.63% / 0.74% RAM host); PostgreSQL 51.44 / 53.68 MiB (0.66% / 0.69% Docker) | API 100.87 / 107.95 MiB (0.63% / 0.68% RAM host); PostgreSQL 52.76 / 53.50 MiB (0.68% / 0.69% Docker) | < 80% | Porcentajes promedio y pico bajo la referencia; se reportan además los MiB para contextualizar. |

El smoke generó 66 requests con 0 fallos, media de 49 ms, p95 de 140 ms y máximo de 167 ms. Recursos no muestreados en smoke porque su objetivo es verificar el flujo funcional con carga mínima.

## 7. Conclusiones

La prueba de carga mostró que la API local no soporta el perfil configurado de hasta 20 flujos/s: registró 1 195 fallos de 3 194 solicitudes, todos por timeout de 60 s, y una tasa de error de 37.41%. El flujo termina si falla el login para evitar solicitudes posteriores sin token. El perfil de estrés llegó a 125 usuarios y completó 1 671 requests sin KO, con media de 2 719 ms y p95 de 9 451 ms; ambos tiempos superan las referencias. CPU y memoria promedio/pico permanecieron por debajo de las referencias porcentuales en carga y estrés. Los datos describen el entorno local y no se extrapolan a producción. El throughput de Gatling incluye el drenaje de respuestas después de la inyección.

## 8. Recomendaciones

- Revisar la capacidad del API y PostgreSQL bajo la carga sostenida; reducir inicialmente la tasa ofrecida y aumentarla gradualmente en nuevas corridas.
- Repetir el perfil de carga después de revisar los timeouts y comparar latencia y tasa de KO.
- Confirmar con el docente si los umbrales del template son criterios obligatorios.
- Repetir las pruebas con el mismo perfil y datos en QA, si el equipo dispone de ese entorno.
