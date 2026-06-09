import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    String content = file.readAsStringSync();
    bool modified = false;
    
    if (content.contains('0xFFD7F454')) {
      content = content.replaceAll('const Color(0xFFD7F454)', 'AppColors.primary');
      content = content.replaceAll('Color(0xFFD7F454)', 'AppColors.primary');
      modified = true;
    }
    
    if (content.contains('0xFF0D0D0D')) {
      content = content.replaceAll('const Color(0xFF0D0D0D)', 'AppColors.authBackground');
      content = content.replaceAll('Color(0xFF0D0D0D)', 'AppColors.authBackground');
      modified = true;
    }
    if (content.contains('0xFF1A1A1A')) {
      content = content.replaceAll('const Color(0xFF1A1A1A)', 'AppColors.authSurface');
      content = content.replaceAll('Color(0xFF1A1A1A)', 'AppColors.authSurface');
      modified = true;
    }
    if (content.contains('0xFF2A2A2A')) {
      content = content.replaceAll('const Color(0xFF2A2A2A)', 'AppColors.authBorder');
      content = content.replaceAll('Color(0xFF2A2A2A)', 'AppColors.authBorder');
      modified = true;
    }
    if (content.contains('0xFF3A3A3A')) {
      content = content.replaceAll('const Color(0xFF3A3A3A)', 'AppColors.authBorderFocus');
      content = content.replaceAll('Color(0xFF3A3A3A)', 'AppColors.authBorderFocus');
      modified = true;
    }
    if (content.contains('0xFF0088CC')) {
      content = content.replaceAll('const Color(0xFF0088CC)', 'AppColors.telegramBlue');
      content = content.replaceAll('Color(0xFF0088CC)', 'AppColors.telegramBlue');
      modified = true;
    }

    if (modified) {
      if (!content.contains('package:eyeon/core/theme/app_theme.dart')) {
        // Insert import after the last import
        final importRegExp = RegExp(r"import '.*?';");
        final matches = importRegExp.allMatches(content);
        if (matches.isNotEmpty) {
          final lastMatch = matches.last;
          content = content.replaceRange(lastMatch.end, lastMatch.end, "\nimport 'package:eyeon/core/theme/app_theme.dart';");
        } else {
          content = "import 'package:eyeon/core/theme/app_theme.dart';\n" + content;
        }
      }
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
