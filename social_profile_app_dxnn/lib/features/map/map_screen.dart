import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/floating_nav.dart';
import '../../core/logger.dart';
import '../../core/ui.dart';
import '../auth/auth_repository.dart';
import 'service_centers_repository.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  static const LatLng _moroccoCenter = LatLng(31.7917, -7.0926);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centersAsync = ref.watch(serviceCentersProvider);
    final bool isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      bottomNavigationBar: const FloatingNav(currentIndex: 2),
      appBar: AppBar(
        title: const Text('Carte des centres DXN Maroc'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Ajouter un centre de services',
              onPressed: () => context.push('/admin/center/new'),
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
        ],
      ),
      body: SerenityBackground(
        child: centersAsync.when(
          loading: () => const LoadingPane(label: 'Chargement de la carte…'),
          error: (error, _) => ErrorPane(
            message: 'Impossible de charger les centres de services.',
            onRetry: () => ref.invalidate(serviceCentersProvider),
          ),
          data: (centers) => _MapBody(centers: centers, isAdmin: isAdmin),
        ),
      ),
    );
  }
}

class _MapBody extends ConsumerWidget {
  const _MapBody({required this.centers, required this.isAdmin});

  final List<ServiceCenter> centers;
  final bool isAdmin;

  void _showCityCenters(
    BuildContext context,
    WidgetRef ref,
    String city,
    List<ServiceCenter> cityCenters,
  ) {
    log.info(
      'Ouverture du popup des centres de services — $city '
      '(${cityCenters.length} centre(s))',
    );

    _showBlurredPopup(
      context,
      Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.80,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: kDeepTeal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Centres de services — $city',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kNavy,
                        ),
                      ),
                    ),

                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close, size: 20, color: kNavy),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: cityCenters.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) {
                    final center = cityCenters[index];

                    return _CenterTile(
                      center: center,
                      isAdmin: isAdmin,
                      onEdit: isAdmin
                          ? () {
                              Navigator.pop(context);

                              context.push('/admin/center/edit', extra: center);
                            }
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Arrière-plan flouté partagé par tous les popups de la carte.
  void _showBlurredPopup(BuildContext context, Widget content) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.transparent,
      pageBuilder: (_, _, _) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: kNavy.withValues(alpha: 0.35),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: content,
        ),
      ),
    );
  }

  void _showCitiesPopup(
    BuildContext context,
    WidgetRef ref,
    List<MapEntry<String, List<ServiceCenter>>> entries,
  ) {
    log.info('Ouverture de la liste des villes (${entries.length})');

    _showBlurredPopup(
      context,
      Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.9,
            maxHeight: MediaQuery.sizeOf(context).height * 0.60,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city, color: kDeepTeal),
                    const SizedBox(width: 8),
                    Text(
                      'Villes du Maroc (${entries.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kNavy,
                      ),
                    ),

                    const Spacer(),

                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close, size: 20, color: kNavy),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (_, index) {
                    final entry = entries[index];

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);

                        _showCityCenters(context, ref, entry.key, entry.value);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 18,
                              color: kDeepTeal,
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: kNavy,
                                ),
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kWarmMist,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${entry.value.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kDeepTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byCity = groupCentersByCity(centers);
    final entries = byCity.entries.toList();

    final List<Marker> markers = [];

    for (final entry in entries) {
      final LatLng? coords = coordsForCity(entry.key);

      if (coords == null) continue;

      markers.add(
        Marker(
          point: coords,
          width: 48,
          height: 54,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showCityCenters(context, ref, entry.key, entry.value),
            child: Tooltip(
              message: '${entry.key} (${entry.value.length})',
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 48,
                    color: kDeepTeal,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${entry.value.length}',
                          style: const TextStyle(
                            color: kDeepTeal,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final unmappedCities = entries
        .where((entry) => coordsForCity(entry.key) == null)
        .map((entry) => entry.key)
        .toList();

    log.debug('Carte affichée avec un décalage vertical de 48 px');

    return Column(
      children: [
        // La carte est davantage décalée sous l'AppBar translucide.

        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 32, 12, 0),
            child: Transform.translate(
              offset: const Offset(0, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: MapScreen._moroccoCenter,
                        initialZoom: 5.4,
                        minZoom: 4.5,
                        maxZoom: 12,
                        // Carte du Maroc uniquement : la caméra ne
                        // peut pas quitter les frontières du Maroc.
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            const LatLng(20.8, -17.3),
                            const LatLng(36.2, -0.9),
                          ),
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.dxn.social_profile_app_dxn',
                        ),
                        MarkerLayer(markers: markers),
                        const RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              '© OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (centers.isEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Aucun centre de services pour le moment.',
                                style: TextStyle(color: kNavy),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Liste des villes : un seul bouton superposé sur la
                    // carte, remonté au-dessus du FloatingNav (la carte
                    // est décalée de 16 px vers le bas).
                    if (entries.isNotEmpty)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 32,
                        child: Center(
                          child: Material(
                            color: Colors.white,
                            elevation: 3,
                            shadowColor: Colors.black26,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () =>
                                  _showCitiesPopup(context, ref, entries),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_city,
                                      size: 18,
                                      color: kDeepTeal,
                                    ),

                                    const SizedBox(width: 8),

                                    Text(
                                      'Villes du Maroc (${entries.length})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: kDeepTeal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (unmappedCities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'Position approximative non disponible pour : '
              '${unmappedCities.join(', ')} '
              '(ouvrez la liste des villes pour les consulter).',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 72),
      ],
    );
  }
}

class _CenterTile extends ConsumerWidget {
  const _CenterTile({required this.center, required this.isAdmin, this.onEdit});

  final ServiceCenter center;
  final bool isAdmin;
  final VoidCallback? onEdit;

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le lien.')),
      );
    }
  }

  Uri buildMapsUri(ServiceCenter center) {
    final String raw = center.location?.trim() ?? '';

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final Uri? parsed = Uri.tryParse(raw);

      if (parsed != null) {
        return parsed;
      }
    }

    if (raw.isNotEmpty) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': raw,
      });
    }

    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${center.city}, Maroc',
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                center.kind == CenterKind.branch
                    ? Icons.corporate_fare
                    : Icons.storefront,
                size: 16,
                color: kMintTeal,
              ),

              const SizedBox(width: 6),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kWarmMist,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  center.kind.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kDeepTeal,
                  ),
                ),
              ),

              const Spacer(),

              if (isAdmin) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined, size: 20, color: kNavy),
                  onPressed: onEdit,
                ),

                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Supprimer',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Supprimer ce centre ?'),
                        content: Text(center.name),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true || !context.mounted) {
                      return;
                    }

                    try {
                      await ref
                          .read(serviceCentersRepositoryProvider)
                          .deleteCenter(center.id);

                      ref.invalidate(serviceCentersProvider);

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Centre supprimé.')),
                      );
                    } catch (error, stack) {
                      log.error(
                        'Suppression du centre impossible',
                        error,
                        stack,
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Suppression impossible.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          Text(
            center.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: kNavy,
            ),
          ),

          const SizedBox(height: 4),

          // ADRESSE
          if ((center.address ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                center.address!,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),

          // TOUS LES NUMEROS DE TELEPHONE
          for (final String phone in center.phones)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () =>
                    _launchUri(context, Uri(scheme: 'tel', path: phone)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: kDeepTeal,
                    ),

                    const SizedBox(width: 4),

                    Flexible(
                      child: Text(
                        phone,
                        style: const TextStyle(
                          color: kDeepTeal,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // TOUTES LES ADRESSES EMAIL
          for (final String email in center.emails)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () =>
                    _launchUri(context, Uri(scheme: 'mailto', path: email)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: kDeepTeal,
                    ),

                    const SizedBox(width: 4),

                    Flexible(
                      child: Text(
                        email,
                        style: const TextStyle(color: kDeepTeal, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 14),

          FilledButton.tonalIcon(
            onPressed: () => _launchUri(context, buildMapsUri(center)),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ouvrir dans Google Maps'),
          ),
        ],
      ),
    );
  }
}
