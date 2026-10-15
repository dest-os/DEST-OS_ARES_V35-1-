import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_model_config.dart';

/// ARES yerel AI modelinin cihazdaki dosya konumunu yönetir.
class LocalModelStorage {
  Future<Directory> getModelDirectory() async {
    final appDirectory = await getApplicationSupportDirectory();
    final modelDirectory = Directory('${appDirectory.path}/ares/models');

    if (!await modelDirectory.exists()) {
      await modelDirectory.create(recursive: true);
    }

    return modelDirectory;
  }

  /// İndirici ve model yükleyici tarafından kullanılan tek model yolu.
  Future<String> getModelPath() async {
    final directory = await getModelDirectory();
    return '${directory.path}/${LocalModelConfig.fileName}';
  }

  Future<bool> isModelAvailable() async {
    final file = await getModelFile();
    return file != null;
  }

  Future<File?> getModelFile() async {
    final modelPath = await getModelPath();
    final file = File(modelPath);

    if (!await file.exists()) return null;
    return file;
  }


  /// Eski sürümün büyük modelini yalnızca yeni model başarıyla yüklendikten
  /// sonra temizler; başarısız yükleme durumunda yedek olarak bırakılır.
  Future<void> deleteLegacyModel() async {
    final directory = await getModelDirectory();
    final legacyFile = File(
      '${directory.path}/Qwen3-1.7B-Q4_K_M.gguf',
    );
    if (await legacyFile.exists()) {
      await legacyFile.delete();
    }
  }

  Future<void> deleteModel() async {
    final file = await getModelFile();
    if (file != null) await file.delete();
  }
}
