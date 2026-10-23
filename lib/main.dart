
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Firebase initialized successfully');
    debugPrint('Firebase project: ${Firebase.app().options.projectId}');

    await setupFCM();
  } catch (e, stack) {
    debugPrint('FIREBASE INITIALIZATION ERROR: $e');
    debugPrint('$stack');
  }

  runApp(const CoffeeOrderApp());
}

// Firebase Cloud Messaging setup
Future<void> setupFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Notification permission: ${settings.authorizationStatus}',
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('PUSH RECEIVED');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
    });

    final token = await messaging.getToken();
    debugPrint('FCM TOKEN: $token');

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        debugPrint('Notification opened');
        debugPrint('Data: ${message.data}');
      },
    );
  } catch (e) {
    debugPrint('FCM SETUP ERROR: $e');
  }
}

class CoffeeOrderApp extends StatelessWidget {
  const CoffeeOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Coffee Order',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
        ),
        useMaterial3: true,
      ),
      home: const OrderPage(),
    );
  }
}

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String coffee = 'Cappuccino';
  String pickupTime = '10:00';
  bool loading = false;

  final DatabaseReference ordersRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://coffeeorder-c1d60-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref('orders');

  Future<void> saveOrder() async {
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name and phone number'),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      debugPrint('STEP 1: Starting Firebase write');

      final DatabaseReference newOrder = ordersRef.push();

      debugPrint('STEP 2: Order reference created');

      await newOrder
          .set({
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'coffee': coffee,
            'pickupTime': pickupTime,
            'createdAt': ServerValue.timestamp,
          })
          .timeout(const Duration(seconds: 15));

      debugPrint('STEP 3: Order saved successfully');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      nameController.clear();
      phoneController.clear();
    } on TimeoutException {
      debugPrint('FIREBASE ERROR: Write timed out after 15 seconds');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebase timeout. Check connection.'),
        ),
      );
    } catch (e, stack) {
      debugPrint('FIREBASE WRITE ERROR: $e');
      debugPrint('$stack');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving order: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('☕ Coffee Order'),
        backgroundColor: Colors.brown.shade100,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Place your coffee order',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Your name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: coffee,
            decoration: const InputDecoration(
              labelText: 'Choose coffee',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Cappuccino',
                child: Text('Cappuccino'),
              ),
              DropdownMenuItem(
                value: 'Latte',
                child: Text('Latte'),
              ),
              DropdownMenuItem(
                value: 'Americano',
                child: Text('Americano'),
              ),
              DropdownMenuItem(
                value: 'Espresso',
                child: Text('Espresso'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => coffee = value);
              }
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: pickupTime,
            decoration: const InputDecoration(
              labelText: 'Pickup time',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '10:00', child: Text('10:00')),
              DropdownMenuItem(value: '11:00', child: Text('11:00')),
              DropdownMenuItem(value: '12:00', child: Text('12:00')),
              DropdownMenuItem(value: '13:00', child: Text('13:00')),
              DropdownMenuItem(value: '14:00', child: Text('14:00')),
              DropdownMenuItem(value: '15:00', child: Text('15:00')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => pickupTime = value);
              }
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: loading ? null : saveOrder,
              child: loading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Saving...'),
                      ],
                    )
                  : const Text('Place order'),
            ),
          ),
        ],
      ),
    );
  }
}
