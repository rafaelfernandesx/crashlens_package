/// Informações específicas da plataforma
class PlatformDeviceInfo {
  final AndroidPlatformInfo? android;
  final IosPlatformInfo? ios;
  final LinuxPlatformInfo? linux;
  final MacOsPlatformInfo? macos;
  final WindowsPlatformInfo? windows;
  final WebPlatformInfo? web;

  PlatformDeviceInfo({
    this.android,
    this.ios,
    this.linux,
    this.macos,
    this.windows,
    this.web,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (android != null) map['android'] = android!.toJson();
    if (ios != null) map['ios'] = ios!.toJson();
    if (linux != null) map['linux'] = linux!.toJson();
    if (macos != null) map['macos'] = macos!.toJson();
    if (windows != null) map['windows'] = windows!.toJson();
    if (web != null) map['web'] = web!.toJson();
    return map;
  }

  factory PlatformDeviceInfo.fromJson(Map<String, dynamic> json) {
    return PlatformDeviceInfo(
      android: json['android'] != null ? AndroidPlatformInfo.fromJson(json['android']) : null,
      ios: json['ios'] != null ? IosPlatformInfo.fromJson(json['ios']) : null,
      linux: json['linux'] != null ? LinuxPlatformInfo.fromJson(json['linux']) : null,
      macos: json['macos'] != null ? MacOsPlatformInfo.fromJson(json['macos']) : null,
      windows: json['windows'] != null ? WindowsPlatformInfo.fromJson(json['windows']) : null,
      web: json['web'] != null ? WebPlatformInfo.fromJson(json['web']) : null,
    );
  }
}

/// Informações específicas do Android
class AndroidPlatformInfo {
  final String? brand;
  final String? model;
  final String? manufacturer;
  final String? deviceName;
  final String? product;
  final String? board;
  final String? hardware;
  final String? supportedAbis;
  final String? bootloader;
  final String? display;
  final String? fingerprint;
  final String? host;
  final String? buildId;
  final String? tags;
  final String? type;
  final String? osVersion;
  final int? sdkInt;
  final String? securityPatch;
  final String? codename;
  final bool? isPhysicalDevice;
  final bool? isLowRamDevice;
  final String? systemFeatures;
  final int? freeDiskSize;
  final int? totalDiskSize;
  final int? physicalRamSize;
  final int? availableRamSize;

  AndroidPlatformInfo({
    this.brand,
    this.model,
    this.manufacturer,
    this.deviceName,
    this.product,
    this.board,
    this.hardware,
    this.supportedAbis,
    this.bootloader,
    this.display,
    this.fingerprint,
    this.host,
    this.buildId,
    this.tags,
    this.type,
    this.osVersion,
    this.sdkInt,
    this.securityPatch,
    this.codename,
    this.isPhysicalDevice,
    this.isLowRamDevice,
    this.systemFeatures,
    this.freeDiskSize,
    this.totalDiskSize,
    this.physicalRamSize,
    this.availableRamSize,
  });

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'model': model,
        'manufacturer': manufacturer,
        'deviceName': deviceName,
        'product': product,
        'board': board,
        'hardware': hardware,
        'supportedAbis': supportedAbis,
        'bootloader': bootloader,
        'display': display,
        'fingerprint': fingerprint,
        'host': host,
        'buildId': buildId,
        'tags': tags,
        'type': type,
        'osVersion': osVersion,
        'sdkInt': sdkInt,
        'securityPatch': securityPatch,
        'codename': codename,
        'isPhysicalDevice': isPhysicalDevice,
        'isLowRamDevice': isLowRamDevice,
        'systemFeatures': systemFeatures,
        'freeDiskSize': freeDiskSize,
        'totalDiskSize': totalDiskSize,
        'physicalRamSize': physicalRamSize,
        'availableRamSize': availableRamSize,
      };

  factory AndroidPlatformInfo.fromJson(Map<String, dynamic> json) {
    return AndroidPlatformInfo(
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      manufacturer: json['manufacturer'] as String?,
      deviceName: json['deviceName'] as String?,
      product: json['product'] as String?,
      board: json['board'] as String?,
      hardware: json['hardware'] as String?,
      supportedAbis: json['supportedAbis'] as String?,
      bootloader: json['bootloader'] as String?,
      display: json['display'] as String?,
      fingerprint: json['fingerprint'] as String?,
      host: json['host'] as String?,
      buildId: json['buildId'] as String?,
      tags: json['tags'] as String?,
      type: json['type'] as String?,
      osVersion: json['osVersion'] as String?,
      sdkInt: json['sdkInt'] as int?,
      securityPatch: json['securityPatch'] as String?,
      codename: json['codename'] as String?,
      isPhysicalDevice: json['isPhysicalDevice'] as bool?,
      isLowRamDevice: json['isLowRamDevice'] as bool?,
      systemFeatures: json['systemFeatures'] as String?,
      freeDiskSize: json['freeDiskSize'] as int?,
      totalDiskSize: json['totalDiskSize'] as int?,
      physicalRamSize: json['physicalRamSize'] as int?,
      availableRamSize: json['availableRamSize'] as int?,
    );
  }
}

/// Informações específicas do iOS
class IosPlatformInfo {
  final String? name;
  final String? systemName;
  final String? systemVersion;
  final String? model;
  final String? modelName;
  final String? localizedModel;
  final String? identifierForVendor;
  final bool? isPhysicalDevice;
  final bool? isiOSAppOnMac;
  final bool? isiOSAppOnVision;
  final String? utsnameSysname;
  final String? utsnameNodename;
  final String? utsnameRelease;
  final String? utsnameVersion;
  final String? utsnameMachine;
  final int? freeDiskSize;
  final int? totalDiskSize;
  final int? physicalRamSize;
  final int? availableRamSize;

  IosPlatformInfo({
    this.name,
    this.systemName,
    this.systemVersion,
    this.model,
    this.modelName,
    this.localizedModel,
    this.identifierForVendor,
    this.isPhysicalDevice,
    this.isiOSAppOnMac,
    this.isiOSAppOnVision,
    this.utsnameSysname,
    this.utsnameNodename,
    this.utsnameRelease,
    this.utsnameVersion,
    this.utsnameMachine,
    this.freeDiskSize,
    this.totalDiskSize,
    this.physicalRamSize,
    this.availableRamSize,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'systemName': systemName,
        'systemVersion': systemVersion,
        'model': model,
        'modelName': modelName,
        'localizedModel': localizedModel,
        'identifierForVendor': identifierForVendor,
        'isPhysicalDevice': isPhysicalDevice,
        'isiOSAppOnMac': isiOSAppOnMac,
        'isiOSAppOnVision': isiOSAppOnVision,
        'utsnameSysname': utsnameSysname,
        'utsnameNodename': utsnameNodename,
        'utsnameRelease': utsnameRelease,
        'utsnameVersion': utsnameVersion,
        'utsnameMachine': utsnameMachine,
        'freeDiskSize': freeDiskSize,
        'totalDiskSize': totalDiskSize,
        'physicalRamSize': physicalRamSize,
        'availableRamSize': availableRamSize,
      };

  factory IosPlatformInfo.fromJson(Map<String, dynamic> json) {
    return IosPlatformInfo(
      name: json['name'] as String?,
      systemName: json['systemName'] as String?,
      systemVersion: json['systemVersion'] as String?,
      model: json['model'] as String?,
      modelName: json['modelName'] as String?,
      localizedModel: json['localizedModel'] as String?,
      identifierForVendor: json['identifierForVendor'] as String?,
      isPhysicalDevice: json['isPhysicalDevice'] as bool?,
      isiOSAppOnMac: json['isiOSAppOnMac'] as bool?,
      isiOSAppOnVision: json['isiOSAppOnVision'] as bool?,
      utsnameSysname: json['utsnameSysname'] as String?,
      utsnameNodename: json['utsnameNodename'] as String?,
      utsnameRelease: json['utsnameRelease'] as String?,
      utsnameVersion: json['utsnameVersion'] as String?,
      utsnameMachine: json['utsnameMachine'] as String?,
      freeDiskSize: json['freeDiskSize'] as int?,
      totalDiskSize: json['totalDiskSize'] as int?,
      physicalRamSize: json['physicalRamSize'] as int?,
      availableRamSize: json['availableRamSize'] as int?,
    );
  }
}

/// Informações específicas do Linux
class LinuxPlatformInfo {
  final String? name;
  final String? prettyName;
  final String? distroId;
  final String? idLike;
  final String? version;
  final String? versionId;
  final String? versionCodename;
  final String? buildId;
  final String? variant;
  final String? variantId;
  final String? machineId;

  LinuxPlatformInfo({
    this.name,
    this.prettyName,
    this.distroId,
    this.idLike,
    this.version,
    this.versionId,
    this.versionCodename,
    this.buildId,
    this.variant,
    this.variantId,
    this.machineId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'prettyName': prettyName,
        'distroId': distroId,
        'idLike': idLike,
        'version': version,
        'versionId': versionId,
        'versionCodename': versionCodename,
        'buildId': buildId,
        'variant': variant,
        'variantId': variantId,
        'machineId': machineId,
      };

  factory LinuxPlatformInfo.fromJson(Map<String, dynamic> json) {
    return LinuxPlatformInfo(
      name: json['name'] as String?,
      prettyName: json['prettyName'] as String?,
      distroId: json['distroId'] as String?,
      idLike: json['idLike'] as String?,
      version: json['version'] as String?,
      versionId: json['versionId'] as String?,
      versionCodename: json['versionCodename'] as String?,
      buildId: json['buildId'] as String?,
      variant: json['variant'] as String?,
      variantId: json['variantId'] as String?,
      machineId: json['machineId'] as String?,
    );
  }
}

/// Informações específicas do macOS
class MacOsPlatformInfo {
  final String? computerName;
  final String? hostName;
  final String? model;
  final String? modelName;
  final String? arch;
  final String? kernelVersion;
  final String? osRelease;
  final int? majorVersion;
  final int? minorVersion;
  final int? patchVersion;
  final int? activeCPUs;
  final int? memorySize;
  final int? cpuFrequency;
  final String? systemGUID;

  MacOsPlatformInfo({
    this.computerName,
    this.hostName,
    this.model,
    this.modelName,
    this.arch,
    this.kernelVersion,
    this.osRelease,
    this.majorVersion,
    this.minorVersion,
    this.patchVersion,
    this.activeCPUs,
    this.memorySize,
    this.cpuFrequency,
    this.systemGUID,
  });

  Map<String, dynamic> toJson() => {
        'computerName': computerName,
        'hostName': hostName,
        'model': model,
        'modelName': modelName,
        'arch': arch,
        'kernelVersion': kernelVersion,
        'osRelease': osRelease,
        'majorVersion': majorVersion,
        'minorVersion': minorVersion,
        'patchVersion': patchVersion,
        'activeCPUs': activeCPUs,
        'memorySize': memorySize,
        'cpuFrequency': cpuFrequency,
        'systemGUID': systemGUID,
      };

  factory MacOsPlatformInfo.fromJson(Map<String, dynamic> json) {
    return MacOsPlatformInfo(
      computerName: json['computerName'] as String?,
      hostName: json['hostName'] as String?,
      model: json['model'] as String?,
      modelName: json['modelName'] as String?,
      arch: json['arch'] as String?,
      kernelVersion: json['kernelVersion'] as String?,
      osRelease: json['osRelease'] as String?,
      majorVersion: json['majorVersion'] as int?,
      minorVersion: json['minorVersion'] as int?,
      patchVersion: json['patchVersion'] as int?,
      activeCPUs: json['activeCPUs'] as int?,
      memorySize: json['memorySize'] as int?,
      cpuFrequency: json['cpuFrequency'] as int?,
      systemGUID: json['systemGUID'] as String?,
    );
  }
}

/// Informações específicas do Windows
class WindowsPlatformInfo {
  final String? computerName;
  final String? userName;
  final String? productName;
  final String? editionId;
  final String? displayVersion;
  final String? releaseId;
  final String? productId;
  final int? majorVersion;
  final int? minorVersion;
  final int? buildNumber;
  final int? platformId;
  final String? csdVersion;
  final int? servicePackMajor;
  final int? servicePackMinor;
  final int? numberOfCores;
  final int? systemMemoryInMegabytes;
  final int? productType;
  final int? suitMask;
  final String? buildLab;
  final String? buildLabEx;
  final String? windowsDeviceId;
  final String? registeredOwner;
  final String? installDate;

  WindowsPlatformInfo({
    this.computerName,
    this.userName,
    this.productName,
    this.editionId,
    this.displayVersion,
    this.releaseId,
    this.productId,
    this.majorVersion,
    this.minorVersion,
    this.buildNumber,
    this.platformId,
    this.csdVersion,
    this.servicePackMajor,
    this.servicePackMinor,
    this.numberOfCores,
    this.systemMemoryInMegabytes,
    this.productType,
    this.suitMask,
    this.buildLab,
    this.buildLabEx,
    this.windowsDeviceId,
    this.registeredOwner,
    this.installDate,
  });

  Map<String, dynamic> toJson() => {
        'computerName': computerName,
        'userName': userName,
        'productName': productName,
        'editionId': editionId,
        'displayVersion': displayVersion,
        'releaseId': releaseId,
        'productId': productId,
        'majorVersion': majorVersion,
        'minorVersion': minorVersion,
        'buildNumber': buildNumber,
        'platformId': platformId,
        'csdVersion': csdVersion,
        'servicePackMajor': servicePackMajor,
        'servicePackMinor': servicePackMinor,
        'numberOfCores': numberOfCores,
        'systemMemoryInMegabytes': systemMemoryInMegabytes,
        'productType': productType,
        'suitMask': suitMask,
        'buildLab': buildLab,
        'buildLabEx': buildLabEx,
        'windowsDeviceId': windowsDeviceId,
        'registeredOwner': registeredOwner,
        'installDate': installDate,
      };

  factory WindowsPlatformInfo.fromJson(Map<String, dynamic> json) {
    return WindowsPlatformInfo(
      computerName: json['computerName'] as String?,
      userName: json['userName'] as String?,
      productName: json['productName'] as String?,
      editionId: json['editionId'] as String?,
      displayVersion: json['displayVersion'] as String?,
      releaseId: json['releaseId'] as String?,
      productId: json['productId'] as String?,
      majorVersion: json['majorVersion'] as int?,
      minorVersion: json['minorVersion'] as int?,
      buildNumber: json['buildNumber'] as int?,
      platformId: json['platformId'] as int?,
      csdVersion: json['csdVersion'] as String?,
      servicePackMajor: json['servicePackMajor'] as int?,
      servicePackMinor: json['servicePackMinor'] as int?,
      numberOfCores: json['numberOfCores'] as int?,
      systemMemoryInMegabytes: json['systemMemoryInMegabytes'] as int?,
      productType: json['productType'] as int?,
      suitMask: json['suitMask'] as int?,
      buildLab: json['buildLab'] as String?,
      buildLabEx: json['buildLabEx'] as String?,
      windowsDeviceId: json['windowsDeviceId'] as String?,
      registeredOwner: json['registeredOwner'] as String?,
      installDate: json['installDate'] as String?,
    );
  }
}

/// Informações específicas do Web
class WebPlatformInfo {
  final String? browserName;
  final String? appName;
  final String? appVersion;
  final String? appCodeName;
  final String? userAgent;
  final String? vendor;
  final String? vendorSub;
  final String? product;
  final String? productSub;
  final String? platform;
  final String? language;
  final String? languages;
  final double? deviceMemory;
  final int? hardwareConcurrency;
  final int? maxTouchPoints;

  WebPlatformInfo({
    this.browserName,
    this.appName,
    this.appVersion,
    this.appCodeName,
    this.userAgent,
    this.vendor,
    this.vendorSub,
    this.product,
    this.productSub,
    this.platform,
    this.language,
    this.languages,
    this.deviceMemory,
    this.hardwareConcurrency,
    this.maxTouchPoints,
  });

  Map<String, dynamic> toJson() => {
        'browserName': browserName,
        'appName': appName,
        'appVersion': appVersion,
        'appCodeName': appCodeName,
        'userAgent': userAgent,
        'vendor': vendor,
        'vendorSub': vendorSub,
        'product': product,
        'productSub': productSub,
        'platform': platform,
        'language': language,
        'languages': languages,
        'deviceMemory': deviceMemory,
        'hardwareConcurrency': hardwareConcurrency,
        'maxTouchPoints': maxTouchPoints,
      };

  factory WebPlatformInfo.fromJson(Map<String, dynamic> json) {
    return WebPlatformInfo(
      browserName: json['browserName'] as String?,
      appName: json['appName'] as String?,
      appVersion: json['appVersion'] as String?,
      appCodeName: json['appCodeName'] as String?,
      userAgent: json['userAgent'] as String?,
      vendor: json['vendor'] as String?,
      vendorSub: json['vendorSub'] as String?,
      product: json['product'] as String?,
      productSub: json['productSub'] as String?,
      platform: json['platform'] as String?,
      language: json['language'] as String?,
      languages: json['languages'] as String?,
      deviceMemory: (json['deviceMemory'] as num?)?.toDouble(),
      hardwareConcurrency: json['hardwareConcurrency'] as int?,
      maxTouchPoints: json['maxTouchPoints'] as int?,
    );
  }
}
