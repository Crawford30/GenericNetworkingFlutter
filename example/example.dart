// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:generic_networking/generic_networking.dart';

// ---- Models -----------------------------------------------------------------

class Policy implements JsonSerializable {
  Policy({required this.id, required this.name});

  factory Policy.fromJson(Map<String, dynamic> json) =>
      Policy(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

// ---- Session (back it with your auth state / secure storage) -----------------

class AppSession extends NetworkSession {
  String? token;

  @override
  String? get accessToken => token;
}

// ---- Setup (once, e.g. in main or your DI container) -------------------------

final session = AppSession();

final NetworkingClient client = DioNetworkingClient(
  config: const NetworkConfig(
    baseUrl: 'https://api.example.com/v1/',
    applicationPlatform: 'android',
    applicationVersion: '1.0.0',
  ),
  session: session,
  unauthorizedHandler: CallbackUnauthorizedHandler((_) {
    session.token = null; // logout(), navigate to login, etc.
  }),
);

// ---- Repository -------------------------------------------------------------

class PolicyRepository {
  PolicyRepository(this.client);

  final NetworkingClient client;

  Future<List<Policy>> policies() =>
      client.get('policies/', Deserializer.list(Policy.fromJson));

  Future<Policy> policy(int id) =>
      client.get('policies/$id/', Deserializer.object(Policy.fromJson));

  Future<Policy> create(Policy policy) =>
      client.post('policies/', Deserializer.object(Policy.fromJson), body: policy);

  Future<Policy> rename(int id, String name) =>
      client.patch('policies/$id/', Deserializer.object(Policy.fromJson), body: {'name': name});

  Future<void> remove(int id) => client.delete('policies/$id/');

  Future<void> uploadId(String path, {void Function(double)? onProgress}) =>
      client.uploadDocument(
        'documents/',
        Deserializer.noBody,
        files: [UploadableFile.fromPath(path, fieldName: 'document')],
        fields: {'type': 'national_id'},
        onSendProgress: (sent, total) => onProgress?.call(total > 0 ? sent / total : 0),
      );

  Future<DownloadedFile> statement(int id, String directory) =>
      client.downloadDocument('policies/$id/statement/', saveDirectory: directory);
}

// ---- Widget using a controller ---------------------------------------------

class PolicyListPage extends StatefulWidget {
  const PolicyListPage({super.key});

  @override
  State<PolicyListPage> createState() => _PolicyListPageState();
}

class _PolicyListPageState extends State<PolicyListPage> {
  late final policies =
      FetchController(client, 'policies/', Deserializer.list(Policy.fromJson))..fetch();

  @override
  void dispose() {
    policies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: policies,
      builder: (context, _) {
        if (policies.loading) return const Center(child: CircularProgressIndicator());
        if (policies.error != null) return Center(child: Text(policies.error!.message));
        return RefreshIndicator(
          onRefresh: policies.refresh,
          child: ListView(
            children: [for (final p in policies.data ?? <Policy>[]) ListTile(title: Text(p.name))],
          ),
        );
      },
    );
  }
}

void main() {
  runApp(MaterialApp(
    builder: (context, child) => OfflineBanner(message: 'MyApp is offline', child: child!),
    home: const Scaffold(body: PolicyListPage()),
  ));
}
