enum CallState { ringing, active, idle, unknown }

class CallEvent {
  final String event;
  final CallState callState;

  CallEvent({required this.event, required this.callState});
}
