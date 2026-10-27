import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const Color _surface = Color(0xFF121212);
const Color _border = Color(0xFF262626);

/// Centre le contenu sur grand écran sans contraindre les petits écrans.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 935,
  });

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
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({
    super.key,
    required this.icon,
    required this.message,
  });

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
            Icon(icon, size: 44, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({
    super.key,
    required this.message,
    this.onRetry,
  });

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
            const Icon(Icons.cloud_off_outlined, size: 44, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
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
  const BrandAvatar({
    super.key,
    required this.url,
    this.size = 88,
  });

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
                errorWidget: (
                  BuildContext context,
                  String _,
                  Object error,
                ) => const _GradientAvatar(),
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
          colors: <Color>[Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
        ),
      ),
      child: Center(
        child: Icon(Icons.person, color: Colors.white, size: 40),
      ),
    );
  }
}
