import 'package:flutter/material.dart';

void main() {
  runApp(const SocialDashboardApp());
}

class SocialDashboardApp extends StatelessWidget {
  const SocialDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Couleur de fond sombre type Instagram
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
        ),
      ),
      home: const ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Variables qui deviendront dynamiques plus tard avec l'API
  String facebookFollowers = "12K";
  String youtubeFollowers = "5.4K";
  String tiktokFollowers = "10K";
  String instagramFollowers = "8.5K";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.add_box_outlined),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 16),
            SizedBox(width: 8),
            Text(
              'nxt_taha',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Zone Avatar et Statistiques
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // Avatar (à remplacer par ton logo)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade800, width: 2),
                      image: const DecorationImage(
                        image: NetworkImage('https://via.placeholder.com/150'), // Placeholder
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // Les 4 compteurs
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(facebookFollowers, 'Facebook'),
                        _buildStatColumn(youtubeFollowers, 'YouTube'),
                        _buildStatColumn(tiktokFollowers, 'TikTok'),
                        _buildStatColumn(instagramFollowers, 'Instagram'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Zone Bio
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nxt Taha',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 4),
                  Text('🔥 Pubg mobile 🔥\n🇲🇦'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Boutons d'action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Action pour forcer l'actualisation
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF262626), // Gris foncé
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Actualiser Stats'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF262626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Gérer API'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.person_add_outlined, size: 20),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            
            // 4. Espace pour la grille de contenu (optionnel pour plus tard)
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Graphiques d\'évolution à venir...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget réutilisable pour afficher une colonne de statistiques
  Widget _buildStatColumn(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}