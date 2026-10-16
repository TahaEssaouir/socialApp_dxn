import 'package:flutter/material.dart';
import 'auth_page.dart'; // Importation de la page d'authentification

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Profile',
      debugShowCheckedModeBanner: false, // Supprime la petite bannière "DEBUG" en haut à droite
      
      // Configuration globale du thème sombre
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: const Color(0xFF000000), // Fond noir
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0, // Enlève l'ombre sous l'AppBar
          iconTheme: IconThemeData(color: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Color(0xFF056162), // Vert WhatsApp
        ),
      ),
      
      // La première page qui s'affiche au lancement de l'application
      home: AuthPage(), 
    );
  }
}