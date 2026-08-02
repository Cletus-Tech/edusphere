enum InstitutionType {
  university,
  polytechnic,
  collegeOfEducation,
  secondarySchool,
  trainingCenter;

  String get id => name;

  static InstitutionType fromId(String id) => InstitutionType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => InstitutionType.university,
      );

  String get label => switch (this) {
        InstitutionType.university => 'University',
        InstitutionType.polytechnic => 'Polytechnic',
        InstitutionType.collegeOfEducation => 'College of Education',
        InstitutionType.secondarySchool => 'Secondary School',
        InstitutionType.trainingCenter => 'Training Center',
      };
}
