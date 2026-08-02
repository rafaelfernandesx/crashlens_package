import 'platform_device_info.dart';

/// Informações do dispositivo coletadas no momento do erro
class DeviceInfoData {
  /// ID único do dispositivo (ANDROID_ID, IDFV, UUID, etc.)
  /// Vincula eventos ao registro Device no backend
  final String? deviceId;
  final String? deviceName;
  final String? deviceModel;
  /// Fabricante do dispositivo (ex: "Apple", "Samsung", "Google")
  final String? deviceManufacturer;
  final String? deviceOs;
  final String? osVersion;
  final String? deviceType;
  final String? screenResolution;
  final String? locale;
  final String? timezone;
  final bool? isPhysicalDevice;
  final String? cpuArchitecture;
  final int? totalMemoryMb;
  final String? appVersion;
  final String? buildNumber;
  
  /// Informações específicas da plataforma (Android, iOS, Windows, macOS, Linux, Web)
  final PlatformDeviceInfo? platformInfo;

  DeviceInfoData({
    this.deviceId,
    this.deviceName,
    this.deviceModel,
    this.deviceManufacturer,
    this.deviceOs,
    this.osVersion,
    this.deviceType,
    this.screenResolution,
    this.locale,
    this.timezone,
    this.isPhysicalDevice,
    this.cpuArchitecture,
    this.totalMemoryMb,
    this.appVersion,
    this.buildNumber,
    this.platformInfo,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'deviceModel': deviceModel,
        'deviceManufacturer': deviceManufacturer,
        'deviceOs': deviceOs,
        'osVersion': osVersion,
        'deviceType': deviceType,
        'screenResolution': screenResolution,
        'locale': locale,
        'timezone': timezone,
        'isPhysicalDevice': isPhysicalDevice,
        'cpuArchitecture': cpuArchitecture,
        'totalMemoryMb': totalMemoryMb,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'platformInfo': platformInfo?.toJson(),
      };

  factory DeviceInfoData.fromJson(Map<String, dynamic> json) =>
      DeviceInfoData(
        deviceId: json['deviceId'] as String?,
        deviceName: json['deviceName'] as String?,
        deviceModel: json['deviceModel'] as String?,
        deviceManufacturer: json['deviceManufacturer'] as String?,
        deviceOs: json['deviceOs'] as String?,
        osVersion: json['osVersion'] as String?,
        deviceType: json['deviceType'] as String?,
        screenResolution: json['screenResolution'] as String?,
        locale: json['locale'] as String?,
        timezone: json['timezone'] as String?,
        isPhysicalDevice: json['isPhysicalDevice'] as bool?,
        cpuArchitecture: json['cpuArchitecture'] as String?,
        totalMemoryMb: json['totalMemoryMb'] as int?,
        appVersion: json['appVersion'] as String?,
        buildNumber: json['buildNumber'] as String?,
        platformInfo: json['platformInfo'] != null 
            ? PlatformDeviceInfo.fromJson(json['platformInfo'] as Map<String, dynamic>)
            : null,
      );
}
