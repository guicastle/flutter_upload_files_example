import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

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
  UploadNotifier(this.ref) : super([]);

  final Ref ref;

  void addFiles(List<PlatformFile> files) {
    final newTasks =
        files.map((file) {
          final id = '${DateTime.now().millisecondsSinceEpoch}-${file.name}';
          return UploadTask(id: id, file: file);
        }).toList();

    state = [...state, ...newTasks];

    for (final task in newTasks) {
      _startUpload(task.id);
    }
  }

  void _startUpload(String taskId) {
    final uploadService = ref.read(uploadServiceProvider);

    // Passamos 3 callbacks: um para o progresso, um para a conclusão (que não precisamos mais), e um para o erro.
    uploadService.startUpload(
      taskId,
      (progress) => _updateTaskProgress(taskId, progress),
      () => _markAsError(taskId), // Callback de erro
    );
  }

  void _updateTaskProgress(String taskId, double progress) {
    final taskIndex = state.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return;

    final taskToUpdate = state[taskIndex];
    final newStatus =
        progress == 1.0 ? UploadStatus.completed : UploadStatus.uploading;

    final updatedTask = taskToUpdate.copyWith(
      progress: progress,
      status: newStatus,
    );

    final newState = List<UploadTask>.from(state);
    newState[taskIndex] = updatedTask;
    state = newState;
  }

  /// Novo método para marcar uma tarefa como "Erro".
  void _markAsError(String taskId) {
    final taskIndex = state.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return;

    final taskToUpdate = state[taskIndex];
    final updatedTask = taskToUpdate.copyWith(status: UploadStatus.error);

    final newState = List<UploadTask>.from(state);
    newState[taskIndex] = updatedTask;
    state = newState;
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, List<UploadTask>>(
  (ref) => UploadNotifier(ref),
);

// Provider para controlar o estado visual do DropTarget (se está sendo arrastado algo sobre ele)
final isDraggingProvider = StateProvider<bool>((ref) => false);

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
    final tasks = ref.watch(uploadProvider);
    final isDragging = ref.watch(
      isDraggingProvider,
    ); // Observa o estado de arrastar

    return Scaffold(
      appBar: AppBar(title: const Text('Upload de Arquivos - Fase 4')),
      // O corpo agora é envolvido pelo DropTarget para habilitar o arrastar e soltar
      body: DropTarget(
        onDragDone: (details) async {
          final notifier = ref.read(uploadProvider.notifier);

          // O pacote nos entrega XFile, precisamos convertê-los para PlatformFile
          final platformFiles = await Future.wait(
            details.files.map((xfile) async {
              return PlatformFile(
                name: xfile.name,
                path: xfile.path,
                size: await xfile.length(),
                bytes: await xfile.readAsBytes(),
              );
            }),
          );

          notifier.addFiles(platformFiles);
        },
        onDragEntered:
            (details) => ref.read(isDraggingProvider.notifier).state = true,
        onDragExited:
            (details) => ref.read(isDraggingProvider.notifier).state = false,
        child: Container(
          // Feedback visual quando um arquivo está sendo arrastado sobre a área
          color:
              isDragging
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.transparent,
          child:
              tasks.isEmpty
                  ? const Center(
                    child: Text(
                      'Arraste arquivos aqui ou clique em "+" para adicionar.',
                    ),
                  )
                  // LayoutBuilder para decidir entre Lista e Grade
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      // Define um ponto de quebra. Se a tela for maior que 600px, usa grade.
                      if (constraints.maxWidth > 600) {
                        return _buildGridView(tasks);
                      } else {
                        return _buildListView(tasks);
                      }
                    },
                  ),
        ),
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

  ListView _buildListView(List<UploadTask> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _UploadListItem(task: tasks[index]),
    );
  }

  GridView _buildGridView(List<UploadTask> tasks) {
    return GridView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250, // Largura máxima de cada item
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2, // Proporção do item
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _UploadGridItem(task: tasks[index]),
    );
  }
}

// Widget para o item da lista (Layout de Celular)
class _UploadListItem extends StatelessWidget {
  const _UploadListItem({required this.task});
  final UploadTask task;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildIconForTask(task),
      title: Text(task.file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: task.progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getColorForStatus(task.status),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${task.status.name} - Tamanho: ${_formatBytes(task.file.size)}',
          ),
        ],
      ),
      trailing: Text('${(task.progress * 100).toStringAsFixed(0)}%'),
    );
  }
}

// Widget para o item da grade (Layout de Web/Desktop)
class _UploadGridItem extends StatelessWidget {
  const _UploadGridItem({required this.task});
  final UploadTask task;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: _buildIconForTask(task, size: 48))),
            Text(
              task.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getColorForStatus(task.status),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.status.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${(task.progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// 4. CAMADA DE SERVIÇO (SERVICE) - ATUALIZADA
// =======================================================================

class UploadService {
  void startUpload(
    String taskId,
    void Function(double) onProgress,
    void Function() onError,
  ) {
    const totalSteps = 20;
    const durationPerStep = 200;
    var currentStep = 0;

    // Chance de 20% de dar erro no início do upload
    final willError = Random().nextDouble() < 0.2;

    Timer.periodic(const Duration(milliseconds: durationPerStep), (timer) {
      if (currentStep > 5 && willError) {
        timer.cancel();
        onError(); // Chama o callback de erro
        return;
      }

      currentStep++;
      final progress = currentStep / totalSteps;
      onProgress(progress);

      if (currentStep == totalSteps) {
        timer.cancel();
      }
    });
  }
}

final uploadServiceProvider = Provider((ref) => UploadService());

// =======================================================================
// 5. FUNÇÕES AUXILIARES DE UI
// =======================================================================

Color _getColorForStatus(UploadStatus status) {
  switch (status) {
    case UploadStatus.uploading:
      return Colors.blue;
    case UploadStatus.completed:
      return Colors.green;
    case UploadStatus.error:
      return Colors.red;
    case UploadStatus.waiting:
      return Colors.grey;
  }
}

Widget _buildIconForTask(UploadTask task, {double size = 40.0}) {
  final status = task.status;
  if (status == UploadStatus.completed) {
    return Icon(
      Icons.check_circle,
      color: _getColorForStatus(status),
      size: size,
    );
  }
  if (status == UploadStatus.error) {
    return Icon(Icons.error, color: _getColorForStatus(status), size: size);
  }

  final extension = p.extension(task.file.name).toLowerCase();
  switch (extension) {
    case '.jpg':
    case '.jpeg':
    case '.png':
    case '.gif':
      return Icon(Icons.image, color: Colors.grey.shade700, size: size);
    case '.mp4':
    case '.mov':
    case '.avi':
      return Icon(Icons.videocam, color: Colors.grey.shade700, size: size);
    default:
      return Icon(
        Icons.insert_drive_file,
        color: Colors.grey.shade700,
        size: size,
      );
  }
}

String _formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}
