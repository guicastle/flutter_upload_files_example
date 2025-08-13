import 'dart:async'; // Para usar o Timer
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =======================================================================
// 1. CAMADA DE MODELO (MODEL) - SEM MUDANÇAS
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
  // O Notifier agora recebe uma referência 'ref' para poder ler outros providers.
  UploadNotifier(this.ref) : super([]);

  final Ref ref;

  /// Adiciona arquivos E inicia o processo de upload para eles.
  void addFiles(List<PlatformFile> files) {
    final newTasks =
        files.map((file) {
          final id = '${DateTime.now().millisecondsSinceEpoch}-${file.name}';
          return UploadTask(id: id, file: file);
        }).toList();

    state = [...state, ...newTasks];

    // Para cada nova tarefa, iniciamos o upload através do nosso serviço.
    for (final task in newTasks) {
      _startUpload(task.id);
    }
  }

  /// Inicia o upload para um ID de tarefa específico.
  void _startUpload(String taskId) {
    // Lemos o nosso UploadService usando a referência 'ref'.
    final uploadService = ref.read(uploadServiceProvider);

    // Chamamos o serviço, passando o ID e um callback para que o serviço
    // possa nos notificar sobre o progresso.
    uploadService.startUpload(taskId, (progress) {
      _updateTaskProgress(taskId, progress);
    });
  }

  /// Atualiza o progresso e o status de uma tarefa.
  void _updateTaskProgress(String taskId, double progress) {
    // Encontra a tarefa a ser atualizada na lista de estado.
    final taskIndex = state.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return; // Tarefa não encontrada

    final taskToUpdate = state[taskIndex];

    // Determina o novo status com base no progresso.
    final newStatus =
        progress == 1.0 ? UploadStatus.completed : UploadStatus.uploading;

    // Cria uma cópia da tarefa com os valores atualizados.
    final updatedTask = taskToUpdate.copyWith(
      progress: progress,
      status: newStatus,
    );

    // Cria uma nova lista de estado com a tarefa atualizada.
    final newState = List<UploadTask>.from(state);
    newState[taskIndex] = updatedTask;

    // Atualiza o estado para notificar a UI.
    state = newState;
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, List<UploadTask>>(
  (ref) => UploadNotifier(ref), // Passamos a 'ref' para o Notifier.
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
      title: 'Projeto de Upload',
      // Adicionado conforme solicitado para remover o banner "DEBUG".
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<UploadTask> tasks = ref.watch(uploadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload de Arquivos - Fase 3')),
      body:
          tasks.isEmpty
              ? const Center(
                child: Text(
                  'Nenhum arquivo selecionado.\nClique em "+" para adicionar.',
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80), // Espaço para o FAB
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return ListTile(
                    // O ícone agora muda quando o upload é concluído.
                    leading:
                        task.status == UploadStatus.completed
                            ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                            : const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      task.file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // A barra de progresso agora se anima!
                        LinearProgressIndicator(
                          value: task.progress,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            task.status == UploadStatus.completed
                                ? Colors.green
                                : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // O texto de status também é dinâmico.
                        Text(
                          'Status: ${task.status.name} - Tamanho: ${_formatBytes(task.file.size)}',
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${(task.progress * 100).toStringAsFixed(0)}%',
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final notifier = ref.read(uploadProvider.notifier);

          final result = await FilePicker.platform.pickFiles(
            allowMultiple: true,
            type: FileType.media,
          );

          if (result != null) {
            notifier.addFiles(result.files);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

// =======================================================================
// 4. CAMADA DE SERVIÇO (SERVICE) - NOVA CAMADA
// =======================================================================

/// Esta classe simula o processo de upload de um arquivo.
class UploadService {
  /// Inicia uma simulação de upload.
  /// Recebe um [taskId] e um callback [onProgress] para notificar o progresso.
  void startUpload(String taskId, void Function(double progress) onProgress) {
    const totalSteps = 20; // Número de atualizações de progresso
    const durationPerStep = 150; // milissegundos
    var currentStep = 0;

    // Usamos um Timer periódico para simular o progresso ao longo do tempo.
    Timer.periodic(const Duration(milliseconds: durationPerStep), (timer) {
      currentStep++;
      final progress = currentStep / totalSteps;
      onProgress(progress); // Notifica o progresso através do callback

      if (currentStep == totalSteps) {
        timer.cancel(); // Para o timer quando o upload estiver completo
      }
    });
  }
}

/// Um provider simples para nos dar acesso à instância do nosso serviço.
final uploadServiceProvider = Provider((ref) => UploadService());
