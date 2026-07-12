import 'package:flutter_contacts/flutter_contacts.dart';

import '../../domain/services/contacts_service.dart';

/// [ContactsService] backed by flutter_contacts (Android/iOS address book).
class DeviceContactsService implements ContactsService {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> hasPermission() async {
    try {
      // requestPermission(readonly:true) returns current grant state without
      // prompting again once decided; we guard for platform exceptions.
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<DeviceContact>> getAll() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) return const [];
      final contacts =
          await FlutterContacts.getContacts(withProperties: true);
      final result = contacts
          .map(_map)
          .where((c) => c.phones.isNotEmpty)
          .toList()
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return result;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<DeviceContact?> pickOne() async {
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return null;
      // openExternalPick returns a lightweight contact; fetch full props.
      final full = await FlutterContacts.getContact(contact.id) ?? contact;
      return _map(full);
    } catch (_) {
      return null;
    }
  }

  DeviceContact _map(Contact c) => DeviceContact(
        id: c.id,
        name: c.displayName,
        phones: c.phones
            .map((p) => p.number.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList(),
        emails: c.emails
            .map((e) => e.address.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList(),
      );
}
