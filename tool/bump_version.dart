import 'dart:io';

/// Automated Version Bumper & Git Release Automation Script
///
/// Usage:
///   dart run tool/bump_version.dart [patch|minor|major|build] ["commit message"]
///
/// Defaults:
///   type: patch
///   message: Auto version bump to vX.Y.Z
void main(List<String> args) async {
  final bumpType = args.isNotEmpty ? args[0].toLowerCase() : 'patch';
  final customMsg = args.length > 1 ? args[1] : null;

  print('===========================================================');
  print('🚀 SheIn Connect Version Bumper & Git Release Automation');
  print('===========================================================');

  // 1. Read pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ Error: pubspec.yaml not found.');
    exit(1);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)', multiLine: true);
  final match = versionRegex.firstMatch(pubspecContent);

  if (match == null) {
    print('❌ Error: Could not parse version in pubspec.yaml.');
    exit(1);
  }

  int major = int.parse(match.group(1)!);
  int minor = int.parse(match.group(2)!);
  int patch = int.parse(match.group(3)!);
  int build = int.parse(match.group(4)!);

  final oldVersionStr = '$major.$minor.$patch+$build';

  // Increment version based on bumpType
  switch (bumpType) {
    case 'major':
      major += 1;
      minor = 0;
      patch = 0;
      build += 1;
      break;
    case 'minor':
      minor += 1;
      patch = 0;
      build += 1;
      break;
    case 'build':
      build += 1;
      break;
    case 'patch':
    default:
      patch += 1;
      build += 1;
      break;
  }

  final newSemanticVersion = '$major.$minor.$patch';
  final newFullVersion = '$newSemanticVersion+$build';
  final tagName = 'v$newSemanticVersion';

  print('📦 Current Version : $oldVersionStr');
  print('🎉 New Version     : $newFullVersion (Tag: $tagName)');
  print('-----------------------------------------------------------');

  // 2. Update pubspec.yaml
  final updatedPubspec = pubspecContent.replaceFirst(
    versionRegex,
    'version: $newFullVersion',
  );
  pubspecFile.writeAsStringSync(updatedPubspec);
  print('✅ Updated pubspec.yaml');

  // 3. Update lib/core/constants/app_config.dart
  final appConfigFile = File('lib/core/constants/app_config.dart');
  if (appConfigFile.existsSync()) {
    var content = appConfigFile.readAsStringSync();
    content = content.replaceAll(
      RegExp(r"static const String appVersion = '[^']+';"),
      "static const String appVersion = '$newSemanticVersion';",
    );
    content = content.replaceAll(
      RegExp(r"static const int buildNumber = \d+;"),
      "static const int buildNumber = $build;",
    );
    appConfigFile.writeAsStringSync(content);
    print('✅ Updated lib/core/constants/app_config.dart');
  }

  // 4. Update CHANGELOG.md (add version header if not exists)
  final changelogFile = File('CHANGELOG.md');
  if (changelogFile.existsSync()) {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final header = '## [$newSemanticVersion] - $dateStr\n- Release version $newFullVersion.\n\n';
    var changelog = changelogFile.readAsStringSync();
    if (!changelog.contains('## [$newSemanticVersion]')) {
      changelog = changelog.replaceFirst('# Changelog\n\n', '# Changelog\n\n$header');
      changelogFile.writeAsStringSync(changelog);
      print('✅ Updated CHANGELOG.md with release header [$newSemanticVersion]');
    }
  }

  print('-----------------------------------------------------------');
  print('🛠️ Executing Git operations...');

  // 5. Check if git repo is initialized; if not, initialize it
  final gitDir = Directory('.git');
  if (!gitDir.existsSync()) {
    print('ℹ️ Initializing local Git repository...');
    await _runCmd('git', ['init']);
    await _runCmd('git', ['branch', '-M', 'main']);
  }

  // 6. Git add all changed files
  print('➕ Running: git add .');
  await _runCmd('git', ['add', '.']);

  // 7. Git commit with new version
  final commitMessage = customMsg ?? 'chore(release): bump version to $tagName [skip ci]';
  print('💾 Running: git commit -m "$commitMessage"');
  await _runCmd('git', ['commit', '-m', commitMessage]);

  // 8. Create Git tag
  print('🏷️  Running: git tag -a $tagName -m "Release $tagName"');
  await _runCmd('git', ['tag', '-a', tagName, '-m', 'Release $tagName']);

  // 9. Git push (if remote origin exists)
  final remoteCheck = await Process.run('git', ['remote']);
  if (remoteCheck.stdout.toString().trim().isNotEmpty) {
    print('🚀 Pushing commits and tags to remote repository...');
    await _runCmd('git', ['push', 'origin', 'HEAD']);
    await _runCmd('git', ['push', 'origin', tagName]);
    print('✨ Successfully pushed $tagName to remote!');
  } else {
    print('💡 Note: No git remote configured yet. When you configure remote, push with:');
    print('   git push origin main && git push origin $tagName');
  }

  print('===========================================================');
  print('🎯 DONE! Version bumped to $newFullVersion and tagged as $tagName.');
  print('===========================================================');
}

Future<void> _runCmd(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.stdout.toString().trim().isNotEmpty) {
    stdout.write(result.stdout);
  }
  if (result.stderr.toString().trim().isNotEmpty && result.exitCode != 0) {
    stderr.write(result.stderr);
  }
  if (result.exitCode != 0) {
    print('⚠️ Note: "$executable ${arguments.join(' ')}" finished with exit code ${result.exitCode}');
  }
}
