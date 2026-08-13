import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/screens/account/static_screen.dart';
import 'package:ride_on/presentation/screens/home/item_home_screen.dart';
import 'package:ride_on/presentation/screens/onboarding/language_select_screen.dart';
import '../../../core/extensions/workspace.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../../core/utils/theme/theme_style.dart';
import '../../cubits/auth/apple_login_cubit.dart';
import '../../cubits/auth/google_login_cubit.dart';
import '../../cubits/auth/login_cubit.dart';
import '../../cubits/auth/user_authenticate_cubit.dart';
import '../../widgets/custom_text_form_field.dart';
import 'google_update_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController textEditingLoginControllerPhoneNumber =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String defaultCountry = "IN";

  @override
  void initState() {
    context.read<SetCountryCubit>().reset();
    super.initState();
    isNumeric = false;
    textEditingLoginControllerPhoneNumber.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    textEditingLoginControllerPhoneNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);
    final isPhoneFilled =
        textEditingLoginControllerPhoneNumber.text.trim().length >= 10;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF7),
        bottomSheet: isNumeric == true && Platform.isIOS
            ? KeyboardDoneButton(
                onTap: () {
                  setState(() {
                    isNumeric = false;
                  });
                },
              )
            : null,
        resizeToAvoidBottomInset: true,
        body: MultiBlocListener(
          listeners: [
            BlocListener<AuthLoginCubit, AuthLoginState>(
              listener: (context, state) {
                if (state is LoginLoading) {
                  Widgets.showLoader(context);
                } else if (state is LoginSuccess) {
                  Widgets.hideLoder(context);
                  context.read<AuthLoginCubit>().resetState();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtpScreen(
                        number: textEditingLoginControllerPhoneNumber.text,
                        countryCode:
                            state.loginModel.data?.phoneCountry ?? "+91",
                        defaultCountry: defaultCountry,
                        routeString: "Login",
                        otpValue: state.loginModel.data?.resetToken ?? "",
                      ),
                    ),
                  );
                } else if (state is LoginFailure) {
                  Widgets.hideLoder(context);
                  showErrorToastMessage(state.error);
                }
              },
            ),
            BlocListener<GoogleLoginCubit, GoogleLoginState>(
              listener: (context, state) {
                if (state is GoogleLoginSucess) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ItemHomeScreen(),
                    ),
                  );
                } else if (state is AddPhoneNumberState) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoogleUpdate(
                        email: state.loginModel.data?.email ?? "",
                      ),
                    ),
                  );
                } else if (state is GoogleLoginFailure) {
                  showErrorToastMessage(state.error);
                }
              },
            ),
            BlocListener<AppleLoginCubit, AppleLoginState>(
              listener: (context, state) {
                if (state is AppleLoginSuccess) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ItemHomeScreen(),
                    ),
                  );
                } else if (state is AddPhoneNumberAppleState) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GoogleUpdate(),
                    ),
                  );
                } else if (state is AppleLoginFailure) {
                  closeLoading();
                  showErrorToastMessage(state.error);
                }
              },
            ),
          ],
          child: Stack(
            children: [
              // Background Gradient & Accents
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFDF5),
                        Color(0xFFFFF9EB),
                        Color(0xFFFFFFFF),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Top Left Soft Glow & Dot Grid Accent
              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFEBAA).withValues(alpha: 0.5),
                        const Color(0xFFFFF9EB).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 100,
                left: 20,
                child: _buildDotGrid(),
              ),

              // Bottom Left Leaf Flourish & Dot Grid Accent
              Positioned(
                bottom: 10,
                left: 10,
                child: Opacity(
                  opacity: 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.eco_outlined,
                        size: 64,
                        color: const Color(0xFFE5A000).withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 10),
                      _buildDotGrid(),
                    ],
                  ),
                ),
              ),

              // Main Screen Scroll Content
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 8),

                                // Header: Foxrun Logo & Action Pills
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "foxrun",
                                      style: heading1(context).copyWith(
                                        color: const Color(0xFF1A1A1A),
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        // Language Button Pill
                                        InkWell(
                                          onTap: () {
                                            goTo(const SelectLanguageScreen(
                                                isBack: true));
                                          },
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(0xFFF2EAD6),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.04),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.language_rounded,
                                                  size: 16,
                                                  color: Color(0xFFE5A000),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "EN",
                                                  style: regular2(context)
                                                      .copyWith(
                                                    color:
                                                        const Color(0xFF2C3E50),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  size: 16,
                                                  color: Color(0xFF7F8C8D),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Help Button Pill
                                        InkWell(
                                          onTap: () {
                                            showModalBottomSheet(
                                              useRootNavigator: true,
                                              backgroundColor:
                                                  notifires.getbgcolor,
                                              isScrollControlled: true,
                                              useSafeArea: true,
                                              context: context,
                                              builder: (BuildContext context) {
                                                return const StaticScreen(
                                                  data: "Help & Support",
                                                );
                                              },
                                            );
                                          },
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(0xFFF2EAD6),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.04),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.help_outline_rounded,
                                                  size: 16,
                                                  color: Color(0xFF2C3E50),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Help".translate(context),
                                                  style: regular2(context)
                                                      .copyWith(
                                                    color:
                                                        const Color(0xFF2C3E50),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Vehicle Selection Pills Row (Bike highlighted, Car, Taxi)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Highlighted Bike Pill
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3CD),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFFFE599),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF5A623)
                                                .withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.two_wheeler_rounded,
                                        size: 22,
                                        color: Color(0xFFD98A00),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Car Icon
                                    const Icon(
                                      Icons.directions_car_filled_rounded,
                                      size: 30,
                                      color: Color(0xFF2C2C2C),
                                    ),
                                    const SizedBox(width: 12),
                                    // Taxi Icon
                                    const Icon(
                                      Icons.local_taxi_rounded,
                                      size: 32,
                                      color: Color(0xFF2C2C2C),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Center Hero Artwork: 3D Phone on Stand with Sparkles
                                _buildPhoneHeroGraphic(),

                                const SizedBox(height: 28),

                                // Headline & Subtitle
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    text: "What's your ".translate(context),
                                    style: heading1(context).copyWith(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E1E1E),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: "number?".translate(context),
                                        style: heading1(context).copyWith(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  "We'll use this to verify your account"
                                      .translate(context),
                                  style: regular2(context).copyWith(
                                    color: const Color(0xFF718096),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 28),

                                // Phone Number Input Field Container Card
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: BlocBuilder<SetCountryCubit,
                                      SetCountryState>(
                                    builder: (context, state) {
                                      return IntelPhoneFieldRefs(
                                        onTap: () {
                                          isNumeric = true;
                                          setState(() {});
                                        },
                                        fillColor: Colors.white,
                                        borderColor: const Color(0xFFF0EBE1),
                                        borderRadius: 20,
                                        dropdownTextStyle:
                                            regular2(context).copyWith(
                                          color: const Color(0xFF1E1E1E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        inputTextStyle:
                                            regular2(context).copyWith(
                                          color: const Color(0xFF1E1E1E),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                        hintStyle: regular3(context).copyWith(
                                          color: const Color(0xFFA0AEC0),
                                          fontSize: 15,
                                        ),
                                        customPrefixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              height: 24,
                                              width: 1,
                                              color: const Color(0xFFE2E8F0),
                                              margin: const EdgeInsets.only(
                                                left: 2,
                                                right: 12,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.call_outlined,
                                              color: Color(0xFFA0AEC0),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                        onChanged: (value) {
                                          final countryCode =
                                              value?.countryISOCode ?? '';
                                          String number = value?.number ?? '';

                                          if (countryCode == 'MY' &&
                                              number.startsWith('0')) {
                                            number = number.substring(1);
                                            textEditingLoginControllerPhoneNumber
                                                .text = number;
                                            textEditingLoginControllerPhoneNumber
                                                    .selection =
                                                TextSelection.fromPosition(
                                              TextPosition(
                                                  offset: number.length),
                                            );
                                          }
                                          setState(() {});
                                          return null;
                                        },
                                        key: ValueKey(state.countryCode),
                                        defultcountry: state.countryCode,
                                        textEditingControllerCommons:
                                            textEditingLoginControllerPhoneNumber,
                                        oncountryChanged: (number) {
                                          context
                                              .read<SetCountryCubit>()
                                              .reset();
                                          textEditingLoginControllerPhoneNumber
                                              .clear();
                                          context
                                              .read<SetCountryCubit>()
                                              .setCountry(
                                                dialCode: number.dialCode,
                                                countryCode: number.code,
                                              );
                                        },
                                        hintText:
                                            "Enter phone number".translate(context),
                                        validator: (phoneNumber) {
                                          if (phoneNumber == null ||
                                              phoneNumber.number.isEmpty) {
                                            return "Please enter your phone number"
                                                .translate(context);
                                          }

                                          final countryCode =
                                              phoneNumber.countryISOCode;
                                          final expectedLength =
                                              phoneLengths[countryCode] ?? 10;

                                          String cleanedNumber = phoneNumber
                                              .number
                                              .replaceAll(RegExp(r'\D'), '');
                                          if (cleanedNumber.startsWith('0')) {
                                            cleanedNumber =
                                                cleanedNumber.substring(1);
                                          }

                                          if (cleanedNumber.length !=
                                              expectedLength) {
                                            return "${"Phone number must be".translate(context)} $expectedLength ${"digits".translate(context)}";
                                          }

                                          return null;
                                        },
                                      );
                                    },
                                  ),
                                ),

                                const Spacer(),
                                const SizedBox(height: 20),

                                // Shield Icon & Legal Terms Box
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF9EB),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFFF0C2),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF0C2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.shield_outlined,
                                          color: Color(0xFFD98A00),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            showModalBottomSheet(
                                              useRootNavigator: true,
                                              backgroundColor:
                                                  notifires.getbgcolor,
                                              isScrollControlled: true,
                                              useSafeArea: true,
                                              context: context,
                                              builder: (BuildContext context) {
                                                return const StaticScreen(
                                                  data: "Terms and Conditions",
                                                );
                                              },
                                            );
                                          },
                                          child: Text.rich(
                                            TextSpan(
                                              text:
                                                  "By continuing, you confirm that you are 18 years of age and agree to the "
                                                      .translate(context),
                                              style: regular3(context).copyWith(
                                                fontSize: 11.5,
                                                color: const Color(0xFF64748B),
                                                height: 1.45,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: "Terms & Conditions"
                                                      .translate(context),
                                                  style: regular3(context)
                                                      .copyWith(
                                                    color: const Color(
                                                        0xFFD98A00),
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text:
                                                      " and ".translate(context),
                                                ),
                                                TextSpan(
                                                  text: "Privacy Policy"
                                                      .translate(context),
                                                  style: regular3(context)
                                                      .copyWith(
                                                    color: const Color(
                                                        0xFFD98A00),
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Full-Width Gradient Next Button
                                GestureDetector(
                                  onTap: () {
                                    if (_formKey.currentState!.validate()) {
                                      if (textEditingLoginControllerPhoneNumber
                                          .text.isEmpty) {
                                        showErrorToastMessage(
                                            "Please enter the phone number"
                                                .translate(context));
                                        return;
                                      }
                                      context.read<AuthLoginCubit>().login(
                                            context: context,
                                            phoneCountry: context
                                                    .read<SetCountryCubit>()
                                                    .state
                                                    .dialCode
                                                    .startsWith("+")
                                                ? context
                                                    .read<SetCountryCubit>()
                                                    .state
                                                    .dialCode
                                                : "+${context.read<SetCountryCubit>().state.dialCode}",
                                            phoneNumber:
                                                textEditingLoginControllerPhoneNumber
                                                    .text,
                                          );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    height: 56,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: isPhoneFilled
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFFFC533),
                                                Color(0xFFFF9F0A),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            )
                                          : null,
                                      color: isPhoneFilled
                                          ? null
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: isPhoneFilled
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFFF9F0A)
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 14,
                                                offset: const Offset(0, 5),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Text(
                                          "Next".translate(context),
                                          style: heading2(context).copyWith(
                                            color: isPhoneFilled
                                                ? const Color(0xFF1E1E1E)
                                                : const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Positioned(
                                          right: 20,
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            color: isPhoneFilled
                                                ? const Color(0xFF1E1E1E)
                                                : const Color(0xFF94A3B8),
                                            size: 22,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3D Phone Platform Hero Widget with Sparkles
  Widget _buildPhoneHeroGraphic() {
    return SizedBox(
      width: 170,
      height: 145,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Yellow Pedestal Glow
          Positioned(
            bottom: 6,
            child: Container(
              width: 130,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0C2),
                borderRadius: const BorderRadius.all(
                  Radius.elliptical(130, 28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),

          // 3D Pedestal Platform Base
          Positioned(
            bottom: 12,
            child: Container(
              width: 110,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFFDF5),
                    Color(0xFFFFE8A3),
                    Color(0xFFFFD54F),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.all(
                  Radius.elliptical(110, 20),
                ),
                border: Border.all(
                  color: const Color(0xFFFFD54F),
                  width: 1.5,
                ),
              ),
            ),
          ),

          // 3D Phone Body
          Positioned(
            bottom: 22,
            child: Container(
              width: 68,
              height: 112,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Speaker notch
                  Container(
                    width: 14,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  // Home indicator bar
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sparkle Stars (* ✨ *)
          const Positioned(
            top: 28,
            left: 20,
            child: Icon(
              Icons.star_rounded,
              color: Color(0xFFF59E0B),
              size: 16,
            ),
          ),

          const Positioned(
            top: 50,
            right: 22,
            child: Icon(
              Icons.star_rounded,
              color: Color(0xFFF59E0B),
              size: 14,
            ),
          ),

          const Positioned(
            bottom: 40,
            left: 26,
            child: Icon(
              Icons.star_rounded,
              color: Color(0xFFF59E0B),
              size: 10,
            ),
          ),

          const Positioned(
            top: 14,
            right: 48,
            child: Icon(
              Icons.star_rounded,
              color: Color(0xFFFFD54F),
              size: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Soft Dot Grid Graphic Accent
  Widget _buildDotGrid() {
    return Column(
      children: List.generate(
        4,
        (r) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: List.generate(
              3,
              (c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A000).withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
