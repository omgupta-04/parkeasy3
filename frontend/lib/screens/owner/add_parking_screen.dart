import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart'; // Needed for MediaType
import 'package:mime/mime.dart';

class AddParkingScreen extends StatefulWidget {
  const AddParkingScreen({Key? key}) : super(key: key);

  @override
  State<AddParkingScreen> createState() => _AddParkingScreenState();
}

class _AddParkingScreenState extends State<AddParkingScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();

  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> uploadImageToNodeServer(File imageFile) async {
    final uri = Uri.parse(
      'http://<YOUR_IP>:5000/upload',
    ); // Replace with your backend URL
    final request = http.MultipartRequest('POST', uri);

    final mimeType = lookupMimeType(imageFile.path);
    final fileStream = http.MultipartFile.fromBytes(
      'image',
      await imageFile.readAsBytes(),
      filename: path.basename(imageFile.path),
      contentType: mimeType != null ? MediaType.parse(mimeType) : null,
    );

    request.files.add(fileStream);

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final jsonResp = jsonDecode(respStr);
        return jsonResp['imageUrl']; // <-- This should be a public URL
      } else {
        print('❌ Upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error uploading image: $e');
    }

    return null;
  }

  Future<void> _uploadParkingSpace() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final price = _priceController.text.trim();

    if (name.isEmpty ||
        location.isEmpty ||
        price.isEmpty ||
        _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select an image.'),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final imageUrl = await uploadImageToNodeServer(_selectedImage!);
      if (imageUrl == null) {
        throw Exception("Image upload failed");
      }

      final ref = FirebaseDatabase.instance.ref('parking_spaces').push();
      await ref.set({
        'name': name,
        'location': location,
        'price': price,
        'imageUrl': imageUrl,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Parking space added')));

      _nameController.clear();
      _locationController.clear();
      _priceController.clear();
      setState(() {
        _selectedImage = null;
      });
    } catch (e) {
      print('🔥 Exception during upload: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Parking Space')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Parking Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey[200],
                ),
                child:
                    _selectedImage == null
                        ? const Center(child: Text('Tap to select image'))
                        : Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadParkingSpace,
              child:
                  _isUploading
                      ? const CircularProgressIndicator()
                      : const Text("Add Parking"),
            ),
          ],
        ),
      ),
    );
  }
}
