import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class PrivacyPolicySheet extends StatelessWidget {
  const PrivacyPolicySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/privacy_policy.md'),
      builder: (context, snapshot) {
        final text = snapshot.data;
        final body = text == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  text,
                  style: AppTextStyles.bodyMedium,
                ),
              );

        return SafeArea(
          child: Container(
            color: AppColors.card,
            constraints: const BoxConstraints(maxHeight: 560),
            child: body,
          ),
        );
      },
    );
  }
}
