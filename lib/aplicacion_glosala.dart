// Compatibilidad con el renderizador Markdown hasta su migración a material_ui.
// ignore_for_file: deprecated_member_use

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';

import 'aplicacion/controlador_boveda.dart';
import 'datos/fabrica_repositorio.dart';
import 'interfaz/tema_aplicacion.dart';
import 'interfaz/pantalla_espacio.dart';
import 'idiomas/gestor_idiomas.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InicioGlosala());
}

class InicioGlosala extends StatefulWidget {
  const InicioGlosala({super.key});

  @override
  State<InicioGlosala> createState() => _EstadoInicioGlosala();
}

class _EstadoInicioGlosala extends State<InicioGlosala> {
  ControladorBoveda? _controlador;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() => _error = null);
    try {
      await GestorIdiomas.instancia.cargar();
      final repositorio = await crearRepositorioBoveda();
      final controller = ControladorBoveda(repositorio);
      await controller.inicializar();
      for (final codigo in GestorIdiomas.disponibles.keys) {
        final fuente = controller.preferencias['idioma_xml_$codigo'];
        if (fuente is String) GestorIdiomas.instancia.aplicar(codigo, fuente);
      }
      final idioma = controller.preferencias['idioma'] as String? ?? 'es';
      GestorIdiomas.instancia.actual =
          GestorIdiomas.disponibles.containsKey(idioma) ? idioma : 'es';
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controlador = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controlador?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controlador != null) {
      return AplicacionGlosala(controller: _controlador!);
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TemaAplicacion.build(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se ha podido abrir el almacenamiento.'),
                      const SizedBox(height: 12),
                      SelectableText('$_error'),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _inicializar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class AplicacionGlosala extends StatelessWidget {
  const AplicacionGlosala({super.key, required this.controller});
  final ControladorBoveda controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'Glosala',
      debugShowCheckedModeBanner: false,
      locale: Locale(GestorIdiomas.instancia.actual),
      supportedLocales: GestorIdiomas.disponibles.keys.map(Locale.new).toList(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: TemaAplicacion.build(
        Brightness.light,
        tema: controller.preferencias['tema'] as String? ?? 'amatista',
      ),
      darkTheme: TemaAplicacion.build(
        Brightness.dark,
        tema: controller.preferencias['tema'] as String? ?? 'amatista',
      ),
      themeMode: switch (controller.preferencias['apariencia']) {
        'sistema' => ThemeMode.system,
        'claro' => ThemeMode.light,
        'oscuro' => ThemeMode.dark,
        _ => controller.modoOscuro ? ThemeMode.dark : ThemeMode.light,
      },
      home: PantallaEspacio(controller: controller),
    ),
  );
}
