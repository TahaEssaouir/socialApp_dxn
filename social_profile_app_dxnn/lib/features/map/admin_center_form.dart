import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logger.dart';
import '../../core/ui.dart';
import '../auth/auth_repository.dart';
import 'service_centers_repository.dart';

class AdminCenterForm extends ConsumerStatefulWidget {
  const AdminCenterForm({super.key, this.center});

  final ServiceCenter? center;

  @override
  ConsumerState<AdminCenterForm> createState() => _AdminCenterFormState();
}

class _AdminCenterFormState extends ConsumerState<AdminCenterForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _cityController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _locationController;
  late CenterKind _kind;
  bool _saving = false;

  bool get _isEditing => widget.center != null;

  @override
  void initState() {
    super.initState();
    final ServiceCenter? center = widget.center;
    _cityController = TextEditingController(text: center?.city ?? '');
    _nameController = TextEditingController(text: center?.name ?? '');
    _addressController = TextEditingController(text: center?.address ?? '');
    _phoneController = TextEditingController(text: center?.phone ?? '');
    _emailController = TextEditingController(text: center?.email ?? '');
    _locationController = TextEditingController(text: center?.location ?? '');
    _kind = center?.kind ?? CenterKind.center;
  }

  @override
  void dispose() {
    _cityController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ServiceCentersRepository repository = ref.read(
        serviceCentersRepositoryProvider,
      );
      if (_isEditing) {
        await repository.updateCenter(
          id: widget.center!.id,
          city: _cityController.text,
          name: _nameController.text,
          kind: _kind,
          address: _addressController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          location: _locationController.text,
        );
      } else {
        await repository.createCenter(
          city: _cityController.text,
          name: _nameController.text,
          kind: _kind,
          address: _addressController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          location: _locationController.text,
        );
      }
      ref.invalidate(serviceCentersProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Centre de services modifié.'
                : 'Centre de services ajouté.',
          ),
        ),
      );
      context.pop();
    } catch (error, stack) {
      log.error(
        'Enregistrement du centre de services impossible',
        error,
        stack,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Modification impossible. Réessayez.'
                : 'Ajout impossible. Réessayez.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label requis.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = ref.watch(isAdminProvider).value ?? false;
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Centre de services')),
        body: const SerenityBackground(
          child: EmptyPane(
            icon: Icons.lock_outline,
            message: 'Accès réservé à l\'administrateur.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Modifier le centre de services'
              : 'Ajouter un centre de services',
        ),
      ),
      body: SerenityBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                20,
                24,
              ),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFB7D9D4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'DXN Maroc — centre de services',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kNavy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cityController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Ville *',
                          hintText: 'Ex. Casablanca, Tanger, Agadir',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        validator: (String? v) => _required(v, 'Ville'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<CenterKind>(
                        initialValue: _kind,
                        decoration: const InputDecoration(
                          labelText: 'Type du centre *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const <DropdownMenuItem<CenterKind>>[
                          DropdownMenuItem<CenterKind>(
                            value: CenterKind.center,
                            child: Text('Centre de services'),
                          ),
                          DropdownMenuItem<CenterKind>(
                            value: CenterKind.branch,
                            child: Text('Branche principale'),
                          ),
                        ],
                        onChanged: (CenterKind? value) {
                          if (value != null) {
                            setState(() => _kind = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nom du centre *',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: (String? v) => _required(v, 'Nom'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Lien de localisation (Google Maps)',
                          hintText: 'Ex. https://maps.app.goo.gl/…',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? 'Enregistrement…'
                              : (_isEditing ? 'Enregistrer' : 'Ajouter'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
