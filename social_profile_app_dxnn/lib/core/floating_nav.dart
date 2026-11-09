import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ui.dart';

class FloatingNav extends StatelessWidget {
  const FloatingNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, label: 'Accueil', route: '/'),
    _NavItem(
      icon: Icons.notifications_none_outlined,
      label: 'Notifications',
      route: '/notifications',
    ),
    _NavItem(icon: Icons.map_outlined, label: 'Carte', route: '/map'),
    _NavItem(icon: Icons.person_outline, label: 'Compte', route: '/login'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: SizedBox(
          width: 310,
          height: 58,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  // Fond verre fumé qui garantit le contraste même sur le fond vert clair
                  color: Colors.black.withOpacity(0.50),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    for (int index = 0; index < _items.length; index++)
                      Expanded(
                        child: _NavButton(
                          item: _items[index],
                          selected: index == currentIndex,
                          onPressed: () {
                            if (index != currentIndex) {
                              if (index == 0) {
                                context.go('/');
                              } else {
                                context.push(_items[index].route);
                              }
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Actif -> kDeepTeal (sur fond kWarmMist), Hover -> blanc vif, Inactif -> blanc texturé bien lisible
    final Color iconColor = widget.selected
        ? kDeepTeal
        : (_isHovered ? Colors.white : Colors.white.withOpacity(0.85));

    final Color circleColor = widget.selected
        ? kWarmMist
        : (_isHovered ? Colors.white.withOpacity(0.18) : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.item.label,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: widget.onPressed,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedScale(
              scale: _isHovered ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: widget.selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(widget.item.icon, color: iconColor, size: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}
