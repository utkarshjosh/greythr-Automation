import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'pages/dashboard_page.dart';
import 'pages/greyt_hr_page.dart';
import 'pages/config_page.dart';
import 'pages/logs_page.dart';
import 'pages/login_page.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'providers/automation_provider.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
}

void main() async {
  // Wrap everything in error handling
  runZonedGuarded(() async {
    print('🚀 App starting...');
    
    // Ensure Flutter binding is initialized first
    WidgetsFlutterBinding.ensureInitialized();
    print('✅ Flutter binding initialized');
    
    // Load environment variables
    try {
      await dotenv.load(fileName: '.env');
      print('✅ Environment variables loaded successfully');
    } catch (e) {
      print('⚠️ Warning: Could not load .env file: $e');
      print('Using default values or environment variables');
    }
    
    // Initialize Firebase with proper error handling - MUST complete before app starts
    print('🔥 Initializing Firebase...');
    bool firebaseInitialized = false;
    try {
      if (kIsWeb) {
        print('🌐 Web platform detected');
        // For web, we need FirebaseOptions
        // Try to get from environment variables, or use defaults from google-services.json
        final options = FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_API_KEY'] ?? 'AIzaSyB_ZNZtpXLmfuidSj9MiX3A9TMUVIRjihw',
          appId: dotenv.env['FIREBASE_APP_ID'] ?? '1:549856193798:web:default',
          messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '549856193798',
          projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? 'utkarsh-agent',
          storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? 'utkarsh-agent.firebasestorage.app',
          authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? 'utkarsh-agent.firebaseapp.com',
        );
        await Firebase.initializeApp(options: options);
      } else {
        print('📱 Mobile platform detected');
        // For mobile platforms, Firebase can auto-initialize from google-services.json/google-services.plist
        try {
          // Check if Firebase app already exists
          try {
            Firebase.app();
            print('✅ Firebase app already exists');
          } catch (e) {
            // App doesn't exist, initialize it
            print('🔄 Initializing new Firebase app from google-services.json...');
            try {
              // Try auto-initialization first (reads from google-services.json)
              await Firebase.initializeApp();
              print('✅ Firebase app created from google-services.json');
            } catch (autoInitError) {
              print('⚠️ Auto-initialization failed: $autoInitError');
              print('🔄 Trying with explicit options as fallback...');
              // Fallback: try with explicit options
              final fallbackOptions = FirebaseOptions(
                apiKey: dotenv.env['FIREBASE_API_KEY'] ?? 'AIzaSyB_ZNZtpXLmfuidSj9MiX3A9TMUVIRjihw',
                appId: dotenv.env['FIREBASE_APP_ID'] ?? '1:549856193798:android:default',
                messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '549856193798',
                projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? 'utkarsh-agent',
                storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? 'utkarsh-agent.firebasestorage.app',
              );
              await Firebase.initializeApp(options: fallbackOptions);
              print('✅ Firebase app created with explicit options');
            }
          }
        } catch (e) {
          print('❌ Failed to initialize Firebase app: $e');
          rethrow;
        }
      }
      
      // Verify Firebase is actually initialized
      try {
        final app = Firebase.app();
        print('✅ Firebase verified - App name: ${app.name}');
        firebaseInitialized = true;
      } catch (e) {
        print('❌ Firebase verification failed: $e');
        firebaseInitialized = false;
        throw Exception('Firebase initialization verification failed: $e');
      }
    } catch (e, stackTrace) {
      print('❌ Firebase initialization failed: $e');
      print('📋 Stack trace: $stackTrace');
      firebaseInitialized = false;
      // Don't continue if Firebase fails - it's critical for the app
      // Show error screen instead
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Firebase Initialization Failed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please check your Firebase configuration',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      return; // Exit early
    }

    // Only initialize notification service if Firebase is initialized
    // Delay notification initialization slightly to avoid lifecycle channel issues
    if (firebaseInitialized) {
      print('🔔 Setting up notifications...');
      // Initialize notifications after a short delay to let the framework settle
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          final notificationService = NotificationService();
          await notificationService.initialize();

          // Set up background message handler
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          print('✅ Notifications initialized');
        } catch (e) {
          print('❌ Error initializing notification service: $e');
        }
      });
    }

    print('🎨 Running app...');
    runApp(const UtkarsAgentApp());
    print('✅ App running');
  }, (error, stack) {
    print('❌❌❌ UNCAUGHT ERROR IN MAIN: $error');
    print('📋 Stack trace: $stack');
    // Even if everything fails, try to show something
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'App initialization failed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Check Android Studio Logcat for details',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  });
}

class UtkarsAgentApp extends StatelessWidget {
  const UtkarsAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AutomationProvider(),
      child: MaterialApp(
        title: 'UtkarsAgent',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
        ],
        builder: (context, child) {
          // Set up error widget builder
          FlutterError.onError = (FlutterErrorDetails details) {
            print('Flutter Error: ${details.exception}');
            print('Stack: ${details.stack}');
            FlutterError.presentError(details);
          };
          return child ?? const SizedBox();
        },
        home: const SafeAuthWrapper(),
      ),
    );
  }
}

class SafeAuthWrapper extends StatefulWidget {
  const SafeAuthWrapper({super.key});

  @override
  State<SafeAuthWrapper> createState() => _SafeAuthWrapperState();
}

class _SafeAuthWrapperState extends State<SafeAuthWrapper> {

  @override
  Widget build(BuildContext context) {
    print('🔐 AuthWrapper building...');
    
    try {
      print('🔍 Getting auth service...');
      final authService = AuthService();
      
      // Check if Firebase is initialized before using AuthService
      if (!authService.isFirebaseInitialized) {
        print('⚠️ Firebase not initialized, showing login page');
        return const LoginPage();
      }
      
      print('✅ Auth service obtained, Firebase is initialized');
      
      return StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          print('📊 Auth state snapshot: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');
          // Handle errors - show login page
          if (snapshot.hasError) {
            print('Auth state error: ${snapshot.error}');
            return const LoginPage();
          }
          
          // Show loading while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen(context);
          }
          
          // Show login page if not authenticated
          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginPage();
          }
          
          // Show home page if authenticated - wrap in error boundary
          return _buildSafeHomePage();
        },
      );
    } catch (e, stackTrace) {
      print('AuthWrapper exception: $e');
      print('Stack trace: $stackTrace');
      // Always show login page on any exception
      return const LoginPage();
    }
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple icon instead of logo to avoid asset issues
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeHomePage() {
    try {
      return const HomePage();
    } catch (e, stackTrace) {
      print('HomePage error: $e');
      print('Stack trace: $stackTrace');
      // If HomePage fails, show login page
      return const LoginPage();
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Widget _buildPage(int index) {
    try {
      switch (index) {
        case 0:
          return const DashboardPage();
        case 1:
          return const GreytHrPage();
        case 2:
          return const ConfigPage();
        case 3:
          return const LogsPage();
        default:
          return const DashboardPage();
      }
    } catch (e, stackTrace) {
      print('Page build error for index $index: $e');
      print('Stack trace: $stackTrace');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load page'),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _setupNotificationHandling();
  }

  void _setupNotificationHandling() {
    final notificationService = NotificationService();
    notificationService.setNotificationTapHandler((message) {
      // Navigate based on notification data
      final data = message.data;
      if (data.containsKey('page')) {
        final page = data['page'] as String;
        switch (page) {
          case 'greythr':
            setState(() {
              _selectedIndex = 1;
            });
            break;
          case 'logs':
            setState(() {
              _selectedIndex = 3;
            });
            break;
          case 'config':
            setState(() {
              _selectedIndex = 2;
            });
            break;
          default:
            setState(() {
              _selectedIndex = 0;
            });
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    final authService = AuthService();
    try {
      await authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      
      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Use icon instead of logo to avoid asset loading issues
              const Icon(Icons.work_rounded, size: 24),
              const SizedBox(width: 12),
              const Text('UtkarsAgent'),
            ],
          ),
          actions: [
            // User email display
            if (user?.email != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: Text(
                    user!.email!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            // Logout button
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: _buildSafeBody(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          elevation: 8,
          height: 72,
          backgroundColor: theme.colorScheme.surface,
          indicatorColor: theme.colorScheme.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          animationDuration: AppTheme.mediumAnimation,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work_rounded),
              label: 'GreytHR',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Config',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'Logs',
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      print('HomePage build error: $e');
      print('Stack trace: $stackTrace');
      // Return a simple error screen
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load home page'),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSafeBody() {
    try {
      return IndexedStack(
        index: _selectedIndex,
        children: List.generate(4, (index) => _buildPage(index)),
      );
    } catch (e, stackTrace) {
      print('Body build error: $e');
      print('Stack trace: $stackTrace');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load page'),
            const SizedBox(height: 8),
            Text(e.toString(), textAlign: TextAlign.center),
          ],
        ),
      );
    }
  }
}
