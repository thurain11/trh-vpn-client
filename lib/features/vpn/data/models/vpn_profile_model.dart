import '../../domain/entities/vpn_profile.dart';

class VpnProfileModel extends VpnProfile {
  const VpnProfileModel({
    required super.id,
    required super.name,
    required super.endpoint,
    required super.protocol,
    required super.rawConfig,
    required super.source,
    super.credentials,
    super.transport,
    super.subscriptionId,
    super.remarks,
    super.isSecureDnsEnabled,
  });

  factory VpnProfileModel.fromEntity(VpnProfile profile) {
    return VpnProfileModel(
      id: profile.id,
      name: profile.name,
      endpoint: profile.endpoint,
      protocol: profile.protocol,
      rawConfig: profile.rawConfig,
      source: profile.source,
      credentials: profile.credentials,
      transport: profile.transport,
      subscriptionId: profile.subscriptionId,
      remarks: profile.remarks,
      isSecureDnsEnabled: profile.isSecureDnsEnabled,
    );
  }

  VpnProfile toEntity() {
    return VpnProfile(
      id: id,
      name: name,
      endpoint: endpoint,
      protocol: protocol,
      rawConfig: rawConfig,
      source: source,
      credentials: credentials,
      transport: transport,
      subscriptionId: subscriptionId,
      remarks: remarks,
      isSecureDnsEnabled: isSecureDnsEnabled,
    );
  }
}
