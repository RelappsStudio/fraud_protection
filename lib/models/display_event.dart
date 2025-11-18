enum DisplayEventAction { added, removed, initial }

class DisplayEvent {
  final DisplayEventAction action;
  final int publicDisplayCount;
  final String message;

  DisplayEvent(
      {required this.action,
      required this.publicDisplayCount,
      required this.message});
}
