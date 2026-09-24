class LeadContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String company;
  final String title;
  final double openDealValue;
  final String lastContacted;
  final String crmAccountId;

  const LeadContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.company,
    required this.title,
    required this.openDealValue,
    required this.lastContacted,
    required this.crmAccountId,
  });
}
