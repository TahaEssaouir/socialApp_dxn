import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Palette « Deep Teal / Serenity ».
const Color kDeepTeal = Color(0xFF005F60);
const Color kMintTeal = Color(0xFF4DB6AC);
const Color kNavy = Color(0xFF1A237E);
const Color kWarmMist = Color(0xFFE0F2F1);

const Color _surface = Color(0xFFE0F2F1);
const Color _border = Color(0xFFB7D9D4);

/// Fond dégradé bleu-vert inspiré de l'exemple.
class SerenityBackground extends StatelessWidget {
  const SerenityBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFE0F2F1),
            Color(0xFFD5EEF0),
            Color(0xFFBFE4E1),
            Color(0xFFA8D9D1),
          ],
          stops: <double>[0, 0.35, 0.7, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Centre le contenu sur grand écran sans contraindre les petits écrans.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 935});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class LoadingPane extends StatelessWidget {
  const LoadingPane({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (label != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              label!,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Avatar circulaire avec dégradé Instagram quand aucune image n'est fournie.
class BrandAvatar extends StatelessWidget {
  const BrandAvatar({super.key, required this.url, this.size = 88});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = url?.trim();
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _border, width: 2),
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (BuildContext context, String _) =>
                    const ColoredBox(color: _surface),
                errorWidget: (BuildContext context, String _, Object error) =>
                    const _GradientAvatar(),
              )
            : const _GradientAvatar(),
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  const _GradientAvatar();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[kDeepTeal, kMintTeal],
        ),
      ),
      child: Center(child: Icon(Icons.person, color: Colors.white, size: 40)),
    );
  }
}
