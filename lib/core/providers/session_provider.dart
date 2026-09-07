import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionState {
  final double? loginLatitude;
  final double? loginLongitude;
  final DateTime? loginTime;

  SessionState({this.loginLatitude, this.loginLongitude, this.loginTime});

  SessionState copyWith(
      {double? loginLatitude, double? loginLongitude, DateTime? loginTime}) {
    return SessionState(
      loginLatitude: loginLatitude ?? this.loginLatitude,
      loginLongitude: loginLongitude ?? this.loginLongitude,
      loginTime: loginTime ?? this.loginTime,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState());

  void setLoginLocation(double lat, double lng) {
    state = state.copyWith(
        loginLatitude: lat, loginLongitude: lng, loginTime: DateTime.now());
  }

  void clear() {
    state = SessionState();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
