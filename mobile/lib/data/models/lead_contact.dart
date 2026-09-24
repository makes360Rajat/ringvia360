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

  factory LeadContact.fromJson(Map<String, dynamic> json) {
    return LeadContact(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      company: json['company'] as String? ?? '',
      title: json['title'] as String? ?? 'Executive',
      openDealValue: (json['openDealValue'] as num?)?.toDouble() ?? 0.0,
      lastContacted: json['lastContacted'] as String? ?? 'Recent',
      crmAccountId: json['crmAccountId'] as String? ?? 'RV360-ACC-01',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'company': company,
    'title': title,
    'openDealValue': openDealValue,
    'lastContacted': lastContacted,
    'crmAccountId': crmAccountId,
  };
}
