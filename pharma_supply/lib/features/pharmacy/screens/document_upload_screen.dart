import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
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
  Map<String, dynamic>? _lastAiResult;

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
      final result = await ApiService.uploadDocument(
        _selectedDocType,
        '',
        _selectedFile!.name,
        _selectedFile!.bytes!,
      );

      if (mounted) {
        final status = result['status'] ?? '';
        final aiScore = result['ai_score'];
        final extractedRaw = result['extracted_data'];
        final issuesRaw = result['verification_issues'];

        Map<String, dynamic> extractedData = {};
        List<dynamic> issues = [];

        try {
          if (extractedRaw != null && extractedRaw is String) {
            extractedData = jsonDecode(extractedRaw);
          }
        } catch (_) {}

        try {
          if (issuesRaw != null && issuesRaw is String) {
            issues = jsonDecode(issuesRaw);
          }
        } catch (_) {}

        setState(() {
          _lastAiResult = {
            'status': status,
            'ai_score': aiScore,
            'extracted_data': extractedData,
            'issues': issues,
          };
          _selectedFile = null;

          if (status == 'Approved') {
            _successMessage =
                'Document verified successfully! Your account is now approved.';
          } else if (status == 'Pending') {
            _successMessage =
                'Document uploaded. AI flagged it for manual review (Score: $aiScore).';
          } else {
            _errorMessage =
                'Document was rejected by AI verification (Score: $aiScore). Please re-upload a valid license.';
          }
        });
        _loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = ApiService.isVerified;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Account Verification',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimaryLight),
          onPressed: () => context.go('/pharmacy_dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernStatusBanner(isVerified),
              const SizedBox(height: 32),

              if (!isVerified) ...[
                _buildModernUploadSection(theme),
                const SizedBox(height: 32),
              ],

              if (_lastAiResult != null) ...[
                _buildModernAiReport(theme),
                const SizedBox(height: 32),
              ],

              _buildModernHistorySection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatusBanner(bool isVerified) {
    final statusColor = isVerified ? AppColors.success : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Fully Verified' : 'Action Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? 'Your pharmacy is active and ready for logistics operations.'
                      : 'Upload your valid pharmacy license to unlock all features.',
                  style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernUploadSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Credentials',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 20),
            
            DropdownButtonFormField<String>(
              value: _selectedDocType,
              decoration: const InputDecoration(
                labelText: 'Document Type',
                prefixIcon: Icon(Icons.assignment_outlined, size: 20),
              ),
              items: _docTypes.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDocType = v!),
            ),
            const SizedBox(height: 20),

            // Dashed Upload Zone
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.borderLight,
                    style: BorderStyle.solid,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.file_present_rounded : Icons.add_photo_alternate_outlined,
                      color: _selectedFile != null ? AppColors.primaryAccent : AppColors.textSecondaryLight,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFile != null ? _selectedFile!.name : 'Drop files here or click to browse',
                      style: TextStyle(
                        color: _selectedFile != null ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
                        fontWeight: _selectedFile != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PDF, PNG, JPG (Max 5MB)',
                      style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_errorMessage != null) ...[
               const SizedBox(height: 16),
               _buildInlineAlert(_errorMessage!, AppColors.error),
            ],
            
            if (_successMessage != null) ...[
               const SizedBox(height: 16),
               _buildInlineAlert(_successMessage!, AppColors.success),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading 
                    ? null 
                    : (_selectedFile == null ? _pickFile : _uploadDocument),
                icon: _isUploading 
                    ? const SizedBox() 
                    : Icon(_selectedFile == null ? Icons.folder_open_rounded : Icons.verified_user_rounded),
                label: _isUploading
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(_selectedFile == null ? 'Browse Files App' : 'Analyze & Verify'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAiReport(ThemeData theme) {
    final result = _lastAiResult!;
    final status = result['status'] ?? 'Unknown';
    final score = result['ai_score'] ?? 0;
    final extractedData = result['extracted_data'] as Map<String, dynamic>? ?? {};
    final issues = result['issues'] as List<dynamic>? ?? [];

    Color statusColor = status == 'Approved' ? AppColors.success : (status == 'Rejected' ? AppColors.error : AppColors.warning);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('AI Analysis Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondaryLight),
                      onPressed: () => setState(() => _lastAiResult = null),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Confidence Score', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: score / 100,
                              minHeight: 10,
                              backgroundColor: AppColors.backgroundLight,
                              valueColor: AlwaysStoppedAnimation(statusColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Text(
                      '$score%',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: -1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: AppColors.backgroundLight.withOpacity(0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Extracted Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                if (extractedData.isEmpty)
                   const Text('No data readable', style: TextStyle(fontStyle: FontStyle.italic))
                else
                   ...extractedData.entries.map((e) => _buildExtractedRow(e.key, e.value.toString())).toList(),
              ],
            ),
          ),

          if (issues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Potential Risks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error)),
                  const SizedBox(height: 12),
                  ...issues.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(i.toString(), style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight))),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExtractedRow(String label, String value) {
    final prettyLabel = label.replaceAll('_', ' ').toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(prettyLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight)),
          ),
          if (value.isNotEmpty && value != 'null')
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16)
          else
            const Icon(Icons.help_outline_rounded, color: AppColors.warning, size: 16),
        ],
      ),
    );
  }

  Widget _buildModernHistorySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verification History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_isLoading)
           const Center(child: CircularProgressIndicator())
        else if (_documents.isEmpty)
           const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No previous uploads')))
        else
           ..._documents.map((doc) => _buildModernDocTile(doc)).toList(),
      ],
    );
  }

  Widget _buildModernDocTile(dynamic doc) {
    final status = doc['status'] ?? 'Pending';
    Color color = status == 'Approved' ? AppColors.success : (status == 'Rejected' ? AppColors.error : AppColors.warning);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.description_outlined, color: AppColors.primaryAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc['filename'] ?? 'document.pdf', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(_docTypes[doc['doc_type']] ?? 'License', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineAlert(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }
}
