import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // ลอง auth หลัง frame (ถ้า biometricAvailable จะ popup)
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    final auth = context.read<AuthProvider>();
    if (!auth.biometricAvailable) return; // รอให้ user เห็น UI
    final ok = await auth.unlock();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'Authentication failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.unlocked) {
      // ปล่อยให้ MaterialApp rebuild ไปยังหน้าหลัก (home: ...)
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
                  auth.biometricAvailable ? Icons.fingerprint : Icons.lock_outline,
                  size: 110,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  auth.biometricAvailable
                      ? 'Biometric Authentication Required'
                      : 'No biometric enrolled / not supported.\nPlease enroll or tap Skip (Dev).',
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
                if (auth.biometricAvailable)
                  ElevatedButton.icon(
                    onPressed: auth.authInProgress ? null : _attempt,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(auth.authInProgress ? 'Authenticating...' : 'Authenticate'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => auth.recheck(),
                    child: const Text('Re-check Biometrics'),
                  ),
                const SizedBox(height: 12),
                // ปุ่ม Bypass เฉพาะ DEV – เอาออกใน Production
                TextButton(
                  onPressed: () => context.read<AuthProvider>().devBypass(),
                  child: const Text('[DEV] Skip Authentication'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}