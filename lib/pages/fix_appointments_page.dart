import 'package:flutter/material.dart';
import '../utils/fix_doctor_appointments.dart';

/// Página para corregir las citas de jessica.rodriguez
class FixAppointmentsPage extends StatefulWidget {
  const FixAppointmentsPage({super.key});

  @override
  State<FixAppointmentsPage> createState() => _FixAppointmentsPageState();
}

class _FixAppointmentsPageState extends State<FixAppointmentsPage> {
  bool _isLoading = false;
  String _resultMessage = '';

  Future<void> _runDryRun() async {
    setState(() {
      _isLoading = true;
      _resultMessage = 'Ejecutando prueba (dry run)...';
    });

    try {
      await FixDoctorAppointments.fixJessicaRodriguezAppointments(dryRun: true);
      setState(() {
        _resultMessage = '✅ Prueba completada. Revisa la consola para ver los detalles.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _resultMessage = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyFix() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Estás seguro?'),
        content: const Text(
          'Esta acción actualizará todas las citas de jessica.rodriguez en Firebase. '
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _resultMessage = 'Aplicando correcciones...';
    });

    try {
      await FixDoctorAppointments.fixJessicaRodriguezAppointments(dryRun: false);
      setState(() {
        _resultMessage = '✅ Correcciones aplicadas correctamente. Revisa la consola para ver los detalles.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _resultMessage = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corregir Citas de Jessica Rodriguez'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Corrección de Citas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Esta herramienta busca y actualiza todas las citas de jessica.rodriguez '
                      'para que coincidan con su UID correcto en Firebase.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Primero ejecuta una prueba (Dry Run) para ver qué se actualizaría.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '2. Si todo está correcto, aplica los cambios.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runDryRun,
              icon: const Icon(Icons.search),
              label: const Text('Ejecutar Prueba (Dry Run)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _applyFix,
              icon: const Icon(Icons.check_circle),
              label: const Text('Aplicar Correcciones'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_resultMessage.isNotEmpty)
              Card(
                color: _resultMessage.contains('❌')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _resultMessage,
                    style: TextStyle(
                      color: _resultMessage.contains('❌')
                          ? Colors.red.shade900
                          : Colors.green.shade900,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nota:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Los resultados detallados se muestran en la consola de depuración. '
                      'Abre la consola del navegador (F12) o la terminal para ver los logs.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

