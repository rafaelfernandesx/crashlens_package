/// Informações do dispositivo coletadas no momento do erro
class DeviceInfoData {
  final String? deviceName;
  final String? deviceModel;
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

  DeviceInfoData({
    this.deviceName,
    this.deviceModel,
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
  });

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        'deviceModel': deviceModel,
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
      };

  factory DeviceInfoData.fromJson(Map<String, dynamic> json) =>
      DeviceInfoData(
        deviceName: json['deviceName'] as String?,
        deviceModel: json['deviceModel'] as String?,
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
      );
}
