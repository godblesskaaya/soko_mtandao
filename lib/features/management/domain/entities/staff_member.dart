class StaffMember {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // e.g., owner, manager, front_desk, maintenance
  final bool isActive;

  StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isActive = true,
  });
}
