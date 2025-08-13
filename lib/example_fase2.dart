import 'dart:math'; // Usado para formatar o tamanho do arquivo
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =======================================================================
// 1. CAMADA DE MODELO (MODEL) - SEM MUDANÇAS NESTA FASE
// =======================================================================

enum UploadStatus { waiting, uploading, completed, error }

@immutable
class UploadTask {
  const UploadTask({
    required this.id,
    required this.file,
    this.progress = 0.0,
    this.status = UploadStatus.waiting,
  });

  final String id;
  final PlatformFile file;
  final double progress;
  final UploadStatus status;

  UploadTask copyWith({double? progress, UploadStatus? status}) {
    return UploadTask(
      id: id,
      file: file,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}

// =======================================================================
// 2. CAMADA DE ESTADO (STATE MANAGEMENT) - ATUALIZADA
// =======================================================================

class UploadNotifier extends StateNotifier<List<UploadTask>> {
  UploadNotifier() : super([]);

  /// Adiciona uma lista de arquivos selecionados como novas tarefas de upload.
  void addFiles(List<PlatformFile> files) {
    // Cria uma lista de novas tarefas a partir dos arquivos selecionados
    final newTasks =
        files.map((file) {
          // Gera um ID único simples para a tarefa
          final id = '${DateTime.now().millisecondsSinceEpoch}-${file.name}';
          return UploadTask(id: id, file: file);
        }).toList();

    // Atualiza o estado, adicionando as novas tarefas à lista existente.
    // A sintaxe com '...' (spread operator) cria uma nova lista, mantendo a imutabilidade.
    state = [...state, ...newTasks];
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, List<UploadTask>>(
  (ref) => UploadNotifier(),
);

// =======================================================================
// 3. CAMADA DE UI (INTERFACE DO USUÁRIO) - ATUALIZADA
// =======================================================================

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Projeto de Upload',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomePage(),
    );
  }
}

/// Convertemos HomePage para um `ConsumerWidget` para que ele possa "ouvir" os providers.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. "Observamos" o estado do nosso provider. Sempre que a lista de tarefas
    // mudar, este widget será reconstruído para exibir a lista atualizada.
    final List<UploadTask> tasks = ref.watch(uploadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload de Arquivos - Fase 2')),
      // O corpo agora exibe a lista de tarefas ou uma mensagem se estiver vazia.
      body:
          tasks.isEmpty
              ? const Center(
                child: Text(
                  'Nenhum arquivo selecionado.\nClique em "+" para adicionar.',
                ),
              )
              : ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(task.file.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // A barra de progresso, por enquanto, ficará estática em 0%.
                        LinearProgressIndicator(value: task.progress),
                        const SizedBox(height: 4),
                        Text('Tamanho: ${_formatBytes(task.file.size)}'),
                      ],
                    ),
                    trailing: Text(
                      '${(task.progress * 100).toStringAsFixed(0)}%',
                    ),
                  );
                },
              ),
      // Botão flutuante para adicionar novos arquivos.
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 2. Usamos `ref.read` dentro de callbacks como o onPressed.
          // Ele é usado para chamar uma função no nosso Notifier.
          final notifier = ref.read(uploadProvider.notifier);

          // 3. Usamos o file_picker para selecionar múltiplos arquivos de mídia.
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: true, // Permite selecionar vários arquivos
            type: FileType.media, // Foca em imagens e vídeos
          );

          // 4. Se o usuário selecionou arquivos, os adicionamos ao nosso estado.
          if (result != null) {
            notifier.addFiles(result.files);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Função auxiliar para formatar o tamanho do arquivo em uma string legível.
  String _formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
