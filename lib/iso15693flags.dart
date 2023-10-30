import 'dart:ffi';

class Iso15693RequestFlag {
  /// bit 1
  bool dualSubCarriers;

  /// bit 2
  bool highDataRate;

  /// bit 3
  bool inventory;

  /// bit 4
  bool protocolExtension;

  /// bit 5
  bool select;

  /// bit 6
  bool address;

  /// bit 7
  bool option;

  /// bit 8
  bool commandSpecificBit8;

  /// encode bits to one byte as specified in ISO15693-3
  Uint8 encode() {
    var result = 0;
    if (dualSubCarriers) {
      result |= 0x01;
    }
    if (highDataRate) {
      result |= 0x02;
    }
    if (inventory) {
      result |= 0x04;
    }
    if (protocolExtension) {
      result |= 0x08;
    }
    if (select) {
      result |= 0x10;
    }
    if (address) {
      result |= 0x20;
    }
    if (option) {
      result |= 0x40;
    }
    if (commandSpecificBit8) {
      result |= 0x80;
    }
    return result as Uint8;
  }

  Iso15693RequestFlag(
      {this.dualSubCarriers = false,
      this.highDataRate = false,
      this.inventory = false,
      this.protocolExtension = false,
      this.select = false,
      this.address = false,
      this.option = false,
      this.commandSpecificBit8 = false});

  /// decode bits from one byte as specified in ISO15693-3
  factory Iso15693RequestFlag.fromRaw(Uint8 raw) {
    var r = raw as int;
    var f = Iso15693RequestFlag(
        dualSubCarriers: (r & 0x01) != 0,
        highDataRate: (r & 0x02) != 0,
        inventory: (r & 0x04) != 0,
        protocolExtension: (r & 0x08) != 0,
        select: (r & 0x10) != 0,
        address: (r & 0x20) != 0,
        option: (r & 0x40) != 0,
        commandSpecificBit8: (r & 0x80) != 0);
    return f;
  }
}
