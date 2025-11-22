abstract class DashboardEvent {
  const DashboardEvent();
}

/// Evento para cargar las estadísticas del dashboard del usuario actual
class LoadDashboardStats extends DashboardEvent {
  const LoadDashboardStats();
}

/// Evento para cargar las estadísticas del dashboard de un médico específico
class LoadDashboardStatsFor extends DashboardEvent {
  final String doctorId;
  final String? specialty;
  
  const LoadDashboardStatsFor(this.doctorId, {this.specialty});
}