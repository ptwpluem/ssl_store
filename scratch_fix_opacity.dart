import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  final regex = RegExp(r'\.withOpacity\(([^)]+)\)');
  
  int count = 0;
  for (var file in files) {
    String content = file.readAsStringSync();
    if (content.contains('.withOpacity(')) {
      final newContent = content.replaceAllMapped(regex, (match) {
        return '.withValues(alpha: ${match.group(1)})';
      });
      if (newContent != content) {
        file.writeAsStringSync(newContent);
        print('Updated ${file.path}');
        count++;
      }
    }
  }
  print('Total files updated: $count');
}
