import 'dart:io';
import 'package:flutter/material.dart';
import 'package:parkeasy2/screens/auth_screen.dart';
import 'package:parkeasy2/services/image_picker_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OwnerProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String uid;

  const OwnerProfileScreen({
    Key? key,
    required this.name,
    required this.email,
    required this.uid,
  }) : super(key: key);

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  bool _isEditing = false;
  File? _profileImage;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _phoneController = TextEditingController();
  final _businessController = TextEditingController();
  final _addressController = TextEditingController();
  final _lotsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _emailController = TextEditingController(text: widget.email);
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    final prefs = await SharedPreferences.getInstance();
    User? currentUser = FirebaseAuth.instance.currentUser;

    setState(() {
      _nameController.text =
          currentUser?.displayName ??
          prefs.getString('owner_name') ??
          'Parking Owner';
      _emailController.text =
          currentUser?.email ??
          prefs.getString('owner_email') ??
          'owner@email.com';
      _phoneController.text =
          prefs.getString('owner_phone') ?? '+91 98765 43210';
      _businessController.text =
          prefs.getString('owner_business') ?? 'Urban Parking Co.';
      _addressController.text =
          prefs.getString('owner_address') ?? '123 Business St';
      _lotsController.text = prefs.getString('owner_lots') ?? '5';

      final imagePath = prefs.getString('owner_profile_image');
      if (imagePath != null) _profileImage = File(imagePath);
    });
  }

  Future<void> _saveOwnerData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_business', _businessController.text);
    await prefs.setString('owner_address', _addressController.text);
    await prefs.setString('owner_lots', _lotsController.text);
    if (_profileImage != null) {
      await prefs.setString('owner_profile_image', _profileImage!.path);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  void _toggleEditing() {
    setState(() {
      if (_isEditing) _saveOwnerData();
      _isEditing = !_isEditing;
    });
  }

  void _pickImage() {
    ImagePickerHelper.showImageSourceActionSheet(
      context: context,
      onImageSelected: (file) {
        setState(() {
          _profileImage = file;
        });
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthScreen()),
      (route) => false,
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    bool editable = true,
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: editable && _isEditing,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: editable ? Colors.white : Colors.grey[200],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Owner Profile"),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _toggleEditing,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage:
                        _profileImage != null
                            ? FileImage(_profileImage!)
                            : const AssetImage(
                                  'assets/images/profile_placeholder.png',
                                )
                                as ImageProvider,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: MediaQuery.of(context).size.width / 2 - 60,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue,
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome, ${_nameController.text}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            _buildSectionTitle("Personal Info"),
            _buildProfileField(
              label: 'Name',
              controller: _nameController,
              editable: false,
            ),
            _buildProfileField(
              label: 'Email',
              controller: _emailController,
              editable: false,
            ),
            _buildProfileField(
              label: 'Phone',
              controller: _phoneController,
              editable: false,
            ),

            _buildSectionTitle("Business Info"),
            _buildProfileField(
              label: 'Business Name',
              controller: _businessController,
            ),
            _buildProfileField(
              label: 'Business Address',
              controller: _addressController,
            ),
            _buildProfileField(
              label: 'Total Lots Owned',
              controller: _lotsController,
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleEditing,
        label: Text(_isEditing ? 'Save' : 'Edit'),
        icon: Icon(_isEditing ? Icons.check : Icons.edit),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
