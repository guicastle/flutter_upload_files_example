# flutter_upload_files_example

Vamos usar analogias, para entender nosso código usando a ideia de ser um **restaurante moderno e automatizado**.

Pense no nosso aplicativo como este restaurante.

-----

### 1\. O Modelo de Dados: A "Ficha de Pedido"

**Analogia:** Cada `UploadTask` é uma **ficha de pedido** individual que vai para a cozinha.

**Código Específico:**

```dart
enum UploadStatus { waiting, uploading, completed, error }

class UploadTask {
  final String id;        // O número único do pedido
  final PlatformFile file;  // O prato principal solicitado (o arquivo)
  final double progress;    // O quão pronto o prato está (0% a 100%)
  final UploadStatus status;  // O estado do pedido: na fila, cozinhando, pronto ou queimado
}
```

**Explicação:** Assim como uma ficha de pedido contém todas as informações sobre um prato (quem pediu, qual o prato, se está sendo preparado ou se já foi entregue), nossa classe `UploadTask` contém tudo o que precisamos saber sobre um único upload. O `enum UploadStatus` garante que o estado do pedido seja sempre um dos valores que conhecemos, evitando confusão.

-----

### 2\. O Gerenciador de Estado: O "Gerente com a Prancheta"

**Analogia:** O `UploadNotifier` é o **gerente do restaurante**, e a lista de tarefas (`state`) é a sua **prancheta de pedidos**.

**Código Específico:**

```dart
class UploadNotifier extends StateNotifier<List<UploadTask>> {
  // ...
  void addFiles(List<PlatformFile> files) { ... }
  void retryUpload(String taskId) { ... }
  // ...
}

final uploadProvider = StateNotifierProvider<...>( ... );
```

**Explicação:** O **Gerente** (`UploadNotifier`) é a única pessoa autorizada a adicionar ou modificar pedidos na **Prancheta** (`state`).

  * Quando o cliente faz um pedido (`addFiles`), o gerente anota tudo na prancheta.
  * Se um prato queima (`error`), o cliente pode reclamar, e o gerente dá a ordem para a cozinha refazê-lo (`retryUpload`).
  * O `uploadProvider` é como o **sistema de comunicação interna do restaurante**. Qualquer funcionário (widget) pode usá-lo para "chamar" o gerente (`ref.read`) ou para "ficar de olho" na prancheta de pedidos para ver as atualizações em tempo real (`ref.watch`).

-----

### 3\. O Serviço de Upload: O "Cozinheiro Especializado"

**Analogia:** O `UploadService` é o **cozinheiro** que trabalha na sua estação, focado em uma única tarefa.

**Código Específico:**

```dart
class UploadService {
  void startUpload(String taskId, void Function(double) onProgress, void Function() onError) { ... }
}
```

**Explicação:** O Gerente (`UploadNotifier`) não cozinha. Ele pega uma ficha de pedido e a entrega ao **Cozinheiro** (`UploadService`), dizendo: "Prepare este prato (`taskId`)". O cozinheiro não fala com os clientes (a UI), ele apenas se concentra em cozinhar. Durante o preparo, ele grita de volta para o gerente:

  * "O prato está 50% pronto\!" (chama o callback `onProgress`).
  * "Opa, queimou\!" (chama o callback `onError`).

Isso mostra o princípio da **responsabilidade única**: o serviço faz o trabalho pesado, e o notifier gerencia o estado geral com base no que o serviço informa.

-----

### 4\. A Interface Principal: O "Salão do Restaurante"

**Analogia:** A `HomePage` é o **salão principal do restaurante**, onde os clientes (usuários) estão.

**Código Específico:**

```dart
class HomePage extends ConsumerWidget {
  // ...
  LayoutBuilder(...) // O layout do salão
  DropTarget(...)   // A esteira de "autoatendimento"
  FloatingActionButton(...) // O botão para chamar o garçom
  // ...
}
```

**Explicação:** No salão, o layout pode mudar (`LayoutBuilder`). Se o restaurante está cheio (tela grande), as mesas são organizadas em uma grade (`GridView`). Se está mais apertado (tela de celular), elas ficam em fila (`ListView`).

O `DropTarget` é como uma esteira rolante onde o cliente pode colocar seus próprios ingredientes (arrastar arquivos) para a cozinha preparar. O `FloatingActionButton` (`+`) é o botão que o cliente aperta para fazer um novo pedido.

-----

### 5\. O Overlay Global: O "Painel de Senhas"

**Analogia:** O `UploadOverlay` é o **painel eletrônico de senhas** que fica na parede, visível de qualquer lugar do restaurante.

**Código Específico:**

```dart
class MyApp extends StatelessWidget {
  // ...
  builder: (context, child) {
    return Stack(children: [child!, const UploadOverlay()]);
  },
  // ...
}

class UploadOverlay extends ConsumerWidget { ... }
```

**Explicação:** Ao construir nosso restaurante (`MyApp`), usamos um `Stack` no `builder` para instalar o **Painel de Senhas** (`UploadOverlay`) em um local fixo *antes* de colocar as mesas e paredes. Não importa se o cliente vai ao balcão (`HomePage`), ao banheiro (`SecondPage`) ou ao caixa (`SettingsPage`), ele sempre consegue ver o painel.

Este painel está ligado diretamente à prancheta do gerente (`ref.watch(uploadProvider)`) e mostra em tempo real o status de todos os pedidos que estão sendo preparados. Ele aparece quando o primeiro pedido é feito e some quando tudo está pronto, exatamente como um painel de senhas.

---

### **Fase 1: A Fundação - Estrutura e Estado**

Nesta primeira fase, não vamos nos preocupar com a aparência. O foco é 100% na arquitetura do nosso app, preparando o esqueleto para as funcionalidades futuras.

* **Objetivo de Aprendizagem:**
    * Compreender como estruturar um projeto Flutter limpo.
    * Aprender a modelar o estado da aplicação (o que são os dados que precisamos gerenciar?).
    * Implementar a base do gerenciamento de estado com Riverpod, criando os `Providers` e `Notifiers` que sustentarão o app.
    * Configurar dependências externas (`flutter_riverpod`, `file_picker`) no `pubspec.yaml`.

* **O Que Será Entregue:**
    1.  Um projeto Flutter funcional, porém com uma tela visualmente simples (talvez apenas com um título).
    2.  O arquivo `pubspec.yaml` com as dependências adicionadas.
    3.  Dentro do `main.dart`, teremos a definição da classe `UploadTask` (que representa um arquivo, seu progresso e status).
    4.  A classe `UploadNotifier` (que gerencia a lista de `UploadTask`) e seu respectivo `StateNotifierProvider` global estarão criados, mas ainda não serão usados pela UI.

---

### **Fase 2: Interação Inicial - Selecionando Arquivos**

Agora que a fundação está pronta, vamos criar a primeira interação do usuário: a capacidade de escolher arquivos e vê-los listados na tela.

* **Objetivo de Aprendizagem:**
    * Aprender a usar o pacote `file_picker` para abrir o seletor de arquivos nativo no mobile e na web.
    * Entender como permitir a seleção de múltiplos arquivos.
    * Conectar a UI ao `Provider` do Riverpod para que, ao selecionar arquivos, eles sejam adicionados ao nosso estado global.
    * Renderizar uma lista simples na tela baseada nos dados do nosso `Provider` (`ConsumerWidget`).

* **O Que Será Entregue:**
    1.  Um botão "Adicionar Arquivos" na tela.
    2.  Ao clicar no botão, o seletor de arquivos do sistema operacional será aberto.
    3.  Após o usuário selecionar um ou mais arquivos, seus nomes aparecerão em uma lista na tela.
    4.  Cada item na lista já pode ter um espaço reservado para a barra de progresso (ex: um progresso estático em 0%).

---

### **Fase 3: A Mágica da Simulação - Dando Vida ao Progresso**

Esta é a fase central do nosso estudo. Vamos simular o processo de upload para fazer nossa UI reagir e mostrar o progresso em tempo real, tudo de forma concorrente.

* **Objetivo de Aprendizagem:**
    * Dominar o conceito de "camada de serviço" para isolar a lógica de negócio.
    * Implementar operações assíncronas (usando `Future` e `Timer`) para simular o upload.
    * Aprender a fazer o serviço se comunicar com o `Notifier` do Riverpod para atualizar o estado (o progresso de cada arquivo).
    * Ver na prática o poder da programação reativa: a UI se atualiza automaticamente em resposta às mudanças de estado, sem intervenção manual.

* **O Que Será Entregue:**
    1.  Uma classe `UploadService` com um método "fake" `uploadFiles()`.
    2.  Ao selecionar os arquivos (entrega da Fase 2), o upload simulado começará automaticamente para todos eles.
    3.  Cada item na lista de uploads terá sua própria barra de progresso, que se animará de 0% a 100% de forma independente.
    4.  O status do arquivo mudará de "Enviando..." para "Concluído" ao final do processo.

---

### **Fase 4: Refinamento - UI Responsiva e Melhorias**

Com a funcionalidade principal pronta e funcionando, agora é hora de refinar a experiência do usuário e garantir que nosso app seja bonito e funcional em qualquer tela.

* **Objetivo de Aprendizagem:**
    * Aprender a criar layouts adaptativos.
    * Implementar o `LayoutBuilder` para diferenciar a UI entre telas estreitas (mobile) e largas (web).
    * Melhorar a apresentação visual dos itens de upload (ícones, cores, feedback de erro).
    * Adicionar o arrasta de 1 ou varios itens e serem adicionados em lista como o Google Driver

* **O Que Será Entregue:**
    1.  A lista de uploads será exibida como uma lista vertical (`ListView`) em telas de celular.
    2.  A mesma lista será exibida como uma grade (`GridView`) em telas maiores, como a de um navegador desktop.
    3.  A UI terá um aspecto mais polido, talvez com ícones que diferenciem imagens de vídeos e um tratamento visual para uploads com erro (que podemos adicionar à simulação).

---

git init 
Initialized empty Git repository in C:/Users/guilhermemuniz/Documents/Repositories/01-Public/flutter_upload_files_example/.git/
git add .
git commit -m "Project init - Exemplos 5 fases"
git remote add origin https://github.com/guicastle/flutter_upload_files_example.git
git branch -M main
git push -u origin main -f