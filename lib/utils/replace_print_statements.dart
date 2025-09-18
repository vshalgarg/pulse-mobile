// This is a utility script to help replace print() statements with debugPrint()
// Run this script to find and replace all print statements in your codebase

import 'dart:io';

void main() async {
  final directory = Directory('lib');
  final files = await directory.list(recursive: true).toList();
  
  int totalReplacements = 0;
  
  for (final file in files) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();
      
      // Count print statements
      final printMatches = RegExp(r'\bprint\(').allMatches(content).length;
      
      if (printMatches > 0) {
        print('Found $printMatches print() statements in ${file.path}');
        
        // Replace print( with debugPrint(
        final updatedContent = content.replaceAll(RegExp(r'\bprint\('), 'debugPrint(');
        
        // Check if we need to add the import
        if (updatedContent.contains('debugPrint(') && !updatedContent.contains("import 'package:flutter/foundation.dart';")) {
          // Add import after existing imports
          final lines = updatedContent.split('\n');
          int insertIndex = 0;
          
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].startsWith('import ')) {
              insertIndex = i + 1;
            } else if (lines[i].trim().isEmpty && insertIndex > 0) {
              break;
            }
          }
          
          lines.insert(insertIndex, "import 'package:flutter/foundation.dart';");
          final finalContent = lines.join('\n');
          
          await file.writeAsString(finalContent);
          print('  ✅ Updated ${file.path} - Added import and replaced $printMatches statements');
          totalReplacements += printMatches;
        } else if (updatedContent.contains('debugPrint(')) {
          await file.writeAsString(updatedContent);
          print('  ✅ Updated ${file.path} - Replaced $printMatches statements');
          totalReplacements += printMatches;
        }
      }
    }
  }
  
  print('\n🎉 Total replacements made: $totalReplacements');
  print('All print() statements have been replaced with debugPrint()');
}
