import 'package:freezed_annotation/freezed_annotation.dart';

import '../constants/app_constants.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String email,
    required String displayName,
    required int totalXp,
    required int currentLevel,
    required String levelTitle,
    required int streakDays,
    required int longestStreak,
    required int totalSessions,
    required int totalFocusMinutes,
    required DateTime joinedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

  const UserProfile._();

  String get computedLevelTitle {
    if (totalXp >= AppXP.level4Min) return AppStrings.level4;
    if (totalXp >= AppXP.level3Min) return AppStrings.level3;
    if (totalXp >= AppXP.level2Min) return AppStrings.level2;
    return AppStrings.level1;
  }
}
