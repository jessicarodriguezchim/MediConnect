import '../models/appointment_model.dart';

class LoadDashboardStatsFor extends DashboardEvent {
	final String doctorId;
	final String? specialty;
	LoadDashboardStatsFor(this.doctorId, {this.specialty});
}

abstract class DashboardEvent {
	const DashboardEvent();
}

/// Evento para cargar la información general del dashboard (estadísticas)
class LoadDashboardStats extends DashboardEvent {
	const LoadDashboardStats();
}

/// Evento genérico para recargar la lista de citas (si se necesita)
class LoadDashboard extends DashboardEvent {
	const LoadDashboard();
}

/// Evento para crear una nueva cita
class AddAppointment extends DashboardEvent {
	final AppointmentModel appointment;
	const AddAppointment(this.appointment);
}

/// Evento para actualizar una cita existente
class UpdateAppointment extends DashboardEvent {
	final String appointmentId;
	final AppointmentModel updatedAppointment;
	const UpdateAppointment(this.appointmentId, this.updatedAppointment);
}

/// Evento para eliminar una cita
class DeleteAppointment extends DashboardEvent {
	final String appointmentId;
	const DeleteAppointment(this.appointmentId);
}