from docx import Document
from docx.shared import Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

source_path = r"D:\Agustin\Universidad\6to semestre\QA II\ProyectoOficialBloque2\eowyn-library\Informe-Pruebas-Performance-Gatling-Eowyn-Library.docx"
path = r"D:\Agustin\Universidad\6to semestre\QA II\ProyectoOficialBloque2\eowyn-library\Informe-Pruebas-Performance-Gatling-Eowyn-Library-Actualizado.docx"
doc = Document(source_path)

def replace_prefix(prefix, text):
    for p in doc.paragraphs:
        if p.text.startswith(prefix):
            p.text = text
            return
    raise RuntimeError(f"Paragraph not found: {prefix}")

def shade(cell, color):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:fill'), color)
    tc_pr.append(shd)

def put(cell, text, bold=False, color='263238', size=8.2):
    cell.text = ''
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(1)
    p.paragraph_format.space_before = Pt(1)
    run = p.add_run(text)
    run.bold = bold
    run.font.name = 'Aptos'
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)

replace_prefix('Este informe documenta las ejecuciones',
    'Este informe define y presenta las pruebas de performance de Eowyn Library. Se eligieron dos enfoques complementarios: un recorrido de baja concurrencia que verifica las 13 rutas en un ciclo dependiente de registro, catálogo y préstamo; y perfiles repetibles de lectura para medir carga sostenida y estrés de concurrencia sin alterar datos en cada iteración. En la corrida full API, las 13 rutas respondieron correctamente; sus 42 ms de media y p95 de 176 ms resumen una sola iteración y no equivalen a una medición de carga sostenida.')
replace_prefix('Medir tiempos de respuesta, percentil 95',
    'Evaluar cobertura, tiempos de respuesta, percentil 95, throughput y fallos HTTP de la API. La cobertura full API comprueba los métodos disponibles y sus dependencias funcionales. Los perfiles de carga miden el flujo autenticado de login y consultas de categorías/libros bajo una tasa de llegada gradual y sostenida; el perfil de estrés aumenta las sesiones concurrentes hasta 125. Se separan las escrituras del tráfico sostenido porque registro, CRUD y préstamos cambian el estado de la base de datos.')
replace_prefix('Endpoints evaluados. Las consultas de catálogo',
    'Alcance: las 13 rutas existentes se cubren una vez en el recorrido full API; los perfiles sostenidos repiten login y consultas de catálogo con el JWT obtenido en cada flujo. La colección Postman orientó los métodos, rutas y el uso de formularios; Gatling genera tokens y datos únicos, no reutiliza valores estáticos.')
replace_prefix('Exclusiones: pruebas de seguridad;',
    'Exclusiones: pruebas de seguridad, verificación real con proveedor de correo externo, carga sobre base de datos externa y pruebas en QA/producción. Las operaciones de escritura se ejecutan con datos únicos y concurrencia baja porque el registro no tiene endpoint de borrado y las mutaciones alteran inventario y estado. No se excluyen del alcance funcional; se excluyen de los perfiles sostenidos actuales.')
replace_prefix('Los KPIs permiten describir el comportamiento bajo carga.',
    'Los KPIs permiten describir el comportamiento bajo carga. Los umbrales del formato de ejemplo son referencias y no requisitos aprobados. En la corrida full API se envió una sola petición por ruta: el promedio y p95 globales no permiten estimar percentiles estables por endpoint ni compararse con los perfiles de carga sostenida.')
replace_prefix('En carga por tasa se iniciaron 1,500 flujos',
    'La cobertura full API ejecutó 13 requests secuenciales, uno por ruta, con 1 usuario virtual: 0 fallos, media 42 ms, p95 176 ms, máximo 215 ms y 4.333 req/s durante el corto recorrido. Estos valores verifican el ciclo y sirven como línea funcional inicial; no son resultados de carga sostenida. En carga por tasa se iniciaron 1,500 flujos (tres requests por flujo). Gatling observó un máximo de 769 usuarios activos mientras las respuestas se ralentizaban. El throughput observado fue 41.426 req/s, inferior a la oferta nominal máxima de 60 req/s.')
replace_prefix('En la prueba de carga por tasa se observaron 41.426 req/s',
    'La cobertura full API completó las 13 rutas sin fallos, pero con una sola muestra por endpoint; sus percentiles no deben interpretarse como estabilidad bajo carga. En la prueba de carga por tasa se observaron 41.426 req/s y ningún fallo HTTP, junto con una media de 6.928 ms y un p95 de 19.510 ms. Categorías fue el endpoint con mayor latencia. El resultado indica degradación de tiempos bajo ese perfil en la máquina local, aunque las respuestas continuaron siendo exitosas.')
replace_prefix('Los datos describen ejecuciones locales del 17/11/2026',
    'Los datos describen ejecuciones locales del 17–18/11/2026 y no se extrapolan a QA/producción. Las cifras de la plantilla son referencias de comparación, no criterios de aceptación confirmados.')

# Date and profile labels in the general-information table.
for row in doc.tables[0].rows:
    if row.cells[0].text == 'Fecha de ejecución':
        put(row.cells[1], '17–18/11/2026')
    if row.cells[0].text == 'Tipo de prueba':
        put(row.cells[1], 'Smoke, cobertura full API, carga por tasa y estrés por concurrencia')

# Rebuild the endpoint scope table with all routes present in the API.
scope = doc.tables[1]
while len(scope.rows) > 1:
    scope._tbl.remove(scope.rows[-1]._tr)
routes = [
    ('POST', '/api/auth/register', 'Registrar usuario único para el escenario.'),
    ('POST', '/api/auth/login', 'Autenticación y extracción dinámica del JWT; también se repite en carga/estrés.'),
    ('GET', '/api/auth/validate-email/:token', 'Comprobar el endpoint actual de validación.'),
    ('POST', '/api/categories', 'Crear categoría aislada.'),
    ('GET', '/api/categories?page=1&limit=50', 'Consultar categorías; se incluye en perfiles sostenidos.'),
    ('PUT', '/api/categories/:id', 'Actualizar categoría de prueba.'),
    ('DELETE', '/api/categories/:id', 'Eliminar categoría al final del ciclo.'),
    ('POST', '/api/books', 'Crear libro asociado a la categoría de prueba.'),
    ('GET', '/api/books?page=1&limit=30', 'Consultar libros; se incluye en perfiles sostenidos.'),
    ('PUT', '/api/books/:id', 'Actualizar libro de prueba.'),
    ('DELETE', '/api/books/:id', 'Eliminar libro tras devolverlo.'),
    ('POST', '/api/loans', 'Prestar el libro de prueba al usuario de la corrida.'),
    ('PUT', '/api/loans/:id/return', 'Devolver el préstamo y restituir disponibilidad.'),
]
for i, values in enumerate(routes):
    cells = scope.add_row().cells
    for j, value in enumerate(values):
        put(cells[j], value, size=7.8)
        if i % 2:
            shade(cells[j], 'F3F6F9')

# Add the explicit full-API design and rationale to the test profile table.
profiles = doc.tables[2]
cells = profiles.add_row().cells
values = ('Cobertura full API',
          'Karate-Gatling; atOnceUsers(1), una iteración con 13 requests secuenciales y datos únicos.',
          'Cubrir rutas y dependencias del ciclo registro → login → categoría → libro → préstamo/devolución → limpieza. Una sola iteración limita escrituras y evita conflictos; no sustituye la carga sostenida.')
for j, value in enumerate(values):
    put(cells[j], value, size=7.8)

# Record the actual full-route run alongside the previous performance profiles.
results = doc.tables[4]
cells = results.add_row().cells
values = ('Cobertura full API (1 usuario)', '13', '0 (0%)', '42 ms', '176 ms', '215 ms', '4.333 req/s', '13/13 rutas OK; una muestra por ruta, no es carga sostenida')
for j, value in enumerate(values):
    put(cells[j], value, size=7.1)

# Add the newly generated HTML report to the evidence table.
evidence = doc.tables[8]
cells = evidence.add_row().cells
put(cells[0], 'Cobertura full API', size=7.6)
put(cells[1], 'performance/gatling/target/gatling/eowynfullapisimulation-20261119003214086/index.html', size=7.2)

for section in doc.sections:
    for p in section.footer.paragraphs:
        if '17/11/2026' in p.text:
            p.text = p.text.replace('17/11/2026', '17–18/11/2026')

doc.core_properties.comments = 'Incluye alcance de las 13 APIs y resultados de la corrida full API del 18/11/2026.'
doc.save(path)
print(path)
