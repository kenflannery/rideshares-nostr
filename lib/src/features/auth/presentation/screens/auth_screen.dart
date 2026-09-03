import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ndk/ndk.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/nostr_service.dart';
import '../widgets/qr_scanner_dialog.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _nsecController = TextEditingController();
  final _bunkerUriController = TextEditingController();
  bool _isLoading = false;
  bool _isAmberInstalled = false;

  late TabController _tabController;

  // Nostr Connect State
  NostrConnect? _nostrConnect;
  StreamSubscription<Nip01Event>? _eventSubscription;
  bool _isConnectingNostrConnect = false;
  String? _bunkerErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAmber();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNostrConnectFlow();
    });
  }

  Future<void> _checkAmber() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final available = await authService.isAmberAvailable();
    if (mounted) {
      setState(() {
        _isAmberInstalled = available;
      });
    }
  }

  void _initNostrConnectFlow() {
    final nostrService = Provider.of<NostrService>(context, listen: false);
    final relays = nostrService.activeRelayUrls.isNotEmpty
        ? nostrService.activeRelayUrls
        : const [
            'wss://relay.damus.io',
            'wss://nos.lol',
            'wss://relay.primal.net',
          ];

    final nostrConnect = NostrConnect(
      relays: relays,
      appName: 'Rideshares Nostr',
      appUrl: 'https://rideshares.nostr',
      perms: [
        'sign_event:1',
        'sign_event:30402',
        'sign_event:5',
        'nip04_encrypt',
        'nip04_decrypt',
        'nip44_encrypt',
        'nip44_decrypt',
      ],
    );

    setState(() {
      _nostrConnect = nostrConnect;
      _isConnectingNostrConnect = false;
      _bunkerErrorMessage = null;
    });

    _startNostrConnectListener(nostrConnect);
  }

  void _startNostrConnectListener(NostrConnect nostrConnect) {
    _eventSubscription?.cancel();
    final nostrService = Provider.of<NostrService>(context, listen: false);

    // Continuous real-time subscription on relays for Kind 24133 ephemeral response
    final filter = Filter(
      kinds: [24133],
      pTags: [nostrConnect.keyPair.publicKey],
      since: (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 60,
    );

    try {
      final sub = nostrService.ndk.requests.subscription(
        filter: filter,
        explicitRelays: nostrConnect.relays,
      );

      _eventSubscription = sub.stream.listen((event) async {
        if (event.kind == 24133 && event.pubKey.isNotEmpty) {
          debugPrint("AuthScreen: Received Kind 24133 event from ${event.pubKey}");
          String? extractedUserPubkey;
          try {
            final localSigner = Bip340EventSigner(
              privateKey: nostrConnect.keyPair.privateKey,
              publicKey: nostrConnect.keyPair.publicKey,
            );
            final decrypted = await localSigner.decryptNip44(
              ciphertext: event.content,
              senderPubKey: event.pubKey,
            );
            if (decrypted != null) {
              final resp = jsonDecode(decrypted);
              final result = resp["result"]?.toString();
              if (result != null && (result.length == 64 || result.startsWith('npub1'))) {
                extractedUserPubkey = result;
              }
            }
          } catch (_) {}

          _onAmberConnected(event.pubKey, nostrConnect, explicitUserPubkey: extractedUserPubkey);
        }
      });
    } catch (e) {
      debugPrint("AuthScreen: Error starting kind 24133 subscription: $e");
    }

    // Run NDK's native bunker handshake in parallel
    nostrService.ndk.bunkers.connectWithNostrConnect(nostrConnect).then((conn) {
      if (conn != null && mounted) {
        debugPrint("AuthScreen: connectWithNostrConnect resolved for ${conn.remotePubkey}");
        _onAmberConnected(conn.remotePubkey, nostrConnect);
      }
    }).catchError((err) {
      debugPrint("AuthScreen: connectWithNostrConnect error: $err");
    });
  }

  void _onAmberConnected(
    String remoteBunkerPubkey,
    NostrConnect nostrConnect, {
    String? explicitUserPubkey,
  }) async {
    if (!mounted) return;

    _eventSubscription?.cancel();
    setState(() {
      _isConnectingNostrConnect = true;
      _bunkerErrorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final nostrService = Provider.of<NostrService>(context, listen: false);

    final conn = BunkerConnection(
      privateKey: nostrConnect.keyPair.privateKey!,
      remotePubkey: remoteBunkerPubkey,
      relays: nostrConnect.relays,
    );

    final success = await authService.loginWithNip46Connection(
      conn,
      nostrService,
      explicitUserPubkey: explicitUserPubkey,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected with Remote Signer / Amber!')),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isConnectingNostrConnect = false;
          _bunkerErrorMessage = 'Connection to remote signer failed. Please retry.';
        });
      }
    }
  }

  Future<void> _openInAmber(String connectUrl) async {
    Clipboard.setData(ClipboardData(text: connectUrl));
    try {
      final uri = Uri.parse(connectUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied! Open Amber -> tap "+" -> "Paste from clipboard"')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied! Open Amber -> tap "+" -> "Paste from clipboard"')),
        );
      }
    }
  }

  void _showManualPubkeyInput() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enter Amber Account (npub)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the public key (npub) shown at the top of your Amber screen:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Your Amber npub or hex key',
                  hintText: 'npub1...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = controller.text.trim();
                Navigator.of(ctx).pop();
                if (key.isNotEmpty && _nostrConnect != null) {
                  _onAmberConnected(key, _nostrConnect!);
                }
              },
              child: const Text('Connect Account'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _nsecController.dispose();
    _bunkerUriController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateKey() async {
    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final nsec = await authService.generateNewKey();

    if (nsec != null && mounted) {
      await _showBackupDialog(nsec);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error generating key.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importKey() async {
    final nsecInput = _nsecController.text.trim();
    if (nsecInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your nsec key.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.importKey(nsecInput);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key imported successfully!')),
        );
        _nsecController.clear();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error importing key. Check format.')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithAmber() async {
    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.loginWithAmber();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected with Amber signer!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not authenticate with Amber.')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithNip07() async {
    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.loginWithNip07();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected with Browser Extension!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find or authenticate with NIP-07 extension.')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithBunkerUri([String? inputUri]) async {
    final uri = inputUri ?? _bunkerUriController.text.trim();
    if (uri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or scan a bunker:// URI.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final nostrService = Provider.of<NostrService>(context, listen: false);

    final success = await authService.loginWithBunkerUrl(uri, nostrService);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected with Remote Signer (NIP-46)!')),
        );
        _bunkerUriController.clear();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to remote signer.')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanBunkerQr() async {
    final scannedCode = await QrScannerDialog.scan(context);
    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      _bunkerUriController.text = scannedCode;
      await _loginWithBunkerUri(scannedCode);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.clearKey();
    } catch (e) {
      debugPrint("Error logging out: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error logging out.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showBackupDialog(String nsec) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('🚨 Backup Your Private Key! 🚨'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                  'This is your private key (nsec). It is the ONLY way to access your Nostr account.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text('⚠️ WRITE IT DOWN and store it securely offline.'),
                const Text('⚠️ DO NOT share it with anyone.'),
                const Text('⚠️ If you lose this key, your account CANNOT be recovered.'),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: SelectableText(nsec, style: const TextStyle(fontFamily: 'monospace')),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to Clipboard'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: nsec));
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('nsec copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('I HAVE BACKED IT UP SAFELY'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Signer'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : authService.isLoggedIn
              ? _buildLoggedInView(authService)
              : _buildLoggedOutView(),
    );
  }

  Widget _buildLoggedInView(AuthService authService) {
    String signerLabel;
    switch (authService.loginType) {
      case LoginType.nsec:
        signerLabel = 'Local Key (nsec)';
        break;
      case LoginType.amber:
        signerLabel = 'Amber / External App (NIP-55)';
        break;
      case LoginType.nip07:
        signerLabel = 'Browser Extension (NIP-07)';
        break;
      case LoginType.nip46:
        signerLabel = 'Remote Bunker (NIP-46)';
        break;
      default:
        signerLabel = 'Custom Signer';
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
          const SizedBox(height: 12),
          const Text(
            'Connected to Nostr',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Center(
            child: Chip(
              avatar: const Icon(Icons.security, size: 18),
              label: Text('Signer: $signerLabel'),
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Your Public Key (npub):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SelectableText(
              authService.npub ?? 'Error: Npub not found',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Npub'),
            onPressed: authService.npub == null
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: authService.npub!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Npub copied to clipboard')),
                    );
                  },
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _logout,
            child: const Text('Logout / Disconnect Signer', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedOutView() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          tabs: const [
            Tab(icon: Icon(Icons.key), text: 'Local Key'),
            Tab(icon: Icon(Icons.phone_android), text: 'Amber / App'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Remote Bunker'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLocalKeyTab(),
              _buildAmberTab(),
              _buildBunkerTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalKeyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create or Import Private Key',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate a new identity or import your existing nsec private key securely stored on this device.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Generate New Key', style: TextStyle(fontSize: 16)),
            onPressed: _generateKey,
          ),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 15),
          const Text('Or paste existing nsec:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _nsecController,
            decoration: const InputDecoration(
              labelText: 'nsec1...',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            maxLines: 1,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            onPressed: _importKey,
            child: const Text('Import Key', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildAmberTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'External Signer (NIP-55 / NIP-07)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Delegate event signing to external signer apps like Amber on Android, keeping your private keys isolated.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Sign in with Amber (Android)', style: TextStyle(fontSize: 16)),
            onPressed: _loginWithAmber,
          ),
          if (!_isAmberInstalled && !kIsWeb) ...[
            const SizedBox(height: 12),
            const Text(
              'Amber signer not detected. Install Amber from F-Droid or GitHub to use.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (kIsWeb) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.extension),
              label: const Text('Sign in with Extension (NIP-07)', style: TextStyle(fontSize: 16)),
              onPressed: _loginWithNip07,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBunkerTab() {
    final connectUrl = _nostrConnect?.nostrConnectURL;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Amber / Remote Signer (NIP-46)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan this QR code in Amber, Keet, or your NIP-46 remote signer app to connect:',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),

          if (_bunkerErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _bunkerErrorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (connectUrl == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: PrettyQrView.data(
                    data: connectUrl,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isConnectingNostrConnect)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text(
                    'Amber approved! Logging in...',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Listening on relay... Scan QR in Amber',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueAccent),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open in Amber'),
                  onPressed: () => _openInAmber(connectUrl),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Link'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: connectUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied! Open Amber -> tap "+" -> "Paste from clipboard"')),
                    );
                  },
                ),
                TextButton(
                  onPressed: _showManualPubkeyInput,
                  child: const Text('Already approved?'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Regenerate QR session',
                  onPressed: _initNostrConnectFlow,
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            'Or connect to a Bunker URI:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.blueGrey[800],
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan Bunker QR Code with Camera'),
            onPressed: _scanBunkerQr,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bunkerUriController,
            decoration: const InputDecoration(
              labelText: 'bunker://<pubkey>?relay=wss://...&secret=...',
              border: OutlineInputBorder(),
              hintText: 'Paste bunker:// URL',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _loginWithBunkerUri(),
            child: const Text('Connect to Bunker', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}