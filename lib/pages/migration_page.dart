import 'package:flutter/material.dart';
import '../utils/migrate_citas_to_appointments.dart';

/// Página para ejecutar la migración de 'citas' a 'appointments'
/// 
/// Esta página permite:
/// 1. Ver cuántas citas hay en cada colección
/// 2. Ejecutar una migración en modo DRY RUN (sin cambios)
/// 3. Ejecutar la migración real
/// 
/// IMPORTANTE: Hacer backup de Firebase antes de ejecutar la migración real
class MigrationPage extends StatefulWidget {
  const MigrationPage({super.key});

  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  bool _isLoading = false;
  bool _dryRun = true;
  Map<String, int>? _counts;
  Map<String, dynamic>? _migrationResult;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    try {
      final counts = await CitasMigrationService.checkCollectionCounts();
      setState(() {
        _counts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando conteos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _runMigration() async {
    setState(() {
      _isLoading = true;
      _migrationResult = null;
    });

    try {
      final result = await CitasMigrationService.migrateAllCitas(
        dryRun: _dryRun,
      );

      setState(() {
        _migrationResult = result;
        _isLoading = false;
      });

      // Recargar conteos después de la migración
      if (!_dryRun && result['success'] == true) {
        await _loadCounts();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: result['success'] == true ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en migración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migración de Citas'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información sobre las colecciones
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de las Colecciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_counts != null) ...[
                      _buildCountRow('citas (legacy)', _counts!['citas'] ?? 0, Colors.orange),
                      const SizedBox(height: 8),
                      _buildCountRow('appointments (nueva)', _counts!['appointments'] ?? 0, Colors.green),
                    ] else
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Información importante
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Información Importante',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• La colección "citas" es legacy y será eliminada gradualmente\n'
                    '• La colección "appointments" es la nueva y estandarizada\n'
                    '• Se recomienda hacer backup de Firebase antes de migrar\n'
                    '• Usa DRY RUN primero para ver qué se migrará',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Opciones de migración
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Opciones de Migración',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Modo DRY RUN (solo simulación)'),
                      subtitle: const Text(
                        'Muestra qué se migraría sin hacer cambios reales',
                      ),
                      value: _dryRun,
                      onChanged: (value) {
                        setState(() => _dryRun = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runMigration,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_dryRun ? 'Ejecutar DRY RUN' : 'Ejecutar Migración Real'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _dryRun ? Colors.blue : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Resultados
            if (_migrationResult != null) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                color: _migrationResult!['success'] == true
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resultados de la Migración',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _migrationResult!['success'] == true
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildResultRow('Total de citas', _migrationResult!['total']),
                      _buildResultRow('Migradas', _migrationResult!['migrated'], Colors.green),
                      _buildResultRow('Omitidas', _migrationResult!['skipped'], Colors.blue),
                      _buildResultRow('Errores', _migrationResult!['errors'], Colors.red),
                      if (_migrationResult!['errorMessages'] != null &&
                          (_migrationResult!['errorMessages'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Mensajes de error:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...(_migrationResult!['errorMessages'] as List)
                            .map((msg) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $msg',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ))
                            .toList(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, dynamic value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

