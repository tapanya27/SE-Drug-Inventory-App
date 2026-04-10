import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen>
    with SingleTickerProviderStateMixin {
  bool _isUploading = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _successMessage;
  List<dynamic> _documents = [];
  PlatformFile? _selectedFile;
  String _selectedDocType = 'pharmacy_license';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final _docTypes = {
    'pharmacy_license': 'Pharmacy License',
    'registration_cert': 'Registration Certificate',
    'gst_certificate': 'GST Certificate',
    'drug_license': 'Drug License',
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
    _loadDocuments();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await ApiService.getMyDocuments();
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _errorMessage = null;
      });
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedFile == null) {
      setState(() => _errorMessage = 'Please select a file first.');
      return;
    }

    if (_selectedFile!.bytes == null) {
      setState(() => _errorMessage = 'Could not read file data.');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ApiService.uploadDocument(
        _selectedDocType,
        '', // path is unavailable on web, bytes are used instead
        _selectedFile!.name,
        _selectedFile!.bytes!,
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Document verified successfully! Your account is now approved. Use the sidebar or click below to go to the dashboard.';
          _selectedFile = null;
        });
        _loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = ApiService.isVerified;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Verification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pharmacy_dashboard'),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Status Banner ---
              _buildStatusBanner(isVerified),
              const SizedBox(height: 24),

              // --- Upload Section (only if not verified) ---
              if (!isVerified) ...[
                _buildUploadSection(),
                const SizedBox(height: 24),
              ],

              // --- Previous Documents ---
              _buildDocumentHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(bool isVerified) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVerified
              ? [Colors.green.withValues(alpha: 0.2), AppColors.cardColor]
              : [Colors.orange.withValues(alpha: 0.2), AppColors.cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.pending_outlined,
            color: isVerified ? Colors.green : Colors.orange,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Account Verified' : 'Verification Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? Colors.green.shade300 : Colors.orange.shade300,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? 'Your pharmacy registration has been verified. You have full access.'
                      : 'Please upload your pharmacy license or registration certificate to activate your account.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upload_file, color: AppColors.primaryAccent, size: 22),
              const SizedBox(width: 8),
              const Text('Upload Document',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),

          // Document Type Dropdown
          DropdownButtonFormField<String>(
            value: _selectedDocType,
            decoration: InputDecoration(
              labelText: 'Document Type',
              prefixIcon: const Icon(Icons.description, color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            dropdownColor: AppColors.cardColor,
            style: const TextStyle(color: Colors.white),
            items: _docTypes.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _selectedDocType = v!),
          ),
          const SizedBox(height: 16),

          // File Picker Zone
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryAccent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                    color: _selectedFile != null ? Colors.green : AppColors.primaryAccent,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFile != null ? _selectedFile!.name : 'Click to select a file',
                    style: TextStyle(
                      color: _selectedFile != null ? Colors.white : Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'PDF, JPG, or PNG • Max 5MB',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Error / Success Messages
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12))),
                ],
              ),
            ),

          if (_successMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade400, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_successMessage!,
                      style: TextStyle(color: Colors.green.shade400, fontSize: 12))),
                ],
              ),
            ),

          // Upload Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadDocument,
              icon: _isUploading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload & Verify'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text('Submitted Documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
          else if (_documents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.folder_open, color: Colors.white.withValues(alpha: 0.2), size: 48),
                    const SizedBox(height: 8),
                    Text('No documents uploaded yet.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            )
          else
            ..._documents.map((doc) => _buildDocumentTile(doc)),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(dynamic doc) {
    final status = doc['status'] ?? 'Pending';
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: AppColors.primaryAccent.withValues(alpha: 0.7), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc['filename'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  _docTypes[doc['doc_type']] ?? doc['doc_type'] ?? 'Document',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 4),
                Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
