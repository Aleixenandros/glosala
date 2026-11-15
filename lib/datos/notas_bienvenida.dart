import '../dominio/nota.dart';
import '../dominio/boveda.dart';

Boveda bovedaBienvenida() {
  final ahora = DateTime.now();
  Nota nota(
    String id,
    String titulo,
    String carpeta,
    String contenido, {
    bool favorite = false,
  }) => Nota(
    id: id,
    titulo: titulo,
    contenido: contenido.trim(),
    carpeta: carpeta,
    creadaEl: ahora,
    modificadaEl: ahora,
    favorita: favorite,
  );
  return Boveda(
    idSeleccionada: 'welcome',
    carpetas: ['Primeros pasos', 'Personal', 'Proyectos'],
    notas: [
      nota('welcome', 'Bienvenido a Glosala', 'Primeros pasos', '''
# Un lugar para tus ideas.

Las mejores ideas empiezan con una nota. Este es tu espacio para escribir, conectar lo que aprendes y volver a encontrarlo cuando lo necesites.

> Escribe con libertad. Dale forma después.

## Hazlo tuyo

- Crea tu primera nota con el botón **Nueva nota**.
- Organiza tus ideas en **carpetas** y marca tus favoritas.
- Alterna entre **Editar**, **Dividir** y **Leer**.
- Tus cambios se guardan automáticamente en este dispositivo.

## Conecta tus ideas

Escribe un enlace como [[Guía de Markdown]] para conectar dos notas. Los **enlaces entrantes** te ayudarán a descubrir qué otras ideas apuntan a esta.

También puedes usar un nombre distinto: [[Mi primera idea|una idea por explorar]].

## Un pequeño comienzo

- [x] Encontrar un espacio para pensar
- [ ] Escribir algo que quieras recordar
- [ ] Conectar dos ideas

---

No hace falta tenerlo todo claro. Empieza por una línea.

#bienvenida #ideas
''', favorite: true),
      nota('markdown-guide', 'Guía de Markdown', 'Primeros pasos', r'''
# Guía de Markdown

Markdown te permite dar formato sin levantar las manos del teclado.

## Lo esencial

Escribe **negrita**, *cursiva* o ~~tachado~~. Usa `código` para resaltar un término técnico.

## Listas y tareas

- Una idea
- Otra idea
  - Un poco más de detalle

1. Captura
2. Conecta
3. Revisa

- [x] Aprender lo básico
- [ ] Ponerlo en práctica

## Citas y código

> Una nota es una conversación con tu yo del futuro.

```dart
final idea = 'Algo que merece ser recordado';
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

¿Qué quiero aprender, crear o recordar hoy?

## Una chispa

Un espacio en blanco también es una invitación.

## Siguiente paso

- [ ] Dedicar diez minutos a explorar esta idea

Relacionado con [[Bienvenido a Glosala]].

#ideas #personal
'''),
    ],
  );
}
