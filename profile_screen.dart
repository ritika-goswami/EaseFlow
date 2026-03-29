import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easeflow_app/user_data.dart';
import 'package:easeflow_app/screens/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String age = "--";
  String weight = "--";
  String height = "--";
  String cycleLength = "--";
  String userPhoneNumber = ""; 
  bool _isDarkMode = false;
  bool _notifications = true;
  bool _isLoading = true; 
  File? _image;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAllUserData();
  }

  Future<void> _loadAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          Map<String, dynamic> data = doc.data()!;
          setState(() {
            age = (data['age'] == null || data['age'] == "") ? "--" : data['age'].toString();
            weight = (data['weight'] == null || data['weight'] == "") ? "--" : data['weight'].toString();
            height = (data['height'] == null || data['height'] == "") ? "--" : data['height'].toString();
            cycleLength = (data['cycleLength'] == null || data['cycleLength'] == "") ? "--" : data['cycleLength'].toString();
            userPhoneNumber = data['number'] ?? "";
          });
          
          await prefs.setString('age', age);
          await prefs.setString('weight', weight);
          await prefs.setString('height', height);
          await prefs.setString('Cycle length', cycleLength);
        }
      } catch (e) {
        debugPrint("Error fetching cloud data: $e");
      }
    }

    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _notifications = prefs.getBool('notifications') ?? true;
      
      if (cycleLength == "--") {
        cycleLength = prefs.getString('Cycle length') ?? "--";
      }

      String? imagePath = prefs.getString('profile_image_path');
      if (imagePath != null && imagePath.isNotEmpty) {
        _image = File(imagePath);
      }
      _isLoading = false;
    });
  }

  String? _validateInput(String title, String value) {
    if (value.isEmpty) return "Field cannot be empty";
    int? numVal = int.tryParse(value);
    if (numVal == null) return "Please enter a valid number";

    if (title == "Age") {
      if (numVal < 10 || numVal > 90) return "Please enter a realistic age (10-90)";
    } else if (title == "Cycle length") {
      if (numVal < 2 || numVal > 13) return "Typical period duration is 3-8 days";
    } else if (title == "Weight") {
      if (numVal < 20 || numVal > 180) return "Please enter a valid weight";
    }
    return null; 
  }

  Future<void> _updateField(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String dbKey = key == 'Cycle length' ? 'cycleLength' : key;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        dbKey: value,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', pickedFile.path);
      setState(() { _image = File(pickedFile.path); });
    }
  }

  void _showEditDialog(String title, String currentValue, String prefKey, Function(String) onUpdate) {
    TextEditingController controller = TextEditingController(text: currentValue == "--" ? "" : currentValue);
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Update $title", style: const TextStyle(color: Color(0xFFE79AA2), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter $title",
                  errorText: errorText,
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE79AA2))),
                ),
                onChanged: (val) {
                  setDialogState(() => errorText = _validateInput(title, val));
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                String val = controller.text.trim();
                String? validationError = _validateInput(title, val);
                
                if (validationError == null) {
                  onUpdate(val);
                  _updateField(prefKey, val);
                  Navigator.pop(context);
                } else {
                  setDialogState(() => errorText = validationError);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDE4E4), elevation: 0),
              child: const Text("Save", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Color(0xFFF9F9F9);
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE79AA2)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildProfileHeader(),
                    const SizedBox(height: 40),
                    const Text("Settings :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _buildInfoCard("Age", age, cardColor, () => _showEditDialog("Age", age, 'age', (v) => setState(() => age = v))),
                    _buildInfoCard("Weight", weight, cardColor, () => _showEditDialog("Weight", weight, 'weight', (v) => setState(() => weight = v))),
                    _buildInfoCard("Height", height, cardColor, () => _showEditDialog("Height", height, 'height', (v) => setState(() => height = v))),
                    _buildInfoCard("Cycle length", cycleLength, cardColor, () => _showEditDialog("Cycle length", cycleLength, 'Cycle length', (v) => setState(() => cycleLength = v))),
                    const SizedBox(height: 25),
                    const Text("Preferences :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _buildToggleCard("Notifications", _notifications, (val) {
                      setState(() => _notifications = val);
                      SharedPreferences.getInstance().then((p) => p.setBool('notifications', val));
                    }, cardColor),
                    _buildToggleCard("Dark Mode", _isDarkMode, (val) {
                      setState(() => _isDarkMode = val);
                      SharedPreferences.getInstance().then((p) => p.setBool('darkMode', val));
                    }, cardColor),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFDE4E4).withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
            ),
            child: TextButton(
              onPressed: () => _showLogoutDialog(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Logout", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const Text("Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
          const CircleAvatar(backgroundColor: Colors.white, radius: 18, child: Icon(Icons.person, color: Colors.black, size: 20)),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure? This will clear all local session data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              
              // --- CRITICAL: Clear all local data so the next user starts fresh ---
              await prefs.remove('period_history_list'); 
              await prefs.remove('Cycle length');
              await prefs.remove('age');
              await prefs.remove('weight');
              await prefs.remove('height');
              await prefs.remove('profile_image_path');
              // You can also use await prefs.clear(); if you want to wipe everything.

              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
              }
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return FutureBuilder<String>(
      future: UserData.getUserName(),
      builder: (context, snapshot) {
        String name = snapshot.data ?? "User X";
        return Row(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFFFDE4E4),
                    backgroundImage: _image != null ? FileImage(_image!) : null,
                    child: _image == null ? const Icon(Icons.person, size: 40, color: Colors.black) : null,
                  ),
                  const CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.camera_alt_outlined, size: 14, color: Colors.black))
                ],
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(10)),
                      child: const Text("Verified", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                Text(userPhoneNumber, style: const TextStyle(color: Colors.black54, fontSize: 14)),
              ],
            )
          ],
        );
      }
    );
  }

  Widget _buildInfoCard(String label, String value, Color cardColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor, 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              children: [
                Text(value, style: const TextStyle(color: Colors.black54, fontSize: 16)),
                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard(String label, bool value, Function(bool) onChanged, Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Switch(
            value: value, 
            onChanged: onChanged, 
            activeColor: const Color(0xFFE79AA2),
            activeTrackColor: const Color(0xFFFDE4E4),
          )
        ],
      ),
    );
  }
}
