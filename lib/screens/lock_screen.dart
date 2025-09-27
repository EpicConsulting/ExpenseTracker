import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    // เลื่อนไปหลังเฟรมแรกเพื่อเลี่ยง notifyListeners ระหว่าง build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authProvider.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.unlocked) {
      return const SizedBox.shrink();
    }

    final status = auth.status;
    final enrolled = status?.enrolled == true;
    final supported = status?.supported == true;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  enrolled ? Icons.fingerprint : Icons.lock_outline,
                  size: 110,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                if (auth.checking)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      Text(
                        enrolled
                            ? 'Biometric Authentication Required'
                            : supported
                                ? 'No biometric enrolled.\nPlease add a fingerprint or use device credential.'
                                : 'Device does not support biometrics.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (auth.lastError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.lastError!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (enrolled)
                        ElevatedButton.icon(
                          onPressed: () => auth.authenticate(allowDeviceCredential: true),
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Authenticate'),
                        )
                      else if (supported)
                        ElevatedButton(
                          onPressed: () => auth.refreshStatus(),
                          child: const Text('Re-check after enroll'),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => auth.devBypass(),
                          child: const Text('Continue (Dev Only)'),
                        ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => auth.devBypass(),
                        child: const Text('[DEV] Skip Authentication'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}