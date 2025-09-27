import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    // เลื่อน init หลังเฟรมแรกเล็กน้อยเพื่อเลี่ยง notify ระหว่าง build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth.init();
    });
  }

  void _maybeAutoAuthenticate(AuthProvider auth) {
    if (auth.unlocked) return;
    final status = auth.status;
    if (status == null) return; // init ยังไม่เสร็จ
    if (!status.supported || !status.enrolled) return;
    if (auth.authInProgress) return;
    if (auth.autoAuthAttempted) return;

    // เรียก biometric อัตโนมัติ (pure biometric)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      auth.authenticate(
        allowDeviceCredential: false, // Option 1: ไม่ใช้ fallback PIN
        auto: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    _maybeAutoAuthenticate(auth);

    if (auth.unlocked) {
      // ให้ MaterialApp rebuild เปลี่ยนหน้า
      return const SizedBox.shrink();
    }

    final status = auth.status;
    final supported = status?.supported == true;
    final enrolled = status?.enrolled == true;

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
                            ? (auth.authInProgress
                                ? 'Authenticating...'
                                : 'Biometric Authentication Required')
                            : supported
                                ? 'No biometric enrolled.\nPlease add a fingerprint.'
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
                      // แสดงปุ่ม Retry เฉพาะกรณี auto ล้มเหลว และไม่ได้กำลัง auth
                      if (enrolled &&
                          !auth.authInProgress &&
                          auth.autoAuthAttempted &&
                          !auth.unlocked)
                        ElevatedButton.icon(
                          onPressed: () => auth.authenticate(
                            allowDeviceCredential: false,
                            auto: false,
                          ),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Try Again'),
                        ),
                      if (supported && !enrolled && !auth.checking)
                        ElevatedButton(
                          onPressed: () => auth.refreshStatus(),
                          child: const Text('Re-check after enroll'),
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