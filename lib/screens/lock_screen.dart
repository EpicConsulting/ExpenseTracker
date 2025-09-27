import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _tryUnlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.unlock(reason: 'Please authenticate to access your expenses');
    if (!mounted) return;
    if (!success) {
      setState(() {
        _error = 'Authentication failed. Try again.';
      });
    }
    setState(() {
      _busy = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.unlocked) {
      // ให้ MaterialApp ต้นทางเลือกหน้าหลักต่อเอง (Navigator.popUntil ฯลฯ) – ที่นี่ return container เฉยๆ
      return const SizedBox.shrink();
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  auth.biometricAvailable ? Icons.fingerprint : Icons.lock,
                  size: 96,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  auth.biometricAvailable
                      ? 'Biometric Authentication Required'
                      : 'Device not supporting biometrics.\nTap Continue to enter.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                _busy
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _tryUnlock,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(auth.biometricAvailable ? 'Authenticate' : 'Continue'),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // ในอนาคต: เปิด dialog ป้อน PIN (เก็บ PIN ใน secure storage)
                  },
                  child: const Text('Use PIN (coming soon)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}