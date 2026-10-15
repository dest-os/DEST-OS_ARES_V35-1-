class SecurityScreenModel {
  const SecurityScreenModel({
    this.title = 'Guvenlik Merkezi',
    this.activeRules = 0,
    this.blockedActions = 0,
    this.pendingApprovals = 0,
  });

  final String title;
  final int activeRules;
  final int blockedActions;
  final int pendingApprovals;
}
