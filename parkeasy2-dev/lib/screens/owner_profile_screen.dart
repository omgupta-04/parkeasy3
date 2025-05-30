import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/image_picker_helper.dart';

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  bool _isEditing = false;
  File? _profileImage;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessController = TextEditingController();
  final _addressController = TextEditingController();
  final _lotsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('owner_name') ?? 'Parking Owner';
      _emailController.text = prefs.getString('owner_email') ?? 'owner@example.com';
      _phoneController.text = prefs.getString('owner_phone') ?? '+91 98765 43210';
      _businessController.text = prefs.getString('owner_business') ?? 'Urban Parking Co.';
      _addressController.text = prefs.getString('owner_address') ?? '123 Business Rd, Delhi';
      _lotsController.text = prefs.getString('owner_lots') ?? '5';

      final imagePath = prefs.getString('owner_profile_image');
      if (imagePath != null) {
        _profileImage = File(imagePath);
      }
    });
  }

  Future<void> _saveOwnerData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_name', _nameController.text);
    await prefs.setString('owner_email', _emailController.text);
    await prefs.setString('owner_phone', _phoneController.text);
    await prefs.setString('owner_business', _businessController.text);
    await prefs.setString('owner_address', _addressController.text);
    await prefs.setString('owner_lots', _lotsController.text);
    if (_profileImage != null) {
      await prefs.setString('owner_profile_image', _profileImage!.path);
    }
  }

  void _toggleEditing() {
    setState(() {
      if (_isEditing) {
        _saveOwnerData();
      }
      _isEditing = !_isEditing;
    });
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: inputType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _toggleEditing,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isEditing) _pickImage();
                    },
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider,
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Welcome, ${_nameController.text}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Personal Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTextField(label: 'Name', controller: _nameController, enabled: _isEditing),
            _buildTextField(label: 'Email', controller: _emailController, enabled: false, inputType: TextInputType.emailAddress),
            _buildTextField(label: 'Phone', controller: _phoneController, enabled: false, inputType: TextInputType.phone),
            const SizedBox(height: 24),
            const Text(
              'Business Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTextField(label: 'Business Name', controller: _businessController, enabled: _isEditing),
            _buildTextField(label: 'Business Address', controller: _addressController, enabled: _isEditing),
            _buildTextField(label: 'Total Lots Owned', controller: _lotsController, enabled: _isEditing, inputType: TextInputType.number),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleEditing,
        icon: Icon(_isEditing ? Icons.save : Icons.edit),
        label: Text(_isEditing ? 'Save' : 'Edit'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
