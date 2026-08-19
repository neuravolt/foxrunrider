import 'package:ride_on/core/services/data_store.dart';

import 'package:ride_on/core/extensions/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ride_on/core/utils/translate.dart';

import '../../presentation/cubits/localizations_cubit.dart';
import '../utils/common_widget.dart';
import '../utils/theme/project_color.dart';
import '../utils/theme/theme_style.dart';

class ChangeLanguage extends StatefulWidget {
  const ChangeLanguage({super.key});

  @override
  State<ChangeLanguage> createState() => _ChangeLanguageState();
}

class _ChangeLanguageState extends State<ChangeLanguage> {
  int _value = 0;

  @override
  void initState() {
    super.initState();
    final savedCode = lanBox.get('lCode') ?? 'en';
    final savedVal = lanBox.get('lanValue');
    if (savedVal != null && savedVal is int && savedVal >= 0 && savedVal < locale.length) {
      _value = savedVal;
    } else {
      final idx = locale.indexWhere((element) => element['locale'] == savedCode);
      _value = idx >= 0 ? idx : 0;
    }
  }

  void _selectLanguage(int index) {
    final selectedLocale = locale[index]['locale'];
    context.read<LanguageCubit>().changeLanguage(selectedLocale);
    try {
      context.read<LCodeCubit>().changeLanguage(selectedLocale);
    } catch (_) {}

    lanBox.put('lCode', selectedLocale);
    lanBox.put('lanValue', index);

    setState(() {
      _value = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: notifires.getbgcolor,
      appBar: CustomAppBars(
        title: "Language".translate(context),
        backgroundColor: notifires.getbgcolor,
        centerTitle: false,
        iconColor: notifires.getwhiteblackColor,
        titleColor: notifires.getwhiteblackColor,
      ),
      body: BlocBuilder<LanguageCubit, LanguageState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: SizedBox(
              height: double.maxFinite,
              width: double.maxFinite,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: locale.length,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () => _selectLanguage(index),
                          child: languageWidget(
                            name: locale[index]['name'],
                            value: index,
                            radio: Radio<int>(
                              value: index,
                              groupValue: _value,
                              activeColor: themeColor,
                              onChanged: (val) {
                                if (val != null) {
                                  _selectLanguage(val);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget languageWidget(
    {String? name, int? value, void Function(int?)? onChanged, radio}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              name ?? "",
              style: appBarNormal.copyWith(
                  fontSize: 16, color: notifires.getwhiteblackColor),
            ),
          ),
          const Spacer(),
          radio,
          const SizedBox(
            width: 10,
          ),
        ],
      ),
    ),
  );
}
