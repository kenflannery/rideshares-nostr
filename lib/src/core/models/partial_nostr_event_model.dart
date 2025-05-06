class PartialNostrEvent {
  int kind;
  String content;
  List<List<String>> tags;
  DateTime? createdAt;

  PartialNostrEvent({
    required this.kind,
    required this.content,
    this.tags = const [],
    this.createdAt,
  });
}