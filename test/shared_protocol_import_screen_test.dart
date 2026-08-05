import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/published_protocol_manifest.dart';
import 'package:protocolflow/models/published_protocol_package.dart';
import 'package:protocolflow/screens/shared_protocol_import_screen.dart';
import 'package:protocolflow/services/protocol_publication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shared protocol preview can select a historical version', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final first = _package(version: 1, title: 'Original protocol');
    final second = _package(version: 2, title: 'Updated protocol');
    final service = _FakePublicationService(first: first, second: second);

    await tester.pumpWidget(
      MaterialApp(
        home: SharedProtocolImportScreen(
          shareUri: 'https://example.com/?import=manifest-file',
          publicationService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Updated protocol'), findsOneWidget);
    expect(
      find.byKey(const Key('shared-protocol-version-selector')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('shared-protocol-version-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Version 1 - 2026-08-01').last);
    await tester.pumpAndSettle();

    expect(service.requestedVersions, [null, 1]);
    expect(find.text('Original protocol'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);
  });
}

PublishedProtocolPackage _package({
  required int version,
  required String title,
}) {
  return PublishedProtocolPackage.create(
    source: Protocol(
      id: 'private-$version',
      title: title,
      objective: 'Objective $version',
      description: 'Description $version',
      steps: const [],
    ),
    publicationId: 'publication-1',
    version: version,
    publishedAt: DateTime.utc(2026, 8, version),
    authorName: 'Author',
  );
}

class _FakePublicationService extends ProtocolPublicationService {
  _FakePublicationService({required this.first, required this.second})
    : super(headersProvider: (_) async => null);

  final PublishedProtocolPackage first;
  final PublishedProtocolPackage second;
  final List<int?> requestedVersions = [];

  late final PublishedProtocolManifest manifest = PublishedProtocolManifest(
    publicationId: 'publication-1',
    title: second.protocol.title,
    latestVersion: 2,
    updatedAt: second.publishedAt,
    versions: [
      PublishedProtocolVersion(
        version: 1,
        publishedAt: first.publishedAt,
        authorName: first.authorName,
        fileId: 'version-1',
        contentHash: first.contentHash,
      ),
      PublishedProtocolVersion(
        version: 2,
        publishedAt: second.publishedAt,
        authorName: second.authorName,
        fileId: 'version-2',
        contentHash: second.contentHash,
      ),
    ],
  );

  @override
  Future<SharedProtocolDownload> downloadSharedPublication(
    String shareUri, {
    int? version,
  }) async {
    requestedVersions.add(version);
    return SharedProtocolDownload(
      manifest: manifest,
      package: version == 1 ? first : second,
      isLegacyPublication: false,
    );
  }
}
