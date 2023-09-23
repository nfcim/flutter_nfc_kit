/// Represents RequestFlag on iOS.
enum Iso15693RequestFlag {
  /// Indicates RequestFlag#address on iOS.
  address,

  /// Indicates RequestFlag#dualSubCarriers on iOS.
  dualSubCarriers,

  /// Indicates RequestFlag#highDataRate on iOS.
  highDataRate,

  /// Indicates RequestFlag#option on iOS.
  option,

  /// Indicates RequestFlag#protocolExtension on iOS.
  protocolExtension,

  /// Indicates RequestFlag#select on iOS.
  select,
}

const Map<Iso15693RequestFlag, String> $Iso15693RequestFlagTable = {
  Iso15693RequestFlag.address: 'address',
  Iso15693RequestFlag.dualSubCarriers: 'dualSubCarriers',
  Iso15693RequestFlag.highDataRate: 'highDataRate',
  Iso15693RequestFlag.option: 'option',
  Iso15693RequestFlag.protocolExtension: 'protocolExtension',
  Iso15693RequestFlag.select: 'select',
};
