import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/screens/auth/login_screen.dart';
import 'package:ride_on/presentation/screens/onboarding/language_select_screen.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../../core/utils/theme/theme_style.dart';



class Onboardingscreen extends StatefulWidget {
  const Onboardingscreen({super.key});

  @override
  State<Onboardingscreen> createState() => _OnboardingscreenState();
}

class _OnboardingscreenState extends State<Onboardingscreen> {
  List content = [
    {
      "image": "assets/images/cuate.svg",
      "title": "More than just a ride, it's a vibe!",
      "description":
          "Book rides in seconds, track your arrival in real-time, and enjoy stress-free journeys. Choose from different ride options, all driven by professional and friendly drivers."
    },
  ];

  late PageController pageController;
  int currentIndex = 0;

  final List<String> _backgroundImages = [
    "assets/images/onboarding_bg1.png",
    "assets/images/onboarding_bg2.png",
    "assets/images/onboarding_bg3.png",
  ];

  Timer? _timer;
  int _currentBgIndex = 0;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: 0);
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentBgIndex = (_currentBgIndex + 1) % _backgroundImages.length;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (var imagePath in _backgroundImages) {
      precacheImage(AssetImage(imagePath), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);
    return Scaffold(
      backgroundColor: whiteColor,
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1000),
                  child: Image.asset(
                    _backgroundImages[_currentBgIndex],
                    key: ValueKey<int>(_currentBgIndex),
                    fit: BoxFit.fill,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 40,
                right: 40,
                child: SafeArea(
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(35),
                    child: Container(
                      height: 70,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFC045), // Lighter yellowish-orange
                            Color(0xFFFF9C1A), // Rich orange
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9C1A).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Left: White circle with location pin
                          Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFFF9C1A),
                              size: 26,
                            ),
                          ),
                          // Center: Text
                          Expanded(
                            child: Text(
                              "Get Started".translate(context),
                              textAlign: TextAlign.center,
                              style: largeHeadingMedium.copyWith(
                                color: const Color(0xFF1E1E1E),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Right: Black circle with arrow
                          Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1A1A1A),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 70,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    languageButton(
                      onTap: () {
                        goTo(const SelectLanguageScreen(
                          isBack: true,
                        ));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget customOnboardingWidget(String image, String title, String description) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: SvgPicture.asset(image),
        ),
        const SizedBox(
          height: 20,
        ),
        Flexible(
          child: Text(
            title,
            textAlign: TextAlign.start,
            style: largeHeadingMedium.copyWith(fontSize: 24),
            softWrap: true,
          ),
        ),
        const SizedBox(
          height: 15,
        ),
        Text(
          description,
          style: smallHeadingMedium.copyWith(
              color: notifires.getGrey2whiteColor, fontSize: 14),
          textAlign: TextAlign.start,
        )
      ],
    ),
  );
}
