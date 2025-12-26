import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'services/profile_service.dart';

/// Profile completion screen
/// Required before lending or borrowing
class ProfileScreen extends StatefulWidget {
  final String? pendingAction;

  const ProfileScreen({super.key, this.pendingAction});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController(); // Back to free text

  // Only Department uses dropdown
  String? _selectedDepartment;

  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _profile;
  String? _error;

  // Your college departments - customize as needed
  static const List<String> departments = [
    'Computer Science and Engineering',
    'Information Technology',
    'Electronics and Communication Engineering',
    'Electrical and Electronics Engineering',
    'Mechanical Engineering',
    'Civil Engineering',
    'Chemical Engineering',
    'Biotechnology',
    'Artificial Intelligence and Data Science',
    'Cyber Security',
    'Aerospace Engineering',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await ProfileService.getCurrentProfile();
      setState(() {
        _profile = profile;
        _fullNameController.text = profile.fullName;
        _selectedDepartment = profile.department.isEmpty ? null : profile.department;
        _contactController.text = profile.contactNumber;
        _emailController.text = profile.email;
        _addressController.text = profile.address;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ProfileService.saveProfile(
        fullName: _fullNameController.text.trim(),
        department: _selectedDepartment ?? '',
        contactNumber: _contactController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildFormCard(),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _buildErrorBox(),
                        ],
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final isComplete = _profile?.isCompleted ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isComplete
              ? [Colors.green.shade400, Colors.teal.shade400]
              : [Colors.orange.shade400, Colors.deepOrange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isComplete ? Icons.verified_user : Icons.person_add,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete ? 'Profile Complete' : 'Complete Your Profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isComplete
                      ? 'You can lend and borrow items'
                      : 'Required for lending and borrowing',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'This information helps build trust in the community.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => value?.trim().isEmpty ?? true ? 'Full name is required' : null,
          ),
          const SizedBox(height: 16),

          // Department - Dropdown only
          DropdownButtonFormField<String>(
            value: _selectedDepartment,
            decoration: InputDecoration(
              labelText: 'Department *',
              hintText: 'Select your department',
              prefixIcon: const Icon(Icons.school),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: departments.map((dept) {
              return DropdownMenuItem(value: dept, child: Text(dept));
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedDepartment = value);
            },
            validator: (value) => value == null ? 'Department is required' : null,
          ),
          const SizedBox(height: 16),

          // Contact Number
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Contact Number *',
              hintText: '10-digit mobile number',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) return 'Contact number is required';
              if (value!.trim().length < 10) return 'Please enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email ID *',
              hintText: 'your.email@college.edu',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) return 'Email is required';
              if (!value!.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Address - Free text again
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Address / Hostel / Block *',
              hintText: 'e.g., Nile Hostel Room 305, Off-campus',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => value?.trim().isEmpty ?? true ? 'Address is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveProfile,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}