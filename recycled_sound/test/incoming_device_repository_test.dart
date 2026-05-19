import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recycled_sound/features/devices/data/incoming_device_repository.dart';
import 'package:recycled_sound/features/devices/data/models/device.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;
  late MockFirebaseAuth auth;
  late IncomingDeviceRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-abc', email: 'a@b.com'),
    );
    repo = IncomingDeviceRepository(
      firestore: firestore,
      storage: storage,
      auth: auth,
    );
  });

  group('createIncoming', () {
    test('writes doc with brand+model and stamps createdBy', () async {
      const device = Device(id: '', brand: 'Phonak', model: 'P90');
      final id = await repo.createIncoming(device);

      expect(id, isNotEmpty);
      final snap = await firestore.collection('incoming').doc(id).get();
      expect(snap.exists, isTrue);
      final data = snap.data()!;
      expect(data['brand'], 'Phonak');
      expect(data['model'], 'P90');
      expect(data['createdBy'], 'user-abc');
    });

    test('throws StateError when no signed-in user', () async {
      final unauth = IncomingDeviceRepository(
        firestore: firestore,
        storage: storage,
        auth: MockFirebaseAuth(signedIn: false),
      );
      expect(
        () => unauth.createIncoming(const Device(id: '', brand: 'X', model: 'Y')),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('watchIncoming', () {
    test('emits ordered list newest first', () async {
      // Seed two docs with different createdAt values
      await firestore.collection('incoming').doc('old').set({
        'brand': 'A',
        'model': '1',
        'createdAt': DateTime.utc(2026, 1, 1),
      });
      await firestore.collection('incoming').doc('new').set({
        'brand': 'B',
        'model': '2',
        'createdAt': DateTime.utc(2026, 6, 1),
      });

      final list = await repo.watchIncoming().first;
      expect(list, hasLength(2));
      expect(list.first.id, 'new');
      expect(list.last.id, 'old');
    });

    test('emits empty list when collection is empty', () async {
      final list = await repo.watchIncoming().first;
      expect(list, isEmpty);
    });
  });

  group('watchIncomingById', () {
    test('emits Device when doc exists', () async {
      await firestore.collection('incoming').doc('xyz').set({
        'brand': 'Widex',
        'model': 'Moment 440',
      });
      final d = await repo.watchIncomingById('xyz').first;
      expect(d, isNotNull);
      expect(d!.brand, 'Widex');
      expect(d.model, 'Moment 440');
    });

    test('emits null when doc is missing', () async {
      final d = await repo.watchIncomingById('does-not-exist').first;
      expect(d, isNull);
    });
  });
}
