import 'package:flutter/material.dart';
import 'models.dart';
import 'mapping_channel.dart';
import 'tv_focusable.dart';

/// Screen for managing profiles (create, switch, delete).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<AppProfile> _profiles = [];
  String _currentId = 'default';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await MappingChannel.getProfiles();
    final currentId = await MappingChannel.getCurrentProfile();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _currentId = currentId;
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final name = await _promptName('Profile name');
    if (name == null || name.isEmpty) return;
    await MappingChannel.createProfile(name);
    _load();
  }

  Future<void> _delete(AppProfile profile) async {
    if (profile.id == 'default') {
      _snack('Cannot delete the default profile');
      return;
    }
    final ok = await _confirm(
        'Delete "${profile.name}"?', 'All its mappings will be lost.');
    if (ok) {
      await MappingChannel.deleteProfile(profile.id);
      _load();
    }
  }

  Future<void> _switch(AppProfile profile) async {
    if (profile.id == _currentId) return;
    await MappingChannel.switchProfile(profile.id);
    setState(() => _currentId = profile.id);
  }

  Future<String?> _promptName(String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Profile Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Create',
                  style: TextStyle(color: Colors.tealAccent))),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Profiles', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ..._profiles.map((p) => _ProfileTile(
                      profile: p,
                      isCurrent: p.id == _currentId,
                      onSwitch: () => _switch(p),
                      onDelete: () => _delete(p),
                    )),
                const SizedBox(height: 8),
                TvListTile(
                  leading:
                      const Icon(Icons.add, color: Colors.tealAccent),
                  title: 'Create New Profile',
                  onTap: _create,
                ),
              ],
            ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final AppProfile profile;
  final bool isCurrent;
  final VoidCallback onSwitch;
  final VoidCallback onDelete;

  const _ProfileTile({
    required this.profile,
    required this.isCurrent,
    required this.onSwitch,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: isCurrent ? Colors.tealAccent : Colors.transparent),
      ),
      child: ListTile(
        onTap: onSwitch,
        leading: Icon(
          isCurrent ? Icons.check_circle : Icons.circle_outlined,
          color: isCurrent ? Colors.tealAccent : Colors.white38,
        ),
        title: Text(profile.name,
            style: TextStyle(
              color: isCurrent ? Colors.tealAccent : Colors.white,
              fontWeight:
                  isCurrent ? FontWeight.bold : FontWeight.normal,
            )),
        subtitle: isCurrent
            ? const Text('Active', style: TextStyle(color: Colors.tealAccent, fontSize: 11))
            : null,
        trailing: profile.id != 'default'
            ? IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
