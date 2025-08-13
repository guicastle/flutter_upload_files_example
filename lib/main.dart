import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// =======================================================================
// 1. CAMADA DE MODELO (MODEL)
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
// 2. CAMADA DE ESTADO (STATE MANAGEMENT)
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
    uploadService.startUpload(
      taskId,
      (progress) => _updateTaskProgress(taskId, progress),
      () => _markAsError(taskId),
    );
  }

  void retryUpload(String taskId) {
    final taskIndex = state.indexWhere((task) => task.id == taskId);
    if (taskIndex == -1) return;

    final taskToRetry = state[taskIndex];
    final resetTask = taskToRetry.copyWith(
      progress: 0.0,
      status: UploadStatus.waiting,
    );

    final newState = List<UploadTask>.from(state);
    newState[taskIndex] = resetTask;
    state = newState;

    _startUpload(taskId);
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

final isDraggingProvider = StateProvider<bool>((ref) => false);
final overlayVisibilityProvider = StateProvider<bool>((ref) => true);

// =======================================================================
// 3. CAMADA DE UI (INTERFACE DO USUÁRIO)
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
      builder: (context, child) {
        return Stack(children: [child!, const UploadOverlay()]);
      },
      home: const HomePage(),
    );
  }
}

// --- PÁGINA INICIAL ---
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(uploadProvider);
    final isDragging = ref.watch(isDraggingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload de Arquivos')),
      body: DropTarget(
        onDragDone: (details) async {
          final notifier = ref.read(uploadProvider.notifier);
          ref.read(overlayVisibilityProvider.notifier).state = true;
          final platformFiles = await Future.wait(
            details.files.map((xfile) async {
              return PlatformFile(
                name: xfile.name,
                path: xfile.path,
                size: await xfile.length(),
              );
            }),
          );
          notifier.addFiles(platformFiles);
        },
        onDragEntered:
            (d) => ref.read(isDraggingProvider.notifier).state = true,
        onDragExited:
            (d) => ref.read(isDraggingProvider.notifier).state = false,
        child: Container(
          color:
              isDragging
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.transparent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SecondPage(),
                            ),
                          ),
                      child: const Text('Ir para Segunda Tela'),
                    ),
                    ElevatedButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsPage(),
                            ),
                          ),
                      child: const Text('Ir para Configurações'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child:
                    tasks.isEmpty
                        ? const Center(
                          child: Text(
                            'Arraste arquivos aqui ou clique em "+" para adicionar.',
                          ),
                        )
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 600) {
                              return _buildGridView(tasks);
                            } else {
                              return _buildListView(tasks);
                            }
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final notifier = ref.read(uploadProvider.notifier);
          ref.read(overlayVisibilityProvider.notifier).state = true;
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
        maxCrossAxisExtent: 250,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _UploadGridItem(task: tasks[index]),
    );
  }
}

// --- WIDGETS E TELAS ---
// POPUP DA LISTA DE ENVIADOS
class UploadOverlay extends ConsumerWidget {
  const UploadOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ongoingTasks = ref.watch(
      uploadProvider.select(
        (tasks) =>
            tasks.where((t) => t.status != UploadStatus.waiting).toList(),
      ),
    );
    final isOverlayVisible = ref.watch(overlayVisibilityProvider);

    if (ongoingTasks.isEmpty || !isOverlayVisible) {
      return const SizedBox.shrink();
    }

    final completedCount =
        ongoingTasks.where((t) => t.status == UploadStatus.completed).length;
    final errorCount =
        ongoingTasks.where((t) => t.status == UploadStatus.error).length;
    final uploadingCount =
        ongoingTasks.where((t) => t.status == UploadStatus.uploading).length;

    String title;
    if (uploadingCount > 0) {
      title =
          'Enviando ${ongoingTasks.length} ${ongoingTasks.length > 1 ? "itens" : "item"}';
    } else if (errorCount > 0) {
      title = '$errorCount falhas de upload';
    } else {
      title = '$completedCount uploads concluídos';
    }

    return Positioned(
      bottom: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 350,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed:
                          () =>
                              ref
                                  .read(overlayVisibilityProvider.notifier)
                                  .state = false,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ongoingTasks.length,
                  itemBuilder: (context, index) {
                    final sortedTasks = List.of(
                      ongoingTasks,
                    )..sort((a, b) => a.status.index.compareTo(b.status.index));
                    return _OverlayUploadPopupItem(task: sortedTasks[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayUploadPopupItem extends ConsumerWidget {
  const _OverlayUploadPopupItem({required this.task});
  final UploadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildIconForTask(task, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.file.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          _buildTrailingForStatus(context, task, ref),
        ],
      ),
    );
  }

  Widget _buildTrailingForStatus(
    BuildContext context,
    UploadTask task,
    WidgetRef ref,
  ) {
    switch (task.status) {
      case UploadStatus.uploading:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: task.progress,
            strokeWidth: 3,
          ),
        );
      case UploadStatus.completed:
        return Icon(Icons.check_circle, color: _getColorForStatus(task.status));
      case UploadStatus.error:
        // Botão de Tentar Novamente com propriedades para UI compacta
        return IconButton(
          icon: Icon(Icons.refresh, color: _getColorForStatus(task.status)),
          onPressed:
              () => ref.read(uploadProvider.notifier).retryUpload(task.id),
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Segunda Tela')),
      body: const Center(
        child: Text(
          'Você está em outra tela, mas o upload continua!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: const Center(
        child: Text(
          'Aqui seria a tela de configurações.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class _UploadListItem extends ConsumerWidget {
  const _UploadListItem({required this.task});
  final UploadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      trailing:
          task.status == UploadStatus.error
              ? IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: _getColorForStatus(task.status),
                ),
                onPressed:
                    () =>
                        ref.read(uploadProvider.notifier).retryUpload(task.id),
              )
              : Text('${(task.progress * 100).toStringAsFixed(0)}%'),
    );
  }
}

class _UploadGridItem extends ConsumerWidget {
  const _UploadGridItem({required this.task});
  final UploadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                if (task.status == UploadStatus.error)
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      size: 18,
                      color: _getColorForStatus(task.status),
                    ),
                    onPressed:
                        () => ref
                            .read(uploadProvider.notifier)
                            .retryUpload(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
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

class UploadService {
  void startUpload(
    String taskId,
    void Function(double) onProgress,
    void Function() onError,
  ) {
    const totalSteps = 20;
    const durationPerStep = 200;
    var currentStep = 0;
    final willError = Random().nextDouble() < 0.2;

    Timer.periodic(const Duration(milliseconds: durationPerStep), (timer) {
      if (currentStep > 5 && willError) {
        timer.cancel();
        onError();
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
