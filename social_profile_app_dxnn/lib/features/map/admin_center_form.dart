import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logger.dart';
import '../../core/ui.dart';
import '../auth/auth_repository.dart';
import 'service_centers_repository.dart';

class AdminCenterForm extends ConsumerStatefulWidget {
  const AdminCenterForm({super.key, this.center, this.initialCity});

  final ServiceCenter? center;

  /// Ville présélectionnée (depuis la carte : « Ajouter un centre à … »).
  final String? initialCity;

  @override
  ConsumerState<AdminCenterForm> createState() => _AdminCenterFormState();
}

class _AdminCenterFormState extends ConsumerState<AdminCenterForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _cityController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final List<TextEditingController> _phoneControllers =
      <TextEditingController>[];
  final List<TextEditingController> _emailControllers =
      <TextEditingController>[];
  late CenterKind _kind;
  bool _saving = false;

  bool get _isEditing => widget.center != null;

  @override
  void initState() {
    super.initState();
    final ServiceCenter? center = widget.center;
    final String initialCity = (center?.city ?? widget.initialCity ?? '')
        .trim();
    _cityController = TextEditingController(text: initialCity);
    _nameController.text = center?.name ?? '';
    _addressController.text = center?.address ?? '';
    _locationController.text = center?.location ?? '';
    if (center != null) {
      for (final String phone in center.phones) {
        _phoneControllers.add(TextEditingController(text: phone));
      }
      for (final String email in center.emails) {
        _emailControllers.add(TextEditingController(text: email));
      }
    }
    if (_phoneControllers.isEmpty) {
      _phoneControllers.add(TextEditingController());
    }
    if (_emailControllers.isEmpty) {
      _emailControllers.add(TextEditingController());
    }
    _kind = center?.kind ?? CenterKind.center;
  }

  @override
  void dispose() {
    _cityController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    for (final TextEditingController controller in _phoneControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller in _emailControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPhoneField() {
    setState(() => _phoneControllers.add(TextEditingController()));
  }

  void _addEmailField() {
    setState(() => _emailControllers.add(TextEditingController()));
  }

  void _removePhoneField(int index) {
    setState(() {
      final TextEditingController controller = _phoneControllers.removeAt(
        index,
      );
      controller.dispose();
    });
  }

  void _removeEmailField(int index) {
    setState(() {
      final TextEditingController controller = _emailControllers.removeAt(
        index,
      );
      controller.dispose();
    });
  }

  List<String> _values(List<TextEditingController> controllers) => controllers
      .map((TextEditingController controller) => controller.text.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);

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
          phones: _values(_phoneControllers),
          emails: _values(_emailControllers),
          location: _locationController.text,
        );
      } else {
        await repository.createCenter(
          city: _cityController.text,
          name: _nameController.text,
          kind: _kind,
          address: _addressController.text,
          phones: _values(_phoneControllers),
          emails: _values(_emailControllers),
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

  /// Options de villes : toutes les villes du Maroc + la ville courante si
  /// elle n'est pas dans la liste (données saisies avant la liste officielle).
  List<String> get _cityOptions {
    final Set<String> options = <String>{
      for (final MoroccoCity city in kMoroccoCities) city.name,
    };
    final String current = _cityController.text.trim();
    if (current.isNotEmpty) options.add(current);
    return options.toList()..sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
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
                      DropdownButtonFormField<String>(
                        initialValue: _cityController.text.trim().isEmpty
                            ? null
                            : _cityController.text.trim(),
                        decoration: const InputDecoration(
                          labelText: 'Ville *',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        items: <DropdownMenuItem<String>>[
                          for (final String city in _cityOptions)
                            DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            ),
                        ],
                        onChanged: (String? value) {
                          if (value != null) {
                            _cityController.text = value;
                          }
                        },
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
                      const SizedBox(height: 16),
                      Text(
                        'Téléphones (plusieurs possibles)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kNavy.withValues(alpha: 0.8),
                        ),
                      ),
                      for (int i = 0; i < _phoneControllers.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneControllers[i],
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Numéro ${i + 1}',
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              if (_phoneControllers.length > 1)
                                IconButton(
                                  tooltip: 'Retirer ce numéro',
                                  icon: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _removePhoneField(i),
                                ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addPhoneField,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter un numéro'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Emails (plusieurs possibles)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kNavy.withValues(alpha: 0.8),
                        ),
                      ),
                      for (int i = 0; i < _emailControllers.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: TextFormField(
                                  controller: _emailControllers[i],
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email ${i + 1}',
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              if (_emailControllers.length > 1)
                                IconButton(
                                  tooltip: 'Retirer cet email',
                                  icon: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _removeEmailField(i),
                                ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addEmailField,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter un email'),
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
