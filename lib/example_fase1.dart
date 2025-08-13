import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Note que 'file_picker' já foi importado, pois será usado no nosso modelo.
import 'package:file_picker/file_picker.dart';

// =======================================================================
// 1. CAMADA DE MODELO (MODEL)
// Descreve a estrutura dos nossos dados.
// =======================================================================

/// Enum para representar os possíveis status de uma tarefa de upload.
/// Usar um enum é mais seguro e legível do que usar Strings.
enum UploadStatus {
  waiting, // Aguardando para iniciar o upload
  uploading, // O arquivo está sendo enviado
  completed, // O upload foi concluído com sucesso
  error, // Ocorreu um erro durante o upload
}

/// Representa uma única tarefa de upload.
/// Esta classe é imutável, o que é uma boa prática no Riverpod.
/// Para atualizar um valor, criaremos uma nova instância usando o `copyWith`.
@immutable
class UploadTask {
  const UploadTask({
    required this.id,
    required this.file,
    this.progress = 0.0,
    this.status = UploadStatus.waiting,
  });

  // Identificador único para cada tarefa, para podermos encontrá-la e atualizá-la.
  final String id;

  // O arquivo que foi selecionado pelo usuário.
  // PlatformFile vem do pacote file_picker e funciona em todas as plataformas.
  final PlatformFile file;

  // O progresso do upload, de 0.0 (0%) a 1.0 (100%).
  final double progress;

  // O status atual da tarefa, usando nosso enum.
  final UploadStatus status;

  /// Cria uma cópia da tarefa com valores atualizados.
  /// Essencial para manter a imutabilidade do nosso estado.
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
// Controladores e Provedores (Providers) do Riverpod.
// =======================================================================

/// O Notifier gerencia o estado, que neste caso é a lista de tarefas de upload.
/// Ele contém a lógica para adicionar, atualizar ou remover tarefas da lista.
class UploadNotifier extends StateNotifier<List<UploadTask>> {
  // O estado inicial é uma lista vazia de tarefas.
  UploadNotifier() : super([]);

  // Métodos para manipular o estado (adicionar, atualizar progresso, etc.)
  // serão adicionados nas próximas fases. Por enquanto, a estrutura está pronta.
}

/// O Provider é um objeto global e seguro que nos permite acessar o UploadNotifier
/// e seu estado de qualquer lugar na árvore de widgets.
final uploadProvider = StateNotifierProvider<UploadNotifier, List<UploadTask>>(
  (ref) => UploadNotifier(),
);

// =======================================================================
// 3. CAMADA DE UI (INTERFACE DO USUÁRIO)
// Todos os widgets que compõem a tela.
// =======================================================================

void main() {
  // O ProviderScope é o widget que armazena o estado de todos os providers.
  // Ele deve estar na raiz do aplicativo.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Projeto de Upload',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload de Arquivos - Fase 1')),
      body: const Center(
        child: Text(
          'A fundação do projeto está pronta!\nNenhuma funcionalidade visível ainda.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
