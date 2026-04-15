import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<List<dynamic>>? _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = ApiService.getAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Security Console',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            onPressed: _refreshUsers,
            tooltip: 'Refresh',
          ),
          AppIconButton(
            icon: Icons.logout_rounded,
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) context.go('/login');
            },
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminHeader(theme),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }
                
                final users = snapshot.data ?? [];
                return _buildUsersList(theme, users);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/signup'),
        label: const Text('Provision User', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.person_add_rounded, size: 20),
        backgroundColor: AppColors.primaryAccent,
      ),
    );
  }

  Widget _buildAdminHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Access Control',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage user permissions and monitor system audit logs.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(ThemeData theme, List<dynamic> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: AppColors.borderLight),
            const SizedBox(height: 16),
            const Text('No users found in directory', style: TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        final name = user['name'] ?? 'Anonymous';
        final email = user['email'] ?? 'No email associated';
        final role = user['role'] ?? 'Restricted';

        return AppCard(
          borderRadius: 20,
          child: AppListTile(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryAccent.withOpacity(0.12),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 18, inherit: true),
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, inherit: true)),
            subtitle: Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, inherit: true)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryAccent, letterSpacing: 0.5, inherit: true),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _confirmDelete(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(dynamic user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete ${user['name']}? This action is irreversible and will delete all their associated data including orders and documents.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteUser(user['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User ${user['name']} deleted successfully.')),
          );
          _refreshUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Security Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AppButton(
              onPressed: _refreshUsers,
              text: 'Try Again',
            ),
          ],
        ),
      ),
    );
  }
}
