import 'package:flutter_test/flutter_test.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_additional_data.dart';
import 'package:protocolflow/models/protocol_publication.dart';
import 'package:protocolflow/models/protocol_step.dart';
import 'package:protocolflow/models/published_protocol_manifest.dart';
import 'package:protocolflow/models/published_protocol_package.dart';

void main() {
  Protocol sourceProtocol() => Protocol(
    id: 'private-id',
    title: 'Cell staining',
    objective: 'Stain cells',
    description: 'Private working copy',
    ownerId: 'google-user-id',
    projectId: 'private-project',
    createdByName: 'Dr. Aviv',
    driveFileId: 'private-drive-id',
    syncStatus: ProtocolSyncStatus.synced,
    files: const ['C:/private/result.png'],
    steps: [
      ProtocolStep(
        id: 'step-1',
        title: 'Wash',
        instructions: 'Wash the cells.',
        actionItems: const [],
        materials: const [],
      ),
    ],
    additionalData: [
      ProtocolAdditionalData(
        id: 'data-1',
        title: 'Reference',
        link: 'https://example.com/reference',
        photoPaths: const ['C:/private/microscope.png'],
      ),
    ],
    publication: ProtocolPublication(
      publicationId: 'old-publication',
      driveFileId: 'old-public-file',
      version: 1,
      publishedAt: DateTime(2026, 8, 1),
      shareUri: 'https://example.com',
      contentHash: 'old-hash',
      ownerGoogleUserId: 'google-user-id',
      anonymous: false,
      status: ProtocolPublicationStatus.published,
    ),
  );

  test('published package strips private and local-only data', () {
    final package = PublishedProtocolPackage.create(
      source: sourceProtocol(),
      publicationId: 'publication-1',
      version: 2,
      publishedAt: DateTime.utc(2026, 8, 5),
      authorName: 'Dr. Aviv',
    );

    expect(package.protocol.id, 'publication-1');
    expect(package.protocol.ownerId, isNull);
    expect(package.protocol.projectId, isNull);
    expect(package.protocol.driveFileId, isNull);
    expect(package.protocol.files, isEmpty);
    expect(package.protocol.additionalData.single.photoPaths, isEmpty);
    expect(package.protocol.publication, isNull);
    expect(package.protocol.createdByName, 'Dr. Aviv');
  });

  test('published package round-trips and rejects changed content', () {
    final package = PublishedProtocolPackage.create(
      source: sourceProtocol(),
      publicationId: 'publication-1',
      version: 1,
      publishedAt: DateTime.utc(2026, 8, 5),
      authorName: null,
    );
    final json = package.toJson();

    final restored = PublishedProtocolPackage.fromJson(json);
    expect(restored.protocol.title, 'Cell staining');
    expect(restored.authorName, isNull);

    final tampered = Map<String, dynamic>.from(json);
    final protocol = Map<String, dynamic>.from(tampered['protocol'] as Map);
    protocol['title'] = 'Changed after publication';
    tampered['protocol'] = protocol;
    expect(
      () => PublishedProtocolPackage.fromJson(tampered),
      throwsFormatException,
    );
  });

  test('imported protocol receives a local identity and provenance', () {
    final package = PublishedProtocolPackage.create(
      source: sourceProtocol(),
      publicationId: 'publication-1',
      version: 3,
      publishedAt: DateTime.utc(2026, 8, 5),
      authorName: 'Dr. Aviv',
    );

    final imported = package.toImportedProtocol(
      shareUri: 'https://aviv7001.github.io/protocolflow/?import=file-1',
      localProtocolId: 'local-copy',
      ownerId: 'recipient',
    );

    expect(imported.id, 'local-copy');
    expect(imported.ownerId, 'recipient');
    expect(imported.publication, isNull);
    expect(imported.importSource?.publicationId, 'publication-1');
    expect(imported.importSource?.version, 3);
  });

  test('publication and import metadata survive protocol serialization', () {
    final source = sourceProtocol().copyWith(
      importSource: ProtocolImportSource(
        publicationId: 'source-publication',
        version: 2,
        importedAt: DateTime.utc(2026, 8, 5),
        shareUri: 'https://example.com/import',
        authorName: 'Researcher',
      ),
    );

    final restored = Protocol.fromJson(source.toJson());
    expect(restored.publication?.driveFileId, 'old-public-file');
    expect(restored.publication?.status, ProtocolPublicationStatus.published);
    expect(restored.importSource?.publicationId, 'source-publication');
  });

  test('publication manifest preserves immutable version history', () {
    final first = PublishedProtocolVersion(
      version: 1,
      publishedAt: DateTime.utc(2026, 8, 1),
      authorName: 'Dr. Aviv',
      fileId: 'version-file-1',
      contentHash: 'hash-1',
    );
    final manifest =
        PublishedProtocolManifest(
          publicationId: 'publication-1',
          title: 'Cell staining',
          latestVersion: 1,
          updatedAt: first.publishedAt,
          versions: [first],
        ).append(
          title: 'Cell staining updated',
          entry: PublishedProtocolVersion(
            version: 2,
            publishedAt: DateTime.utc(2026, 8, 5),
            fileId: 'version-file-2',
            resourceKey: 'resource-2',
            contentHash: 'hash-2',
          ),
        );

    final restored = PublishedProtocolManifest.fromJson(manifest.toJson());

    expect(restored.latestVersion, 2);
    expect(restored.title, 'Cell staining updated');
    expect(restored.versions.map((entry) => entry.version), [1, 2]);
    expect(restored.version(1).fileId, 'version-file-1');
    expect(restored.version(2).resourceKey, 'resource-2');
  });

  test('publication manifest rejects duplicate and inconsistent versions', () {
    final entry = PublishedProtocolVersion(
      version: 1,
      publishedAt: DateTime.utc(2026, 8, 1),
      fileId: 'version-file-1',
      contentHash: 'hash-1',
    );
    final json = PublishedProtocolManifest(
      publicationId: 'publication-1',
      title: 'Cell staining',
      latestVersion: 1,
      updatedAt: entry.publishedAt,
      versions: [entry],
    ).toJson();
    json['versions'] = [entry.toJson(), entry.toJson()];

    expect(
      () => PublishedProtocolManifest.fromJson(json),
      throwsFormatException,
    );
  });
}
