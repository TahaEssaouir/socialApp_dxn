import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger.dart';
import '../posts/posts_repository.dart';
import 'admin_repository.dart';

class AdminPostForm extends ConsumerStatefulWidget {
  const AdminPostForm({super.key, this.post});

  final PostItem? post;

  @override
  ConsumerState<AdminPostForm> createState() => _AdminPostFormState();
}

class _AdminPostFormState extends ConsumerState<AdminPostForm> {
  static const int _maxBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _driveLinkController = TextEditingController();
  final TextEditingController _explicationNameController =
      TextEditingController();
  final TextEditingController _facebookLinkController = TextEditingController();
  final TextEditingController _instagramLinkController =
      TextEditingController();
  final ImagePicker _picker = ImagePicker();

  PostPlatform _platform = PostPlatform.instagram;
  PostKind _kind = PostKind.post;
  Uint8List? _bytes;
  String? _extension;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.post != null;

  @override
  void initState() {
    super.initState();
    final PostItem? post = widget.post;
    if (post != null) {
      _platform = post.platform;
      _kind = post.kind;
      _captionController.text = post.caption ?? '';
      _facebookLinkController.text = post.facebookLink ?? '';
      _instagramLinkController.text = post.instagramLink ?? '';
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _driveLinkController.dispose();
    _explicationNameController.dispose();
    _facebookLinkController.dispose();
    _instagramLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 90,
      );
      if (picked == null) return;

      final int length = await picked.length();
      if (length > _maxBytes) {
        if (!mounted) return;
        setState(() => _error = 'Fichier trop lourd : 10 Mo maximum.');
        return;
      }

      final String extension = _extensionOf(picked.name);
      if (!_allowedExtensions.contains(extension)) {
        if (!mounted) return;
        setState(
          () => _error = 'Format non supporté. Utilisez JPEG, PNG ou WebP.',
        );
        return;
      }

      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.length > _maxBytes) {
        if (!mounted) return;
        setState(() => _error = 'Fichier trop lourd : 10 Mo maximum.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _extension = extension;
        _error = null;
      });
    } on PlatformException catch (error, stack) {
      log.error('Ouverture de la galerie impossible', error, stack);
      if (!mounted) return;
      setState(() => _error = 'Impossible d’ouvrir la galerie.');
    } catch (error, stack) {
      log.error('Lecture de l’image impossible', error, stack);
      if (!mounted) return;
      setState(() => _error = 'Impossible de lire cette image.');
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final Uint8List? bytes = _bytes;
    final String? extension = _extension;
    final String driveLink = _driveLinkController.text.trim();
    final String facebookLink = _facebookLinkController.text.trim();
    final String instagramLink = _instagramLinkController.text.trim();

    if (_kind == PostKind.explication) {
      final String name = _explicationNameController.text.trim();
      if (!_isEditing && (name.isEmpty || driveLink.isEmpty)) {
        setState(
          () => _error =
              'Indiquez le nom et le lien Google Drive pour cette explication.',
        );
        return;
      }
    } else {
      if (_kind == PostKind.reel &&
          facebookLink.isEmpty &&
          instagramLink.isEmpty) {
        setState(
          () => _error =
              'Saisissez au moins le lien Facebook ou le lien Instagram.',
        );
        return;
      }
      if (!_isEditing && (bytes == null || extension == null)) {
        setState(
          () => _error = _kind == PostKind.reel
              ? 'Choisissez une miniature pour le Reel.'
              : 'Choisissez une image avant de publier.',
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await ref
            .read(adminRepositoryProvider)
            .updatePoster(
              id: widget.post!.id,
              oldMediaPath: widget.post!.mediaPath,
              platform: _platform,
              kind: _kind,
              caption: _kind == PostKind.explication
                  ? _explicationNameController.text.trim()
                  : _captionController.text,
              bytes: bytes,
              extension: extension,
              driveLink: _kind == PostKind.explication ? driveLink : null,
              facebookLink: facebookLink.isEmpty ? null : facebookLink,
              instagramLink: instagramLink.isEmpty ? null : instagramLink,
              externalLink: null,
            );
      } else {
        if (_kind == PostKind.explication) {
          await ref
              .read(adminRepositoryProvider)
              .createDriveLinkPoster(
                driveUrl: driveLink,
                platform: _platform,
                kind: _kind,
                caption: _explicationNameController.text.trim(),
              );
        } else {
          await ref
              .read(adminRepositoryProvider)
              .createPoster(
                bytes: bytes!,
                extension: extension!,
                platform: _platform,
                kind: _kind,
                caption: _captionController.text,
                facebookLink: facebookLink.isEmpty ? null : facebookLink,
                instagramLink: instagramLink.isEmpty ? null : instagramLink,
                externalLink: null,
              );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Poster modifié.' : 'Poster publié.'),
        ),
      );
      context.go('/');
    } catch (error, stack) {
      log.error(
        _isEditing
            ? 'Modification du poster impossible'
            : 'Publication du poster impossible',
        error,
        stack,
      );
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is PostgrestException) {
      return 'Erreur Supabase (${error.code}) : ${error.message}';
    }
    if (error is StorageException) {
      return 'Erreur Storage (${error.statusCode ?? 'inconnue'}) : ${error.message}';
    }
    if (error is AuthException) {
      return 'Session administrateur invalide : ${error.message}';
    }
    return 'Modification impossible. Réessayez.';
  }

  String _extensionOf(String name) {
    final int dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le poster' : 'Nouveau poster'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  Text(
                    _kind == PostKind.explication
                        ? (_isEditing
                              ? 'Modifier une explication'
                              : 'Ajouter une explication')
                        : (_isEditing
                              ? 'Modifier un poster'
                              : 'Publier un poster'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _kind == PostKind.explication
                        ? 'Indiquez le nom et le lien du dossier Google Drive.'
                        : 'JPEG, PNG ou WebP · 10 Mo maximum.',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<PostPlatform>(
                    initialValue: _platform,
                    decoration: const InputDecoration(
                      labelText: 'Plateforme',
                      prefixIcon: Icon(Icons.share_outlined),
                    ),
                    items: PostPlatform.values
                        .map(
                          (PostPlatform platform) =>
                              DropdownMenuItem<PostPlatform>(
                                value: platform,
                                child: Row(
                                  children: <Widget>[
                                    Icon(platform.icon, size: 18),
                                    const SizedBox(width: 8),
                                    Text(platform.label),
                                  ],
                                ),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: _submitting
                        ? null
                        : (PostPlatform? value) {
                            if (value != null) {
                              setState(() => _platform = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<PostKind>(
                    initialValue: _kind,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: PostKind.values
                        .map(
                          (PostKind kind) => DropdownMenuItem<PostKind>(
                            value: kind,
                            child: Text(kind.sectionLabel),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _submitting
                        ? null
                        : (PostKind? value) {
                            if (value != null) {
                              setState(() => _kind = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  if (_kind == PostKind.post)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.info_outline, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Image depuis Google Drive',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '1. Google Drive → Sélectionner ton image\n'
                            '2. Clic droit → Partager → Accès : « Toute personne disposant du lien peut consulter »\n'
                            '3. Copier le lien (il contient l\'ID du fichier)\n'
                            '4. Utiliser le lien direct : https://drive.google.com/uc?export=view&id=ID_DU_FICHIER',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_kind == PostKind.post) const SizedBox(height: 14),
                  if (_kind != PostKind.explication)
                    TextFormField(
                      controller: _captionController,
                      enabled: !_submitting,
                      maxLength: 2200,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Légende (optionnelle)',
                        alignLabelWithHint: true,
                      ),
                      validator: (String? value) {
                        if (value != null && value.length > 2200) {
                          return 'La légende dépasse 2200 caractères.';
                        }
                        return null;
                      },
                    ),
                  if (_kind != PostKind.explication) ...<Widget>[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _facebookLinkController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Lien du poster Facebook',
                        hintText: 'https://facebook.com/...',
                        prefixIcon: Icon(Icons.facebook),
                      ),
                      validator: (String? value) {
                        final String v = (value ?? '').trim();
                        if (v.isEmpty) return null;
                        if (!(v.startsWith('http://') ||
                            v.startsWith('https://'))) {
                          return 'Lien Facebook invalide.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _instagramLinkController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Lien du poster Instagram',
                        hintText: 'https://instagram.com/...',
                        prefixIcon: Icon(Icons.camera_alt_outlined),
                      ),
                      validator: (String? value) {
                        final String v = (value ?? '').trim();
                        if (v.isEmpty) return null;
                        if (!(v.startsWith('http://') ||
                            v.startsWith('https://'))) {
                          return 'Lien Instagram invalide.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_kind == PostKind.explication) ...<Widget>[
                    TextFormField(
                      controller: _explicationNameController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        hintText: 'Nom du dossier/explication',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (String? value) {
                        if (_kind != PostKind.explication) return null;
                        final String v = (value ?? '').trim();
                        if (v.isEmpty) {
                          return 'Nom requis pour une explication.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _driveLinkController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Lien du drive',
                        hintText: 'https://drive.google.com/...',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (String? value) {
                        if (_kind != PostKind.explication) return null;
                        final String v = (value ?? '').trim();
                        if (v.isEmpty) {
                          return 'Lien requis pour une explication.';
                        }
                        if (!(v.startsWith('http://') ||
                            v.startsWith('https://'))) {
                          return 'Lien invalide.';
                        }
                        return null;
                      },
                    ),
                  ] else if (_bytes == null)
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _kind == PostKind.reel
                            ? 'Choisir une miniature'
                            : _isEditing
                            ? 'Changer l’image (optionnel)'
                            : 'Choisir une image',
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.memory(
                              _bytes!,
                              fit: BoxFit.cover,
                              semanticLabel: _kind == PostKind.reel
                                  ? 'Aperçu de la miniature du Reel'
                                  : 'Aperçu du poster',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _pickImage,
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(
                            _kind == PostKind.reel
                                ? 'Changer la miniature'
                                : 'Changer d’image',
                          ),
                        ),
                      ],
                    ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A1212),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF7A2020)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Color(0xFFFFB4AB),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFFFB4AB),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _kind == PostKind.explication
                                ? Icons.add_link
                                : Icons.upload_outlined,
                          ),
                    label: Text(
                      _submitting
                          ? (_isEditing ? 'Modification…' : 'Ajout…')
                          : _kind == PostKind.explication
                          ? (_isEditing ? 'Enregistrer' : 'Ajouter')
                          : (_isEditing ? 'Enregistrer' : 'Publier'),
                    ),
                  ),
                  if (_submitting) ...<Widget>[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
