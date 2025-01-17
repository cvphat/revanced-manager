import 'dart:convert';
import 'dart:io';
import 'package:app_installer/app_installer.dart';
import 'package:collection/collection.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:revanced_manager/app/app.locator.dart';
import 'package:revanced_manager/models/github_latest_release.dart';
import 'package:revanced_manager/models/patch.dart';
import 'package:revanced_manager/models/patched_application.dart';
import 'package:revanced_manager/services/github_api.dart';
import 'package:revanced_manager/services/revanced_api.dart';
import 'package:revanced_manager/services/root_api.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class ManagerAPI {
  final RevancedAPI _revancedAPI = locator<RevancedAPI>();
  final GithubAPI _githubAPI = locator<GithubAPI>();
  final RootAPI _rootAPI = RootAPI();
  final String patcherRepo = 'revanced-patcher';
  final String cliRepo = 'revanced-cli';
  final String vancedMicroGPackageName = 'com.mgoogle.android.gms';
  late SharedPreferences _prefs;
  String storedPatchesFile = '/selected-patches.json';
  String defaultApiUrl = 'https://releases.revanced.app/';
  String defaultRepoUrl = 'https://api.github.com';
  String defaultPatcherRepo = 'revanced/revanced-patcher';
  String defaultPatchesRepo = 'revanced/revanced-patches';
  String defaultIntegrationsRepo = 'revanced/revanced-integrations';
  String defaultCliRepo = 'revanced/revanced-cli';
  String defaultManagerRepo = 'cvphat/revanced-manager';
  String defaultMicroGRepo = 'TeamVanced/VancedMicroG';

  GithubLatestRelease? _vancedMicroGLatestRelease;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    storedPatchesFile =
        (await getApplicationDocumentsDirectory()).path + storedPatchesFile;
  }

  String? getGithubToken() {
    return _prefs.getString('githubToken');
  }

  Future<void> setGithubToken(String token) async {
    await _prefs.setString('githubToken', token);
  }

  String getApiUrl() {
    return _prefs.getString('apiUrl') ?? defaultApiUrl;
  }

  Future<void> setApiUrl(String url) async {
    if (url.isEmpty || url == ' ') {
      url = defaultApiUrl;
    }
    await _revancedAPI.initialize(url);
    await _revancedAPI.clearAllCache();
    await _prefs.setString('apiUrl', url);
  }

  String getRepoUrl() {
    return _prefs.getString('repoUrl') ?? defaultRepoUrl;
  }

  Future<void> setRepoUrl(String url) async {
    if (url.isEmpty || url == ' ') {
      url = defaultRepoUrl;
    }
    await _prefs.setString('repoUrl', url);
  }

  String getPatchesRepo() {
    return _prefs.getString('patchesRepo') ?? defaultPatchesRepo;
  }

  Future<void> setPatchesRepo(String value) async {
    if (value.isEmpty || value.startsWith('/') || value.endsWith('/')) {
      value = defaultPatchesRepo;
    }
    await _prefs.setString('patchesRepo', value);
  }

  String getIntegrationsRepo() {
    return _prefs.getString('integrationsRepo') ?? defaultIntegrationsRepo;
  }

  Future<void> setIntegrationsRepo(String value) async {
    if (value.isEmpty || value.startsWith('/') || value.endsWith('/')) {
      value = defaultIntegrationsRepo;
    }
    await _prefs.setString('integrationsRepo', value);
  }

  String getMicroGRepo() {
    return _prefs.getString('microGRepo') ?? defaultMicroGRepo;
  }

  Future<void> setMicroGRepo(String value) async {
    if (value.isEmpty || value.startsWith('/') || value.endsWith('/')) {
      value = defaultMicroGRepo;
    }
    await _prefs.setString('microGRepo', value);
  }

  bool getUseDynamicTheme() {
    return _prefs.getBool('useDynamicTheme') ?? false;
  }

  Future<void> setUseDynamicTheme(bool value) async {
    await _prefs.setBool('useDynamicTheme', value);
  }

  bool getUseDarkTheme() {
    return _prefs.getBool('useDarkTheme') ?? false;
  }

  Future<void> setUseDarkTheme(bool value) async {
    await _prefs.setBool('useDarkTheme', value);
  }

  bool isSentryEnabled() {
    return _prefs.getBool('sentryEnabled') ?? true;
  }

  Future<void> setSentryStatus(bool value) async {
    await _prefs.setBool('sentryEnabled', value);
  }

  bool areUniversalPatchesEnabled() {
    return _prefs.getBool('universalPatchesEnabled') ?? false;
  }

  Future<void> enableUniversalPatchesStatus(bool value) async {
    await _prefs.setBool('universalPatchesEnabled', value);
  }

  bool areExperimentalPatchesEnabled() {
    return _prefs.getBool('experimentalPatchesEnabled') ?? false;
  }

  Future<void> enableExperimentalPatchesStatus(bool value) async {
    await _prefs.setBool('experimentalPatchesEnabled', value);
  }

  Future<void> deleteTempFolder() async {
    final Directory dir = Directory('/data/local/tmp/revanced-manager');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<File> getKeyStoreFile() async {
    final appCache = await getTemporaryDirectory();
    final dataDir = await getExternalStorageDirectory() ?? appCache;
    return File('${dataDir.path}/revanced-manager.keystore');
  }

  Future<void> deleteKeystore() async {
    final File keystore = await getKeyStoreFile();
    if (await keystore.exists()) {
      await keystore.delete();
    }
  }

  List<PatchedApplication> getPatchedApps() {
    final List<String> apps = _prefs.getStringList('patchedApps') ?? [];
    return apps.map((a) => PatchedApplication.fromJson(jsonDecode(a))).toList();
  }

  Future<void> setPatchedApps(List<PatchedApplication> patchedApps) async {
    if (patchedApps.length > 1) {
      patchedApps.sort((a, b) => a.name.compareTo(b.name));
    }
    await _prefs.setStringList(
      'patchedApps',
      patchedApps.map((a) => json.encode(a.toJson())).toList(),
    );
  }

  Future<void> savePatchedApp(PatchedApplication app) async {
    final List<PatchedApplication> patchedApps = getPatchedApps();
    patchedApps.removeWhere((a) => a.packageName == app.packageName);
    final ApplicationWithIcon? installed = await DeviceApps.getApp(
      app.packageName,
      true,
    ) as ApplicationWithIcon?;
    if (installed != null) {
      app.name = installed.appName;
      app.version = installed.versionName!;
      app.icon = installed.icon;
    }
    patchedApps.add(app);
    await setPatchedApps(patchedApps);
  }

  Future<void> deletePatchedApp(PatchedApplication app) async {
    final List<PatchedApplication> patchedApps = getPatchedApps();
    patchedApps.removeWhere((a) => a.packageName == app.packageName);
    await setPatchedApps(patchedApps);
  }

  Future<void> clearAllData() async {
    try {
      _revancedAPI.clearAllCache();
      _githubAPI.clearAllCache();
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
    }
  }

  Future<Map<String, List<dynamic>>> getContributors() async {
    return await _revancedAPI.getContributors();
  }

  Future<List<Patch>> getPatches() async {
    try {
      final String repoName = getPatchesRepo();
      if (repoName == defaultPatchesRepo) {
        return await _revancedAPI.getPatches();
      } else {
        return await _githubAPI.getPatches(repoName);
      }
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return [];
    }
  }

  Future<File?> downloadPatches() async {
    try {
      final String repoName = getPatchesRepo();
      if (repoName == defaultPatchesRepo) {
        return await _revancedAPI.getLatestReleaseFile(
          '.jar',
          defaultPatchesRepo,
        );
      } else {
        return await _githubAPI.getLatestReleaseFile('.jar', repoName);
      }
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return null;
    }
  }

  Future<File?> downloadIntegrations() async {
    try {
      final String repoName = getIntegrationsRepo();
      if (repoName == defaultIntegrationsRepo) {
        return await _revancedAPI.getLatestReleaseFile(
          '.apk',
          defaultIntegrationsRepo,
        );
      } else {
        return await _githubAPI.getLatestReleaseFile('.apk', repoName);
      }
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return null;
    }
  }

  Future<File?> downloadManager() async {
    return await _githubAPI.getLatestReleaseFile('.apk', defaultManagerRepo);
  }

  Future<String?> getLatestPatcherReleaseTime() async {
    return await _revancedAPI.getLatestReleaseTime('.gz', defaultPatcherRepo);
  }

  Future<String?> getLatestManagerReleaseTime() async {
    return await _githubAPI.getLatestReleaseTime('.apk', defaultManagerRepo);
  }

  Future<String?> getLatestManagerVersion() async {
    return await _githubAPI.getLatestReleaseVersion(
      '.apk',
      defaultManagerRepo,
    );
  }

  Future<String?> getLatestPatchesVersion() async {
    try {
      final repoName = getPatchesRepo();
      if (repoName == defaultPatchesRepo) {
        return await _revancedAPI.getLatestReleaseVersion(
          '.json',
          defaultPatchesRepo,
        );
      } else {
        return await _githubAPI.getLatestReleaseVersion('.json', repoName);
      }
    } on Exception catch (e, s) {
      await Sentry.captureException(e, stackTrace: s);
      return null;
    }
  }

  Future<String> getCurrentManagerVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<List<PatchedApplication>> getAppsToRemove(
    List<PatchedApplication> patchedApps,
  ) async {
    final List<PatchedApplication> toRemove = [];
    for (final PatchedApplication app in patchedApps) {
      final bool isRemove = await isAppUninstalled(app);
      if (isRemove) {
        toRemove.add(app);
      }
    }
    return toRemove;
  }

  Future<List<PatchedApplication>> getUnsavedApps(
    List<PatchedApplication> patchedApps,
  ) async {
    final List<PatchedApplication> unsavedApps = [];
    final bool hasRootPermissions = await _rootAPI.hasRootPermissions();
    if (hasRootPermissions) {
      final List<String> installedApps = await _rootAPI.getInstalledApps();
      for (final String packageName in installedApps) {
        if (!patchedApps.any((app) => app.packageName == packageName)) {
          final ApplicationWithIcon? application = await DeviceApps.getApp(
            packageName,
            true,
          ) as ApplicationWithIcon?;
          if (application != null) {
            unsavedApps.add(
              PatchedApplication(
                name: application.appName,
                packageName: application.packageName,
                originalPackageName: application.packageName,
                version: application.versionName!,
                apkFilePath: application.apkFilePath,
                icon: application.icon,
                patchDate: DateTime.now(),
                isRooted: true,
              ),
            );
          }
        }
      }
    }
    final List<Application> userApps =
        await DeviceApps.getInstalledApplications();
    for (final Application app in userApps) {
      if (app.packageName.startsWith('app.revanced') &&
          !app.packageName.startsWith('app.revanced.manager.') &&
          !patchedApps.any((uapp) => uapp.packageName == app.packageName)) {
        final ApplicationWithIcon? application = await DeviceApps.getApp(
          app.packageName,
          true,
        ) as ApplicationWithIcon?;
        if (application != null) {
          unsavedApps.add(
            PatchedApplication(
              name: application.appName,
              packageName: application.packageName,
              originalPackageName: application.packageName,
              version: application.versionName!,
              apkFilePath: application.apkFilePath,
              icon: application.icon,
              patchDate: DateTime.now(),
            ),
          );
        }
      }
    }
    return unsavedApps;
  }

  Future<void> reAssessSavedApps() async {
    final List<PatchedApplication> patchedApps = getPatchedApps();
    final List<PatchedApplication> unsavedApps =
        await getUnsavedApps(patchedApps);
    patchedApps.addAll(unsavedApps);
    final List<PatchedApplication> toRemove =
        await getAppsToRemove(patchedApps);
    patchedApps.removeWhere((a) => toRemove.contains(a));
    for (final PatchedApplication app in patchedApps) {
      app.hasUpdates =
          await hasAppUpdates(app.originalPackageName, app.patchDate);
      app.changelog =
          await getAppChangelog(app.originalPackageName, app.patchDate);
      if (!app.hasUpdates) {
        final String? currentInstalledVersion =
            (await DeviceApps.getApp(app.packageName))?.versionName;
        if (currentInstalledVersion != null) {
          final String currentSavedVersion = app.version;
          final int currentInstalledVersionInt = int.parse(
            currentInstalledVersion.replaceAll(RegExp('[^0-9]'), ''),
          );
          final int currentSavedVersionInt =
              int.parse(currentSavedVersion.replaceAll(RegExp('[^0-9]'), ''));
          if (currentInstalledVersionInt > currentSavedVersionInt) {
            app.hasUpdates = true;
          }
        }
      }
    }
    await setPatchedApps(patchedApps);
  }

  Future<bool> isAppUninstalled(PatchedApplication app) async {
    bool existsRoot = false;
    final bool existsNonRoot = await DeviceApps.isAppInstalled(app.packageName);
    if (app.isRooted) {
      final bool hasRootPermissions = await _rootAPI.hasRootPermissions();
      if (hasRootPermissions) {
        existsRoot = await _rootAPI.isAppInstalled(app.packageName);
      }
      return !existsRoot || !existsNonRoot;
    }
    return !existsNonRoot;
  }

  Future<bool> hasAppUpdates(String packageName, DateTime patchDate) async {
    final List<String> commits = await _githubAPI.getCommits(
      packageName,
      getPatchesRepo(),
      patchDate,
    );
    return commits.isNotEmpty;
  }

  Future<List<String>> getAppChangelog(
    String packageName,
    DateTime patchDate,
  ) async {
    List<String> newCommits = await _githubAPI.getCommits(
      packageName,
      getPatchesRepo(),
      patchDate,
    );
    if (newCommits.isEmpty) {
      newCommits = await _githubAPI.getCommits(
        packageName,
        getPatchesRepo(),
        patchDate,
      );
    }
    return newCommits;
  }

  Future<bool> isSplitApk(PatchedApplication patchedApp) async {
    Application? app;
    if (patchedApp.isFromStorage) {
      app = await DeviceApps.getAppFromStorage(patchedApp.apkFilePath);
    } else {
      app = await DeviceApps.getApp(patchedApp.packageName);
    }
    return app != null && app.isSplit;
  }

  Future<void> setSelectedPatches(String app, List<String> patches) async {
    final File selectedPatchesFile = File(storedPatchesFile);
    final Map<String, dynamic> patchesMap = await readSelectedPatchesFile();
    if (patches.isEmpty) {
      patchesMap.remove(app);
    } else {
      patchesMap[app] = patches;
    }
    selectedPatchesFile.writeAsString(jsonEncode(patchesMap));
  }

  Future<List<String>> getSelectedPatches(String app) async {
    final Map<String, dynamic> patchesMap = await readSelectedPatchesFile();
    return List.from(patchesMap.putIfAbsent(app, () => List.empty()));
  }

  Future<Map<String, dynamic>> readSelectedPatchesFile() async {
    final File selectedPatchesFile = File(storedPatchesFile);
    if (!selectedPatchesFile.existsSync()) {
      return {};
    }
    final String string = selectedPatchesFile.readAsStringSync();
    if (string.trim().isEmpty) {
      return {};
    }
    return jsonDecode(string);
  }

  Future<void> resetLastSelectedPatches() async {
    final File selectedPatchesFile = File(storedPatchesFile);
    selectedPatchesFile.deleteSync();
  }

  bool getBasicMode() {
    return _prefs.getBool('basicMode') ?? true;
  }

  Future<void> setBasicMode(bool value) async {
    await _prefs.setBool('basicMode', value);
  }

  Future<bool> isVancedMicroGInstalled() async {
    return await DeviceApps.isAppInstalled(vancedMicroGPackageName);
  }

  Future<GithubLatestRelease?> getVancedMicroGLatestRelease() async {
    if (_vancedMicroGLatestRelease == null) {
      final vancedMicroGRepo = getMicroGRepo();
      _vancedMicroGLatestRelease =
          await _githubAPI.getLatestRelease(vancedMicroGRepo);
    }

    return _vancedMicroGLatestRelease;
  }

  Future<bool> hasUpdatedVancedMicroG() async {
    final app = await DeviceApps.getApp(vancedMicroGPackageName);
    final vancedMicroGLatestRelease = await getVancedMicroGLatestRelease();
    final version = vancedMicroGLatestRelease?.tagName;
    if (app != null &&
        version != null &&
        version.contains(app.versionName ?? '')) {
      return false;
    }

    if (version == null) {
      return false;
    }

    return true;
  }

  Future<bool> installVancedMicroG() async {
    final isInstall = await isVancedMicroGInstalled();
    if (!isInstall) {
      final vancedMicroGLatestRelease = await getVancedMicroGLatestRelease();
      final vancedMicroGAsset = vancedMicroGLatestRelease?.assets
          .firstWhereOrNull((element) => element.name.endsWith('apk'));
      if (vancedMicroGAsset != null) {
        final vancedMicroGFile = await DefaultCacheManager().getSingleFile(
          vancedMicroGAsset.browserDownloadUrl,
        );
        await AppInstaller.installApk(vancedMicroGFile.path);
        return true;
      }
    }
    return false;
  }

  Future<String?> getLatestVancedMicroGVersion() async {
    final vancedMicroGLatestRelease = await getVancedMicroGLatestRelease();
    return vancedMicroGLatestRelease?.tagName;
  }
}
