from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

OUT = r"D:\Agustin\Universidad\6to semestre\QA II\ProyectoOficialBloque2\eowyn-library\Informe-Pruebas-Performance-Gatling-Eowyn-Library-Paginacion-19-11-2026.docx"
NAVY = '17365D'
TEAL = '0F6B78'
PALE = 'F1F5F9'
TEXT = '273444'
MUTED = '5B6573'

doc = Document()
sec = doc.sections[0]
sec.top_margin = Inches(.58)
sec.bottom_margin = Inches(.58)
sec.left_margin = Inches(.68)
sec.right_margin = Inches(.68)

normal = doc.styles['Normal']
normal.font.name = 'Aptos'
normal.font.size = Pt(9)
normal.font.color.rgb = RGBColor.from_string(TEXT)
normal.paragraph_format.space_after = Pt(4)
for name, size in [('Title', 23), ('Heading 1', 14), ('Heading 2', 10.5)]:
    s = doc.styles[name]
    s.font.name = 'Aptos Display'
    s.font.size = Pt(size)
    s.font.bold = True
    s.font.color.rgb = RGBColor.from_string(NAVY if name != 'Heading 2' else TEAL)
    s.paragraph_format.space_before = Pt(8)
    s.paragraph_format.space_after = Pt(4)

def shade(cell, color):
    pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:fill'), color)
    pr.append(shd)

def put(cell, value, bold=False, color=TEXT, size=8):
    cell.text = ''
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(1)
    p.paragraph_format.space_before = Pt(1)
    run = p.add_run(str(value))
    run.bold = bold
    run.font.name = 'Aptos'
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER

def add_table(headers, rows, widths, size=8):
    t = doc.add_table(rows=1, cols=len(headers))
    t.style = 'Table Grid'
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    for i, h in enumerate(headers):
        put(t.rows[0].cells[i], h, True, 'FFFFFF', size)
        shade(t.rows[0].cells[i], NAVY)
    for n, row in enumerate(rows):
        cells = t.add_row().cells
        for i, value in enumerate(row):
            put(cells[i], value, size=size)
            if n % 2:
                shade(cells[i], PALE)
    for row in t.rows:
        for i, width in enumerate(widths):
            row.cells[i].width = Inches(width)
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(1)
    p.paragraph_format.space_before = Pt(0)
    return t

header = sec.header.paragraphs[0]
header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
r = header.add_run('QA II  |  EOWYN LIBRARY  |  GATLING')
r.font.name = 'Aptos'; r.font.size = Pt(7.5); r.font.bold = True; r.font.color.rgb = RGBColor.from_string(TEAL)
footer = sec.footer.paragraphs[0]
footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = footer.add_run('Informe de pruebas de performance  ·  19/11/2026')
r.font.name = 'Aptos'; r.font.size = Pt(7.5); r.font.color.rgb = RGBColor.from_string(MUTED)

p = doc.add_paragraph(style='Title')
p.add_run('Informe de Pruebas de Performance')
p = doc.add_paragraph()
r = p.add_run('Eowyn Library · API REST')
r.bold = True; r.font.size = Pt(11); r.font.color.rgb = RGBColor.from_string(TEAL)
doc.add_paragraph('Se evaluó el flujo autenticado de consulta del catálogo, incluyendo tres páginas de 10 registros por cada lista. Los perfiles completaron los flujos sin fallos; carga y estrés registraron percentiles superiores a las referencias.')

doc.add_heading('1. Información general', level=1)
add_table(['Campo', 'Información'], [
    ('Proyecto', 'Eowyn Library'),
    ('Página de pruebas', 'API REST — http://localhost:3000'),
    ('Fecha de ejecución', '19/11/2026 (hora local)'),
    ('Responsable', 'Agustín Mendoza — pruebas Gatling'),
    ('Tipo de prueba', 'Smoke test, carga y estrés'),
    ('Herramienta utilizada', 'Gatling 3.9.5 y Karate-Gatling 1.5.0'),
    ('Entorno', 'Desarrollo local: Windows 11; API en host local y PostgreSQL 15.3 en Docker'),
    ('Objetivo principal', 'Evaluar el flujo crítico autenticado bajo carga gradual y concurrencia creciente.'),
], [1.55, 5.65], 8.2)

doc.add_heading('2. Objetivo de la prueba', level=1)
doc.add_paragraph('Medir tiempos de respuesta, p95, throughput y fallos del flujo login → categorías → libros. El perfil de estrés llega a 125 usuarios concurrentes para observar el comportamiento por encima de los 100 usuarios de referencia del template. Los umbrales de ejemplo se usan para comparar; no son criterios de aceptación confirmados.')

doc.add_heading('3. Alcance', level=1)
doc.add_paragraph('Endpoints repetidos en los perfiles de carga y estrés:')
add_table(['Método', 'Endpoint'], [
    ('POST', '/api/auth/login'),
    ('GET', '/api/categories?page=1, 2 y 3; limit=10'),
    ('GET', '/api/books?page=1, 2 y 3; limit=10'),
], [1.0, 6.2], 8.2)
doc.add_paragraph('El smoke y los perfiles de carga/estrés cubren el mismo flujo de lectura autenticado. Exclusiones: registro, validación de correo, operaciones CRUD de escritura, préstamos/devoluciones, pruebas de seguridad, base de datos externa y ambiente QA/producción. Se prioriza el flujo crítico de lectura por ser repetible sin alterar inventario en cada iteración.')

doc.add_heading('4. Tipos de prueba ejecutadas', level=1)
add_table(['Tipo de prueba', 'Descripción y parámetros', 'Propósito'], [
    ('Smoke test', 'Karate-Gatling; rampa de 2 usuarios en 10 s y 1 usuario/s durante 20 s; cada flujo hace login y consulta 3 páginas de categorías y 3 de libros (7 requests).', 'Validar entorno, autenticación y respuestas del flujo antes de carga mayor.'),
    ('Prueba de carga', 'Rampa 0→8,5 flujos/s en 30 s; mantiene 8,5 flujos/s durante 60 s. Cada flujo hace 7 requests y pausa 5 s; oferta nominal ≈59,5 req/s.', 'Observar estabilidad y latencia bajo una tasa sostenida.'),
    ('Prueba de estrés', 'Rampas de 10 s y mesetas de 15 s a 25, 50, 75, 100 y 125 usuarios; 7 requests por flujo y pausa de 12 s.', 'Observar el sistema al aumentar la concurrencia por encima de 100 usuarios.'),
], [1.08, 3.55, 2.57], 7.4)
doc.add_paragraph('Cada flujo consulta páginas 1, 2 y 3 de categorías y libros con limit=10. La tasa de 8,5 flujos/s es experimental y conserva una oferta nominal cercana a 60 requests/s; no es una proyección de tráfico real.')

doc.add_heading('5. Indicadores de Desempeño (KPIs)', level=1)
doc.add_paragraph('Los umbrales siguientes son referencias tomadas del template docente.')
add_table(['Indicador', 'Descripción / unidad', 'Umbral', 'Observación'], [
    ('Tiempo promedio', 'Suma de tiempos / requests (ms)', '< 1500 ms', 'Medir por endpoint.'),
    ('Percentil 95', 'p95 (ms)', '< 2000 ms', 'Refleja cola de latencia.'),
    ('Throughput', 'Requests por segundo', '> 40 req/s', 'Depende del perfil y pausas.'),
    ('Tasa de error', 'Fallos / total × 100', '< 1%', 'KO de Gatling incluye timeouts; login fallido detiene el flujo.'),
    ('CPU / memoria', 'CPU %; memoria MiB y % de RAM', 'CPU < 75%; memoria < 80%', 'Muestreo efectivo ≈2,7 s. API % sobre RAM host; DB % de Docker.'),
], [1.2, 1.75, 1.25, 3.0], 7.3)

doc.add_heading('6. Resultados', level=1)
add_table(['Indicador', 'Carga por tasa', 'Estrés concurrencia', 'Umbral', 'Observación'], [
    ('Requests / flujos', '4 459; 637/637 flujos (100%)', '3 745; 535/535 flujos (100%)', 'Flujos >99%', 'Smoke: 154 requests; 22/22 flujos.'),
    ('Tiempo promedio', '4 968 ms', '1 342 ms', '< 1500 ms', 'Carga no alcanza; estrés alcanza. Smoke: 24 ms.'),
    ('Percentil 95', '18 081 ms', '7 895 ms', '< 2000 ms', 'Carga/estrés superan; smoke: 133 ms.'),
    ('Throughput', '40.171 req/s', '24.638 req/s', '> 40 req/s', 'Carga supera por poco; estrés no. Smoke: 5.310.'),
    ('Tasa de error', '0%', '0%', '< 1%', '0 KO en los tres perfiles; flujos 100% completados.'),
    ('CPU promedio / máximo', 'API 1.43% / 2.17%; PostgreSQL 1.99% / 18.09%', 'API 0.81% / 1.99%; PostgreSQL 1.57% / 13.83%', '< 75%', 'API normalizado sobre capacidad total del host.'),
    ('Memoria promedio / máximo', 'API 69.94 / 90.91 MiB (0.44% / 0.57% RAM); DB 49.08 / 53.27 MiB (0.63% / 0.69% Docker)', 'API 91.40 / 92.46 MiB (0.57% / 0.58% RAM); DB 52.33 / 53.10 MiB (0.67% / 0.69% Docker)', '< 80%', 'Promedios/máximos porcentuales bajo referencia.'),
], [1.05, 1.05, 1.55, .9, 2.65], 7.0)
doc.add_paragraph('CPU API está normalizado sobre 20 procesadores lógicos. Para aproximar porcentaje por núcleo de k6: carga 28.6% promedio / 43.4% máximo; estrés 16.2% / 39.8%. No se midió CPU total de la máquina. El muestreo de recursos cubrió 46 muestras de carga y 60 de estrés; intervalo efectivo cercano a 2,7 s. Smoke: 154 requests sin KO, media 24 ms y p95 133 ms; recursos no muestreados por ser carga mínima.')

doc.add_heading('6.3 Desglose de tiempos por endpoint', level=2)
doc.add_paragraph('Gatling también genera media y p95 por request en sus reportes HTML. En la carga, los percentiles incluyen los KO por timeout y se ven afectados por ellos.')
add_table(['Smoke test', 'OK/KO', 'Media', 'p95', 'req/s'], [
    ('POST /api/auth/login', '22 / 0', '134 ms', '149 ms', '0.759'),
    ('GET /api/categories (3 páginas)', '66 / 0', '6 ms', '11 ms', '2.276'),
    ('GET /api/books (3 páginas)', '66 / 0', '5 ms', '9 ms', '2.276'),
], [2.5, 1.1, 1.1, 1.1, 1.05], 7.2)
add_table(['Prueba de carga', 'OK/KO', 'Media', 'p95', 'req/s'], [
    ('POST /api/auth/login', '637 / 0', '4 707 ms', '11 130 ms', '5.739'),
    ('GET /api/categories (3 páginas)', '1 911 / 0', '6 762 ms', '19 126 ms', '17.216'),
    ('GET /api/books (3 páginas)', '1 911 / 0', '3 262 ms', '16 374 ms', '17.216'),
], [2.5, 1.1, 1.1, 1.1, 1.05], 7.2)
add_table(['Prueba de estrés', 'OK/KO', 'Media', 'p95', 'req/s'], [
    ('POST /api/auth/login', '535 / 0', '3 590 ms', '10 570 ms', '3.520'),
    ('GET /api/categories (3 páginas)', '1 605 / 0', '1 625 ms', '8 812 ms', '10.559'),
    ('GET /api/books (3 páginas)', '1 605 / 0', '310 ms', '583 ms', '10.559'),
], [2.5, 1.1, 1.1, 1.1, 1.05], 7.2)
doc.add_paragraph('Frente a las referencias por endpoint del documento (media: login <400 ms y lecturas <150 ms; p95: login <800 ms y lecturas <300 ms), smoke queda dentro; carga y estrés superan los p95. El p95 de libros en estrés fue 583 ms.')
doc.add_paragraph('Gatling consulta páginas 1–3 con limit=10, alineado con el tamaño solicitado. Sus escalones de estrés (25–125) difieren de E50–E400 de k6, por lo que la comparación por nivel de concurrencia no es equivalente.')

doc.add_heading('7. Conclusiones', level=1)
doc.add_paragraph('Con tres páginas de 10 registros por lista, los tres perfiles completaron 100% de los flujos y no registraron KO. Carga alcanzó 40.171 req/s, pero media y p95 globales superaron los umbrales. Estrés llegó a 125 usuarios, con media global de 1.342 ms y p95 de 7.895 ms: la media cumple la referencia de 1.500 ms y el p95 no cumple la de 2.000 ms. Son resultados del entorno local, no extrapolables a producción.')

doc.add_heading('8. Recomendaciones', level=1)
for text in [
    'Revisar capacidad y timeouts bajo carga; comenzar las nuevas corridas con una tasa menor y aumentarla gradualmente.',
    'Repetir el perfil después de revisar la API y comparar latencia y tasa de KO.',
    'Confirmar con el docente si los umbrales del template son criterios obligatorios.',
    'Repetir los mismos perfiles en QA si el equipo dispone de ese entorno.',
]:
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.space_after = Pt(2)
    p.add_run(text)

doc.core_properties.title = 'Informe de Pruebas de Performance Eowyn Library'
doc.core_properties.subject = 'Informe resumido según el template docente'
doc.core_properties.author = 'Agustín Mendoza'
doc.save(OUT)
print(OUT)
