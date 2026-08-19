import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/presentation/screens/account/static_screen.dart';
import 'package:ride_on/presentation/screens/home/item_home_screen.dart';
import 'package:ride_on/presentation/screens/onboarding/language_select_screen.dart';
import 'package:ride_on/presentation/screens/onboarding/on_boarding_screen.dart';
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

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  TextEditingController textEditingLoginControllerPhoneNumber =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String defaultCountry = "IN";
  final ValueNotifier<bool> isTermsAcceptedNotifier = ValueNotifier<bool>(false);
  final FocusNode phoneFocusNode = FocusNode();
  final ValueNotifier<bool> isFieldFocusedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    context.read<SetCountryCubit>().reset();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    isNumeric = false;
    phoneFocusNode.addListener(_onFocusChange);
  }

  bool _wasKeyboardOpen = false;

  void _onFocusChange() {
    isFieldFocusedNotifier.value = phoneFocusNode.hasFocus;
    if (!phoneFocusNode.hasFocus) {
      _wasKeyboardOpen = false;
    }
  }

  @override
  void didChangeMetrics() {
    final isKeyboardOpen = View.of(context).viewInsets.bottom > 0;
    if (isKeyboardOpen) {
      _wasKeyboardOpen = true;
    } else if (_wasKeyboardOpen) {
      _wasKeyboardOpen = false;
      if (phoneFocusNode.hasFocus) {
        phoneFocusNode.unfocus();
      }
      isFieldFocusedNotifier.value = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    phoneFocusNode.removeListener(_onFocusChange);
    phoneFocusNode.dispose();
    textEditingLoginControllerPhoneNumber.dispose();
    isTermsAcceptedNotifier.dispose();
    isFieldFocusedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const Onboardingscreen(),
          ),
          (route) => false,
        );
      },
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
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
              // Background Gradient & Accents (Cached via RepaintBoundary)
              Positioned.fill(
                child: RepaintBoundary(
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
              ),

              // Top Left Soft Glow & Dot Grid Accent
              Positioned(
                top: -30,
                left: -30,
                child: RepaintBoundary(
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
              ),

              const Positioned(
                top: 100,
                left: 20,
                child: RepaintBoundary(
                  child: DotGridWidget(),
                ),
              ),

              // Bottom Left Leaf Flourish & Dot Grid Accent
              Positioned(
                bottom: 10,
                left: 10,
                child: RepaintBoundary(
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
                        const DotGridWidget(),
                      ],
                    ),
                  ),
                ),
              ),

              // Main Screen Scroll Content
              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
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
                                  // Back Navigation Button & Logo
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (token.isNotEmpty &&
                                              Navigator.canPop(context)) {
                                            Navigator.pop(context);
                                          } else {
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const Onboardingscreen(),
                                              ),
                                              (route) => false,
                                            );
                                          }
                                        },
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(14),
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
                                          child: const Icon(
                                            Icons.arrow_back_rounded,
                                            size: 20,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ),
                                       const SizedBox(width: 8),
                                       // Foxrun Logo Icon
                                       ClipRRect(
                                         borderRadius:
                                             BorderRadius.circular(8),
                                         child: Image.asset(
                                           'assets/images/appIcon.png',
                                           height: 32,
                                           width: 32,
                                           fit: BoxFit.contain,
                                         ),
                                       ),
                                       const SizedBox(width: 6),
                                       // Foxrun Text & Small TM Sign
                                       Text.rich(
                                         TextSpan(
                                           text: "foxrun",
                                           style: heading1(context).copyWith(
                                             color: const Color(0xFF1A1A1A),
                                             fontSize: 24,
                                             fontWeight: FontWeight.w900,
                                             letterSpacing: -0.6,
                                           ),
                                           children: const [
                                             WidgetSpan(
                                               alignment:
                                                   PlaceholderAlignment.top,
                                               child: Padding(
                                                 padding: EdgeInsets.only(
                                                     left: 2, top: 2),
                                                 child: Text(
                                                   "TM",
                                                   style: TextStyle(
                                                     fontSize: 9,
                                                     fontWeight:
                                                         FontWeight.w800,
                                                     color: Color(0xFFD98A00),
                                                   ),
                                                 ),
                                               ),
                                             ),
                                           ],
                                         ),
                                       ),
                                    ],
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

                              // Center Hero Artwork (Collapses smoothly when field is focused without triggering full screen rebuilds)
                              ValueListenableBuilder<bool>(
                                valueListenable: isFieldFocusedNotifier,
                                builder: (context, isFocused, child) {
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.fastOutSlowIn,
                                    height: isFocused ? 0 : 145,
                                    child: SingleChildScrollView(
                                      physics: const NeverScrollableScrollPhysics(),
                                      child: child,
                                    ),
                                  );
                                },
                                child: const RepaintBoundary(
                                  child: PhoneHeroGraphicWidget(),
                                ),
                              ),

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
                                      focusNode: phoneFocusNode,
                                      onTap: () {
                                        isNumeric = true;
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
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Terms & Conditions Checkbox Row Card
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFF2EAD6),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isTermsAcceptedNotifier,
                                      builder: (context, isAccepted, child) {
                                        return Checkbox(
                                          value: isAccepted,
                                          activeColor: const Color(0xFFF59E0B),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          onChanged: (val) {
                                            isTermsAcceptedNotifier.value =
                                                val ?? false;
                                          },
                                        );
                                      },
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          isTermsAcceptedNotifier.value =
                                              !isTermsAcceptedNotifier.value;
                                        },
                                        child: RichText(
                                          text: TextSpan(
                                            text:
                                                "I confirm that I am 18 years of age and agree to the "
                                                    .translate(context),
                                            style: regular2(context).copyWith(
                                              color: const Color(0xFF718096),
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                            children: [
                                              WidgetSpan(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    showModalBottomSheet(
                                                      useRootNavigator: true,
                                                      backgroundColor:
                                                          notifires.getbgcolor,
                                                      isScrollControlled: true,
                                                      useSafeArea: true,
                                                      context: context,
                                                      builder:
                                                          (BuildContext context) {
                                                        return const StaticScreen(
                                                          data:
                                                              "Terms & Conditions",
                                                        );
                                                      },
                                                    );
                                                  },
                                                  child: Text(
                                                    "Terms & Conditions".translate(context),
                                                    style: regular2(context).copyWith(
                                                      color: const Color(0xFFD98A00),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              TextSpan(
                                                text: " and ".translate(context),
                                              ),
                                              WidgetSpan(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    showModalBottomSheet(
                                                      useRootNavigator: true,
                                                      backgroundColor:
                                                          notifires.getbgcolor,
                                                      isScrollControlled: true,
                                                      useSafeArea: true,
                                                      context: context,
                                                      builder:
                                                          (BuildContext context) {
                                                        return const StaticScreen(
                                                          data: "Privacy Policy",
                                                        );
                                                      },
                                                    );
                                                  },
                                                  child: Text(
                                                    "Privacy Policy".translate(context),
                                                    style: regular2(context).copyWith(
                                                      color: const Color(0xFFD98A00),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
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

                              const SizedBox(height: 28),

                              // Next Submit Button
                              ValueListenableBuilder<bool>(
                                valueListenable: isTermsAcceptedNotifier,
                                builder: (context, isAccepted, child) {
                                  return ValueListenableBuilder<TextEditingValue>(
                                    valueListenable:
                                        textEditingLoginControllerPhoneNumber,
                                    builder: (context, value, child) {
                                      final isPhoneValid =
                                          value.text.trim().length >= 7;
                                      final isButtonEnabled =
                                          isAccepted && isPhoneValid;

                                      return SizedBox(
                                        width: double.infinity,
                                        height: 54,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isButtonEnabled
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFFEEF2F6),
                                            foregroundColor: isButtonEnabled
                                                ? Colors.white
                                                : const Color(0xFFA0AEC0),
                                            elevation: isButtonEnabled ? 4 : 0,
                                            shadowColor: const Color(0xFFF5A623)
                                                .withValues(alpha: 0.3),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          onPressed: isButtonEnabled
                                              ? () {
                                                  if (_formKey.currentState!
                                                      .validate()) {
                                                    String rawPhone =
                                                        textEditingLoginControllerPhoneNumber
                                                            .text
                                                            .trim();
                                                    String cleanPhone = rawPhone
                                                        .replaceFirst(
                                                            RegExp(r'^0+'), '');

                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    context
                                                        .read<AuthLoginCubit>()
                                                        .login(
                                                          context: context,
                                                          phoneNumber: cleanPhone,
                                                          phoneCountry: context
                                                              .read<
                                                                  SetCountryCubit>()
                                                              .state
                                                              .dialCode,
                                                        );
                                                  }
                                                }
                                              : null,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Next".translate(context),
                                                style: regular2(context).copyWith(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isButtonEnabled
                                                      ? Colors.white
                                                      : const Color(0xFFA0AEC0),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 20,
                                                color: isButtonEnabled
                                                    ? Colors.white
                                                    : const Color(0xFFA0AEC0),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

// 3D Phone Platform Hero Widget with Sparkles
class PhoneHeroGraphicWidget extends StatelessWidget {
  const PhoneHeroGraphicWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
}

// Soft Dot Grid Graphic Accent
class DotGridWidget extends StatelessWidget {
  const DotGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
