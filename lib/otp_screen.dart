import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import 'dart:math';

class OTPScreen extends StatefulWidget {
  final EmailOTP auth;
  final String email;
  final String phone;
  final bool isDemoMode; // NEW parameter

  const OTPScreen({super.key, required this.auth, required this.email, required this.phone, this.isDemoMode = false});

  @override State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final otpController = TextEditingController();

  void _verify() async {
    bool verified = false;

    if (widget.isDemoMode) {
      // In Demo mode, code '1234' always works
      if (otpController.text == "1234") verified = true;
    } else {
      // Try real verification
      verified = await widget.auth.verifyOTP(otp: otpController.text);
    }

    if (verified) {
      String tempPass = "GX-${Random().nextInt(9000) + 1000}";
      _showSuccess(tempPass);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Code")));
    }
  }

  void _showSuccess(String pass) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text("Success"),
        content: Text("Your temporary passkey is: $pass"),
        actions: [ElevatedButton(onPressed: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        }, child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify")),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Text("Enter code sent to ${widget.email}"),
          if (widget.isDemoMode)
            const Text("(Demo Mode Active: Enter 1234)", style: TextStyle(color: Colors.orange, fontSize: 12)),
          const SizedBox(height: 30),
          TextField(controller: otpController, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _verify, child: const Text("VERIFY")),
        ],
      ),
    );
  }
}