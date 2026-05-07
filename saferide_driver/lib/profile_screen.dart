import 'dart:io';
import 'dart:convert'; // 🔥 For Base64 encoding
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';

// ❌ REMOVED: firebase_storage — no longer needed

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  final _nameController    = TextEditingController();
  final _phoneController   = TextEditingController();
  final _licenseController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _routeController   = TextEditingController();

  bool    _isEditing        = false;
  bool    _isSaving         = false;
  bool    _isLoading        = true;
  bool    _isUploadingPhoto = false;

  // 🔥 Base64 string stored directly in Realtime DB (no Storage needed)
  String? _photoBase64;
  File?   _localPhotoFile; // shown instantly before DB write completes

  int _totalTrips  = 0;
  int _alertsToday = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _vehicleController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  // ── Load profile ─────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    if (_user == null) return;

    try {
      // 🔥 Read root driver node (includes registration data + profile subnode)
      final rootSnap = await FirebaseDatabase.instance
          .ref("drivers/${_user!.uid}")
          .get();

      if (rootSnap.exists) {
        final root = rootSnap.value as Map;

        // Root-level fields set during registration
        final rootName    = root['name']?.toString()          ?? '';
        final rootPhone   = root['phone']?.toString()         ?? '';
        final rootLicense = root['licenseNumber']?.toString() ?? '';

        // Profile subnode written by this screen
        final profile = (root['profile'] ?? {}) as Map;

        if (mounted) {
          setState(() {
            // Profile subnode එකේ දත්ත ඇත්නම් ඒවාට මුල් තැන ලබා දේ
            _nameController.text = profile['name']?.toString() ?? rootName;
            _phoneController.text = profile['phone']?.toString() ?? rootPhone;
            _licenseController.text = profile['license']?.toString() ?? rootLicense;
            _vehicleController.text = profile['vehicle']?.toString() ?? root['vanId']?.toString() ?? '';
            _routeController.text = profile['route']?.toString() ?? '';

            // 🔥 Base64 photo කියවා ගැනීම
            final b64 = profile['photoBase64']?.toString() ?? '';
            if (b64.isNotEmpty) _photoBase64 = b64;
            
            _isLoading = false; // දත්ත කියවා අවසන් වූ පසු loading නවත්වයි
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Profile load error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Load stats ────────────────────────────────────────────────────────────
  Future<void> _loadStats() async {
    if (_user == null) return;
    try {
      final tripsSnap = await FirebaseDatabase.instance
          .ref("trips")
          .orderByChild("driverId")
          .equalTo(_user!.uid)
          .get();
      if (tripsSnap.exists) {
        _totalTrips = (tripsSnap.value as Map).length;
      }

      // Driver ගේ vanId read කරලා correct alerts path use කරනවා
      final driverSnap = await FirebaseDatabase.instance
          .ref("drivers/${_user!.uid}")
          .get();
      String vanId = 'van01';
      if (driverSnap.exists) {
        final d = driverSnap.value as Map;
        final v = d['vanId']?.toString() ??
            (d['profile'] as Map?)?['vehicle']?.toString();
        if (v != null && v.isNotEmpty) vanId = v.toLowerCase();
      }

      final alertSnap =
          await FirebaseDatabase.instance.ref("v1/alerts/$vanId").get();
      if (alertSnap.exists) {
        final data = alertSnap.value as Map?;
        if (data != null && data['isDrowsy'] == true) _alertsToday = 1;
      }
    } catch (e) {
      debugPrint("Stats load error: $e");
    }
    if (mounted) setState(() {});
  }

  // ── Save profile ──────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (_user == null) return;
    setState(() => _isSaving = true);

    try {
      await _user!.updateDisplayName(_nameController.text.trim());

      await FirebaseDatabase.instance
          .ref("drivers/${_user!.uid}/profile")
          .update({
        'name'     : _nameController.text.trim(),
        'phone'    : _phoneController.text.trim(),
        'license'  : _licenseController.text.trim(),
        'vehicle'  : _vehicleController.text.trim(),
        'route'    : _routeController.text.trim(),
        'email'    : _user!.email ?? '',
        'updatedAt': ServerValue.timestamp,
      });

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ── Pick photo → Base64 → Realtime DB ────────────────────────────────────
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 300,
      maxHeight: 300,
    );
    if (picked == null) return;

    final file = File(picked.path);

    setState(() {
      _localPhotoFile   = file;
      _isUploadingPhoto = true;
    });

    try {
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);

      await FirebaseDatabase.instance
          .ref("drivers/${_user!.uid}/profile")
          .update({'photoBase64': base64Str});

      if (mounted) {
        setState(() {
          _photoBase64      = base64Str;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Photo saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Change password ───────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'A password reset email will be sent to your registered email address.'),
            const SizedBox(height: 12),
            Text(_user?.email ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: _user!.email!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📧 Password reset email sent!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Send Email',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeader(
              name:             _nameController.text.isNotEmpty
                                    ? _nameController.text
                                    : (_user?.email ?? 'Driver'),
              email:            _user?.email ?? '',
              photoBase64:      _photoBase64,
              localPhotoFile:   _localPhotoFile,
              isEditing:        _isEditing,
              isUploadingPhoto: _isUploadingPhoto,
              onEditPhoto:      _pickPhoto,
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StatsRow(
                  totalTrips: _totalTrips, alertsToday: _alertsToday),
            ),

            const SizedBox(height: 20),

            // Edit / Save / Cancel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _isEditing
                        ? ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check,
                                    color: Colors.white),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Changes',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _isEditing = true),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade600),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _isEditing = false);
                        _loadProfile();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ProfileCard(
                title: 'Personal Information',
                icon: Icons.person_outline,
                children: [
                  _ProfileField(
                    label: 'Full Name',
                    controller: _nameController,
                    icon: Icons.badge_outlined,
                    enabled: _isEditing,
                  ),
                  _ProfileField(
                    label: 'Email Address',
                    controller:
                        TextEditingController(text: _user?.email ?? ''),
                    icon: Icons.email_outlined,
                    enabled: false,
                  ),
                  _ProfileField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                    hint: '+94 7X XXX XXXX',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ProfileCard(
                title: 'Driver Details',
                icon: Icons.directions_bus_outlined,
                children: [
                  _ProfileField(
                    label: 'License Number',
                    controller: _licenseController,
                    icon: Icons.credit_card_outlined,
                    enabled: _isEditing,
                    hint: 'e.g. B1234567',
                  ),
                  _ProfileField(
                    label: 'Vehicle / Van ID',
                    controller: _vehicleController,
                    icon: Icons.airport_shuttle_outlined,
                    enabled: _isEditing,
                    hint: 'e.g. van01',
                  ),
                  _ProfileField(
                    label: 'Assigned Route',
                    controller: _routeController,
                    icon: Icons.route_outlined,
                    enabled: _isEditing,
                    hint: 'e.g. Negombo - Colombo',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ProfileCard(
                title: 'Security',
                icon: Icons.lock_outline,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.key_outlined,
                          color: Colors.orange.shade700, size: 20),
                    ),
                    title: const Text('Change Password',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Send a reset link to your email'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── _ProfileHeader ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String  name;
  final String  email;
  final String? photoBase64;    // 🔥 Base64 string
  final File?   localPhotoFile;
  final bool    isEditing;
  final bool    isUploadingPhoto;
  final VoidCallback onEditPhoto;

  const _ProfileHeader({
    required this.name,
    required this.email,
    this.photoBase64,
    this.localPhotoFile,
    required this.isEditing,
    this.isUploadingPhoto = false,
    required this.onEditPhoto,
  });

  ImageProvider? get _imageProvider {
    if (localPhotoFile != null) return FileImage(localPhotoFile!);
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photoBase64!));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.green.shade100,
                backgroundImage: provider,
                child: provider == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'D',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      )
                    : null,
              ),
              if (isUploadingPhoto)
                Container(
                  width: 104, height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 3),
                ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: onEditPhoto,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 4),
          Text(email,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined,
                    size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'Verified Driver',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _StatsRow ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalTrips;
  final int alertsToday;

  const _StatsRow(
      {required this.totalTrips, required this.alertsToday});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
              label: 'Total Trips',
              value: '$totalTrips',
              icon: Icons.directions_bus,
              color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              label: 'Alerts Today',
              value: '$alertsToday',
              icon: Icons.warning_amber_rounded,
              color: alertsToday > 0 ? Colors.red : Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
              label: 'Status',
              value: 'Active',
              icon: Icons.circle,
              color: Colors.green),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── _ProfileCard ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ProfileCard(
      {required this.title,
      required this.icon,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade800)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ── _ProfileField ─────────────────────────────────────────────────────────────

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final String? hint;
  final TextInputType keyboardType;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.icon,
    this.enabled = true,
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon,
              size: 20,
              color: enabled
                  ? Colors.green.shade600
                  : Colors.grey.shade400),
          filled: true,
          fillColor:
              enabled ? Colors.green.shade50 : Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade200)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.green.shade600, width: 2)),
          labelStyle: TextStyle(
              color: enabled
                  ? Colors.green.shade700
                  : Colors.grey.shade500,
              fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}