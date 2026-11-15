import '../dominio/nota.dart';
import '../dominio/boveda.dart';

// Muestra breve de Chiquito Ipsum: https://github.com/daviddavo/fistrum#readme.
// El resto de los ejemplos está redactado para Glosala.

Boveda bovedaBienvenida() {
  final ahora = DateTime.now();
  Nota nota(
    String id,
    String titulo,
    String carpeta,
    String contenido, {
    bool favorita = false,
  }) => Nota(
    id: id,
    titulo: titulo,
    contenido: contenido.trim(),
    carpeta: carpeta,
    creadaEl: ahora,
    modificadaEl: ahora,
    favorita: favorita,
  );
  return Boveda(
    idSeleccionada: 'welcome',
    carpetas: ['Primeros pasos', 'Personal', 'Proyectos'],
    notas: [
      nota('welcome', 'Bienvenido a Glosala', 'Primeros pasos', '''
# Un lugar para tus ideas… ¡con mucho arte!

Aquí caben tus grandes planes, la lista de la compra y esa ocurrencia que llega justo cuando apagas la luz. Vamos a darles una casa antes de que salgan corriendo.

> Lorem fistrum quietooor fistro qué dise usteer quietooor va usté muy cargadoo.

Una pizca de [Chiquito Ipsum](https://www.chiquitoipsum.com/) para estrenar la bóveda con una sonrisa.

## Hazlo tuyo

- Crea tu primera nota con el botón **Nueva nota**.
- Organiza tus ideas en **carpetas** y marca tus favoritas.
- Alterna entre **Editar**, **Dividir** y **Leer**.
- Tus cambios se guardan automáticamente en este dispositivo.

## Conecta tus ideas

Escribe un enlace como [[Guía de Markdown]] para conectar dos notas. Los **enlaces entrantes** te ayudarán a descubrir qué otras ideas apuntan a esta.

También puedes usar un nombre distinto: [[Mi primera idea|una idea por explorar]].

## Un pequeño comienzo

- [x] Encontrar un sitio para las ideas
- [ ] Apuntar esa genialidad antes del café
- [ ] Conectar dos notas sin hacer un nudo

---

Empieza por una línea. La obra maestra puede esperar a que vuelva la inspiración de merendar.

#bienvenida #ideas
''', favorita: true),
      nota('markdown-guide', 'Guía de Markdown', 'Primeros pasos', r'''
# Guía de Markdown

Markdown pone guapo el texto con cuatro símbolos. El teclado hace el trabajo y tú te llevas los aplausos.

## Lo esencial

Escribe **negrita**, *cursiva* o ~~tachado~~. Usa `código` para resaltar un término técnico.

## Listas y tareas

- Preparar una idea con fundamento
- Añadirle una chispa de humor
  - Sin pasarse con los fuegos artificiales

1. Captura la ocurrencia
2. Conecta los puntos
3. Revisa antes de dar la vuelta al ruedo

- [x] Aprender lo básico
- [ ] Ponerlo en práctica

## Citas y código

> Por la gloria de mi madre

Una cita para practicar el formato; la documentación importante también merece una sonrisa.

```dart
final idea = 'Una idea con más arte que una libreta en feria';
print(idea);
```

## Tablas

| Sintaxis | Resultado |
| --- | --- |
| `# Título` | Encabezado |
| `**texto**` | Negrita |
| `[[Una nota]]` | Enlace interno |
| `#etiqueta` | Etiqueta |

## Enlaces

Vuelve a [[Bienvenido a Glosala]] o visita la [guía de Markdown](https://www.markdownguide.org/basic-syntax/).

#guía #markdown
'''),
      nota('first-idea', 'Mi primera idea', 'Personal', '''
# Mi primera idea

Operación: convertir una ocurrencia de sobremesa en un proyecto que no se quede dormido en el sofá.

## Una chispa

Si aparece el síndrome de «No puedor», escribe una frase pequeña. Una. La segunda suele venir a cotillear.

## Siguiente paso

- [ ] Dedicar diez minutos a explorar esta idea
- [ ] Anotar una pregunta que merezca la pena
- [ ] Celebrar el avance, aunque sea con una galleta

Hasta luego, Lucas. La nota se queda aquí esperándote.

Relacionado con [[Bienvenido a Glosala]].

#ideas #personal
'''),
    ],
  );
}
