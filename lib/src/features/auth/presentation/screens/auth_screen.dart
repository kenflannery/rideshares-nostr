import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart'; // Adjust import path if needed

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nsecController = TextEditingController();
  bool _isLoading = false;
  String? _generatedNsec; // To temporarily hold the generated nsec for display

  @override
  void dispose() {
    _nsecController.dispose();
    super.dispose();
  }

  // --- Action Methods ---

  Future<void> _generateKey() async {
    setState(() {
      _isLoading = true;
      _generatedNsec = null;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final nsec = await authService.generateNewKey(); // AuthService notifies here

    // Keep isLoading true until AFTER the dialog is handled

    if (nsec != null && mounted) {
      // --- Don't set isLoading = false yet ---
      // --- Don't pop yet ---

      // Show the dialog and WAIT for it to be closed by the user
      await _showBackupDialog(nsec); // Add await here

      // --- Now handle post-dialog logic ---
      if (mounted) {
        // Set loading false AFTER dialog is closed
        setState(() { _isLoading = false; });
        // Pop the screen AFTER dialog is closed
        Navigator.of(context).pop();
      }
    } else {
      // Error generating key
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error generating key.')),
        );
        // Ensure loading stops on error
        setState(() { _isLoading = false; });
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

    setState(() { _isLoading = true; });
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.importKey(nsecInput);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key imported successfully!')),
        );
        _nsecController.clear(); // Clear field on success
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error importing key. Check format.')),
        );
      }
      setState(() { _isLoading = false; });
    }
    // Main screen will rebuild via Provider listener if login state changes.
  }

  Future<void> _logout() async {
    // Set loading state at the beginning
    setState(() { _isLoading = true; });
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      // Perform the async operation
      await authService.clearKey();
      // If clearKey completes successfully, the Provider listener will
      // trigger a rebuild showing the logged-out state.
    } catch (e) {
      // Handle potential errors during key clearing
      debugPrint("Error logging out: $e");
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error logging out.')),
        );
      }
    } finally {
      // *** CRUCIAL: Set loading state back to false ***
      // This runs whether clearKey succeeded or failed, ensuring the spinner hides.
      // Check if mounted because the async gap could mean the widget was disposed.
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- Dialog for Backup (Needs to return a Future) ---
  // Change the return type to Future<void>
  Future<void> _showBackupDialog(String nsec) async { // Make async
    // Use await here so the _generateKey function pauses
    await showDialog<void>( // Expect no return value specifically needed
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
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                const Text(
                    '⚠️ WRITE IT DOWN and store it securely offline.'),
                const Text('⚠️ DO NOT share it with anyone.'),
                const Text(
                    '⚠️ If you lose this key, your account CANNOT be recovered.'),
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
                // Just pop the dialog itself
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Listen to AuthService changes to rebuild the UI
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rideshares - Account'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : authService.isLoggedIn
              ? _buildLoggedInView(authService)
              : _buildLoggedOutView(),
        ),
      ),
    );
  }

  // --- Logged In View ---
  Widget _buildLoggedInView(AuthService authService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Welcome!', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 20),
        const Text('Your Public Key (npub):'),
        SelectableText(
          authService.npub ?? 'Error: Npub not found', // Display npub
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy Npub'),
          onPressed: authService.npub == null ? null : () {
            Clipboard.setData(ClipboardData(text: authService.npub!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Npub copied to clipboard')),
            );
          },
        ),
        const SizedBox(height: 40),
        // TODO: Add navigation to Feed Screen later
        // ElevatedButton(
        //   onPressed: () { /* Navigate to Feed */ },
        //   child: const Text('Go to Rides Feed'),
        // ),
        // const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _logout,
          child: const Text('Logout / Clear Key'),
        ),
      ],
    );
  }

  // --- Logged Out View ---
  Widget _buildLoggedOutView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Login or Create Account',
          style: TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _generateKey,
          child: const Text('Generate New Key'),
        ),
        // Display generated key temporarily if needed (handled by dialog now)
        // if (_generatedNsec != null) ...
        const SizedBox(height: 40),
        const Text(
          'Or Import Existing Key:',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nsecController,
          decoration: const InputDecoration(
            labelText: 'Paste your nsec private key here',
            border: OutlineInputBorder(),
          ),
          obscureText: true, // Hide the key visually
          maxLines: 1,
        ),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: _importKey,
          child: const Text('Import Key'),
        ),
      ],
    );
  }
}