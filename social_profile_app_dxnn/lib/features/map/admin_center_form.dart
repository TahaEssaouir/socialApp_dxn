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
  late final TextEditingController _locationController;

  final List<TextEditingController> _phoneControllers = [];
  final List<TextEditingController> _emailControllers = [];

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
    _locationController = TextEditingController(text: center?.location ?? '');

    _phoneControllers.addAll(_initialContacts(center?.phones ?? []));

    _emailControllers.addAll(_initialContacts(center?.emails ?? []));

    _kind = center?.kind ?? CenterKind.center;
  }

  List<TextEditingController> _initialContacts(List<String> contacts) {
    final values = contacts.isEmpty ? <String>[''] : contacts;

    return values.map((value) => TextEditingController(text: value)).toList();
  }

  List<String> _contactList(List<TextEditingController> controllers) {
    return controllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  void _addContact(List<TextEditingController> controllers) {
    setState(() {
      controllers.add(TextEditingController());
    });
  }

  void _removeContact(List<TextEditingController> controllers, int index) {
    if (controllers.length == 1) {
      controllers.first.clear();
      return;
    }

    final removed = controllers[index];

    setState(() {
      controllers.removeAt(index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      removed.dispose();
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _locationController.dispose();

    for (final controller in _phoneControllers) {
      controller.dispose();
    }

    for (final controller in _emailControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label requis.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();

    if (email.isEmpty) return null;

    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!regex.hasMatch(email)) {
      return 'Adresse e-mail invalide.';
    }

    return null;
  }

  Widget _contactFields({
    required String label,
    required IconData icon,
    required TextInputType keyboard,
    required List<TextEditingController> controllers,
    required String addLabel,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < controllers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ObjectKey(controllers[i]),
                  controller: controllers[i],
                  keyboardType: keyboard,
                  decoration: InputDecoration(
                    labelText: '$label ${i + 1}',
                    prefixIcon: Icon(icon),
                  ),
                  validator: validator,
                ),
              ),

              const SizedBox(width: 4),

              IconButton(
                tooltip: 'Supprimer $label ${i + 1}',
                onPressed: _saving
                    ? null
                    : () => _removeContact(controllers, i),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 4),

        TextButton.icon(
          onPressed: _saving ? null : () => _addContact(controllers),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(addLabel),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final repository = ref.read(serviceCentersRepositoryProvider);

      final phones = _contactList(_phoneControllers);
      final emails = _contactList(_emailControllers);

      if (_isEditing) {
        await repository.updateCenter(
          id: widget.center!.id,
          city: _cityController.text,
          name: _nameController.text,
          kind: _kind,
          address: _addressController.text,
          phones: phones,
          emails: emails,
          location: _locationController.text,
        );
      } else {
        await repository.createCenter(
          city: _cityController.text,
          name: _nameController.text,
          kind: _kind,
          address: _addressController.text,
          phones: phones,
          emails: emails,
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

      if (!mounted) return;

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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
                    children: [
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
                        validator: (v) => _required(v, 'Ville'),
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<CenterKind>(
                        initialValue: _kind,
                        decoration: const InputDecoration(
                          labelText: 'Type du centre *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem<CenterKind>(
                            value: CenterKind.center,
                            child: Text('Centre de services'),
                          ),
                          DropdownMenuItem<CenterKind>(
                            value: CenterKind.branch,
                            child: Text('Branche principale'),
                          ),
                        ],
                        onChanged: (value) {
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
                        validator: (v) => _required(v, 'Nom'),
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

                      _contactFields(
                        label: 'Téléphone',
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        controllers: _phoneControllers,
                        addLabel: 'Ajouter un numéro de téléphone',
                      ),

                      const SizedBox(height: 12),

                      _contactFields(
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        controllers: _emailControllers,
                        addLabel: 'Ajouter une adresse e-mail',
                        validator: _validateEmail,
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
