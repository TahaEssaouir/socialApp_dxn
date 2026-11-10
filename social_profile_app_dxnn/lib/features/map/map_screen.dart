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
    final AsyncValue<List<ServiceCenter>> centersAsync = ref.watch(
      serviceCentersProvider,
    );
    final bool isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      bottomNavigationBar: const FloatingNav(currentIndex: 2),
      appBar: AppBar(
        title: const Text('Carte du Maroc'),
        actions: <Widget>[
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
          error: (Object error, _) => ErrorPane(
            message: 'Impossible de charger la carte.',
            onRetry: () => ref.invalidate(serviceCentersProvider),
          ),
          data: (List<ServiceCenter> centers) =>
              _MapBody(centers: centers, isAdmin: isAdmin),
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
    String cityName,
    List<ServiceCenter> cityCenters,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.80,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.location_on, color: kDeepTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Centres de services — $cityName',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (cityCenters.isEmpty) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: const Text(
                        'Aucun centre de services dans cette ville pour le moment.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                    if (isAdmin)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          context.push(
                            Uri(
                              path: '/admin/center/new',
                              queryParameters: <String, String>{
                                'city': cityName,
                              },
                            ).toString(),
                          );
                        },
                        icon: const Icon(
                          Icons.add_location_alt_outlined,
                          size: 18,
                        ),
                        label: Text('Ajouter un centre à $cityName'),
                      ),
                  ] else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: cityCenters.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (BuildContext _, int index) {
                          final ServiceCenter center = cityCenters[index];
                          return _CenterTile(
                            center: center,
                            isAdmin: isAdmin,
                            onEdit: isAdmin
                                ? () {
                                    Navigator.pop(sheetContext);
                                    context.push(
                                      '/admin/center/edit',
                                      extra: center,
                                    );
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
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, List<ServiceCenter>> byCityKey = groupCentersByCity(
      centers,
    );

    // Un marqueur par ville du Maroc, avec badge si la ville a des centres.
    final List<Marker> markers = <Marker>[];
    for (final MoroccoCity city in kMoroccoCities) {
      final List<ServiceCenter> cityCenters =
          byCityKey[normalizeCityKey(city.name)] ?? const <ServiceCenter>[];
      markers.add(
        Marker(
          point: city.position,
          width: 48,
          height: 54,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showCityCenters(context, ref, city.name, cityCenters),
            child: _CityPin(cityName: city.name, count: cityCenters.length),
          ),
        ),
      );
    }

    // Villes saisies avant la liste officielle (repli, sans coordonnées).
    final List<MapEntry<String, List<ServiceCenter>>> unmappedEntries =
        byCityKey.entries
            .where(
              (MapEntry<String, List<ServiceCenter>> entry) =>
                  moroccoCityByName(entry.value.first.city) == null,
            )
            .toList(growable: false);

    return Column(
      children: <Widget>[
        SizedBox(height: MediaQuery.paddingOf(context).top + kToolbarHeight),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: <Widget>[
                  FlutterMap(
                    options: const MapOptions(
                      initialCenter: MapScreen._moroccoCenter,
                      initialZoom: 5.4,
                      minZoom: 4.5,
                      maxZoom: 12,
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.dxn.social_profile_app_dxn',
                      ),
                      MarkerLayer(markers: markers),
                      const RichAttributionWidget(
                        attributions: <SourceAttribution>[
                          TextSourceAttribution('© OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                  if (unmappedEntries.isNotEmpty)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Villes non localisées : '
                            '${unmappedEntries.map((MapEntry<String, List<ServiceCenter>> e) => e.value.first.city).join(', ')}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
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
        if (unmappedEntries.isNotEmpty)
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              scrollDirection: Axis.horizontal,
              itemCount: unmappedEntries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext _, int index) {
                final MapEntry<String, List<ServiceCenter>> entry =
                    unmappedEntries[index];
                return ActionChip(
                  avatar: const Icon(Icons.place, size: 16, color: kDeepTeal),
                  label: Text(
                    '${entry.value.first.city} (${entry.value.length})',
                  ),
                  onPressed: () => _showCityCenters(
                    context,
                    ref,
                    entry.value.first.city,
                    entry.value,
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 72),
      ],
    );
  }
}

class _CityPin extends StatelessWidget {
  const _CityPin({required this.cityName, required this.count});

  final String cityName;
  final int count;

  @override
  Widget build(BuildContext context) {
    final bool hasCenters = count > 0;
    return Tooltip(
      message: hasCenters ? '$cityName ($count)' : cityName,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Icon(
            Icons.location_on,
            size: hasCenters ? 46 : 34,
            color: hasCenters ? kDeepTeal : kMintTeal,
            shadows: const <Shadow>[
              Shadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          if (hasCenters)
            Positioned(
              top: 7,
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
                    '$count',
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
      if (parsed != null) return parsed;
    }
    if (raw.isNotEmpty) {
      return Uri.https('www.google.com', '/maps/search/', <String, String>{
        'api': '1',
        'query': raw,
      });
    }
    return Uri.https('www.google.com', '/maps/search/', <String, String>{
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
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
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
              if (isAdmin) ...<Widget>[
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
                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) => AlertDialog(
                        title: const Text('Supprimer ce centre ?'),
                        content: Text(center.name),
                        actions: <Widget>[
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
                    if (confirmed != true || !context.mounted) return;
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
          for (final String phone in center.phones)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () =>
                    _launchUri(context, Uri(scheme: 'tel', path: phone.trim())),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: kDeepTeal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: kDeepTeal,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final String email in center.emails)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () => _launchUri(
                  context,
                  Uri(scheme: 'mailto', path: email.trim()),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
