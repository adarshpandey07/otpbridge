import 'package:equatable/equatable.dart';

/// A device contact reduced to what OTPBridge needs. Keeps the flutter_contacts
/// plugin types out of the UI/domain layers.
class DeviceContact extends Equatable {
  const DeviceContact({
    required this.id,
    required this.name,
    required this.phones,
    this.emails = const [],
  });

  final String id;
  final String name;
  final List<String> phones;
  final List<String> emails;

  String? get primaryPhone => phones.isEmpty ? null : phones.first;
  String? get primaryEmail => emails.isEmpty ? null : emails.first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  List<Object?> get props => [id, name, phones, emails];
}

/// Access to the device address book.
abstract interface class ContactsService {
  Future<bool> isSupported();
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// All contacts that have at least one phone number, name-sorted.
  Future<List<DeviceContact>> getAll();

  /// Open the OS native single-contact picker. Returns null if cancelled or
  /// unsupported.
  Future<DeviceContact?> pickOne();
}

/// Fallback used on platforms without contacts access and in tests.
class NoopContactsService implements ContactsService {
  @override
  Future<bool> isSupported() async => false;
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<List<DeviceContact>> getAll() async => const [];
  @override
  Future<DeviceContact?> pickOne() async => null;
}
