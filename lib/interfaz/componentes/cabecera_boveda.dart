// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../idiomas/gestor_idiomas.dart';
import 'controles_ventana.dart';

class CabeceraBoveda extends StatelessWidget {
  const CabeceraBoveda({super.key, required this.alCrear});
  final VoidCallback alCrear;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: ZonaArrastreVentana(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Glosala',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(fontSize: 11),
            ),
            onPressed: alCrear,
            icon: const Icon(Icons.add, size: 16),
            label: Text(t('Nueva nota')),
          ),
        ],
      ),
    ),
  );
}
