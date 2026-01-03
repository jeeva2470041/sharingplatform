import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user_profile.dart';
import 'services/profile_service.dart';
import 'app_theme.dart';

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
  String? _selectedYear;

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

  // Academic year options
  static const List<String> years = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'PG/PhD',
    'Faculty/Staff',
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
      // Always use the registered email from Firebase Auth
      final registeredEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      
      setState(() {
        _profile = profile;
        _fullNameController.text = profile.fullName;
        _selectedDepartment = profile.department.isEmpty ? null : profile.department;
        _selectedYear = profile.year?.isEmpty ?? true ? null : profile.year;
        _contactController.text = profile.contactNumber;
        _emailController.text = registeredEmail; // Use Firebase Auth email
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
        year: _selectedYear ?? '',
        contactNumber: _contactController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (!mounted) return;

      // Store context reference before async gap
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: AppTheme.fontWeightBold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryPressed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: AppTheme.spacing24),
                        _buildFormCard(),
                        if (_error != null) ...[
                          const SizedBox(height: AppTheme.spacing16),
                          _buildErrorBox(),
                        ],
                        const SizedBox(height: AppTheme.spacing24),
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
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryPressed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Icon(
              isComplete ? Icons.verified_user : Icons.person_add,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete ? 'Profile Complete' : 'Complete Your Profile',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white,
                    fontSize: AppTheme.fontSizeCardHeader,
                    fontWeight: AppTheme.fontWeightBold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  isComplete
                      ? 'You can lend and borrow items'
                      : 'Required for lending and borrowing',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: AppTheme.fontSizeLabel,
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
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: AppTheme.sectionTitle,
          ),
          const SizedBox(height: AppTheme.spacing8),
          const Text(
            'This information helps build trust in the community.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.textSecondary,
              fontSize: AppTheme.fontSizeLabel,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),

          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: AppTheme.inputDecoration(
              label: 'Full Name *',
              hint: 'Enter your full name',
              prefixIcon: const Icon(Icons.person, color: AppTheme.textSecondary),
            ),
            validator: (value) => value?.trim().isEmpty ?? true ? 'Full name is required' : null,
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Department - Dropdown only
          DropdownButtonFormField<String>(
            initialValue: _selectedDepartment,
            decoration: AppTheme.inputDecoration(
              label: 'Department *',
              hint: 'Select your department',
              prefixIcon: const Icon(Icons.school, color: AppTheme.textSecondary),
            ),
            items: departments.map((dept) {
              return DropdownMenuItem(value: dept, child: Text(dept));
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedDepartment = value);
            },
            validator: (value) => value == null ? 'Department is required' : null,
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Year - Dropdown
          DropdownButtonFormField<String>(
            value: _selectedYear,
            decoration: AppTheme.inputDecoration(
              label: 'Year *',
              hint: 'Select your year',
              prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.textSecondary),
            ),
            items: years.map((year) {
              return DropdownMenuItem(value: year, child: Text(year));
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedYear = value);
            },
            validator: (value) => value == null ? 'Year is required' : null,
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Contact Number
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: AppTheme.inputDecoration(
              label: 'Contact Number *',
              hint: '10-digit mobile number',
              prefixIcon: const Icon(Icons.phone, color: AppTheme.textSecondary),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) return 'Contact number is required';
              if (value!.trim().length < 10) return 'Please enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Email - Read-only, from Firebase Auth
          TextFormField(
            controller: _emailController,
            readOnly: true,
            enabled: false,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.textSecondary,
            ),
            decoration: AppTheme.inputDecoration(
              label: 'Email ID (from registration)',
              hint: '',
              prefixIcon: const Icon(Icons.email, color: AppTheme.textSecondary),
              suffixIcon: const Tooltip(
                message: 'Email cannot be changed',
                child: Icon(Icons.lock_outline, color: AppTheme.textDisabled, size: 18),
              ),
            ).copyWith(
              filled: true,
              fillColor: AppTheme.disabledBackground,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Address - Free text again
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: AppTheme.inputDecoration(
              label: 'Address / Hostel / Block *',
              hint: 'e.g., Nile Hostel Room 305, Off-campus',
              prefixIcon: const Icon(Icons.location_on, color: AppTheme.textSecondary),
            ),
            validator: (value) => value?.trim().isEmpty ?? true ? 'Address is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.danger,
                fontSize: AppTheme.fontSizeLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 48,
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
        style: AppTheme.primaryButtonStyle,
      ),
    );
  }
}