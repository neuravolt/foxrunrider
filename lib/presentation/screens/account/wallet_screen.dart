import 'package:flutter/material.dart';
import 'package:ride_on/core/utils/theme/theme_style.dart';
import 'package:ride_on/core/utils/translate.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Wallet".translate(context), style: headingBlack(context)),
      ),
      body: Center(
        child: Text(
          "coming soon".translate(context),
          style: headingBlack(context).copyWith(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
