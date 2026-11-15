// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../idiomas/gestor_idiomas.dart';

class DialogoTexto extends StatefulWidget {
  const DialogoTexto({
    super.key,
    required this.titulo,
    this.inicial = '',
    this.validar,
  });
  final String titulo;
  final String inicial;
  final String? Function(String)? validar;
  @override
  State<DialogoTexto> createState() => _EstadoDialogoTexto();
}

class _EstadoDialogoTexto extends State<DialogoTexto> {
  late final _texto = TextEditingController(text: widget.inicial);
  String? _error;
  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _guardar() {
    final valor = _texto.text.trim();
    final error = valor.isEmpty
        ? t('Escribe un nombre.')
        : widget.validar?.call(valor);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    content: SizedBox(
      width: 400,
      child: TextField(
        controller: _texto,
        autofocus: true,
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _guardar(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('Cancelar')),
      ),
      FilledButton(onPressed: _guardar, child: Text(t('Guardar'))),
    ],
  );
}
