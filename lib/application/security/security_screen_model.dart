class SecurityScreenModel {
  final String title;
  final int activeRules;
  final int blockedActions;
  final int pendingApprovals;

  const SecurityScreenModel({
    required this.title,
    required this.activeRules,
    required this.blockedActions,
    required this.pendingApprovals,
  });
}
