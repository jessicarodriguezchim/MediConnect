import 'package:flutter/material.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {

  // NUEVO: Lista local de mensajes (placeholders)
  final List<Map<String, String>> mensajes = [
    {
      "remitente": "Dr. Ramírez",
      "hora": "10:45 AM",
      "mensaje": "Hola, recuerda tu cita mañana temprano."
    },
    {
      "remitente": "Clínica Central",
      "hora": "9:12 AM",
      "mensaje": "Tus resultados están disponibles."
    },
    {
      "remitente": "Nutrióloga Pérez",
      "hora": "Ayer",
      "mensaje": "No olvides enviar tu registro semanal."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mensajes")),

      // NUEVO: Listado dinámico con ListView.builder
      body: ListView.builder(
        itemCount: mensajes.length,
        itemBuilder: (context, index) {

          final mensaje = mensajes[index];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text(
                mensaje["remitente"]!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(mensaje["mensaje"]!),
              trailing: Text(mensaje["hora"]!),

              // NUEVO: Gesto para abrir detalles del mensaje
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(mensaje["remitente"]!),
                    content: Text(mensaje["mensaje"]!),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cerrar"),
                      )
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),

      // NUEVO: Botón para simular agregar un mensaje nuevo
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          setState(() {
            mensajes.add({
              "remitente": "Sistema Médico",
              "hora": "Ahora",
              "mensaje": "Nuevo mensaje automático de prueba."
            });
          });
        },
      ),
    );
  }
}