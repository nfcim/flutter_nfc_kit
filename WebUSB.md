# WebUSB Protocol

## Overview

Since NFC is inaccessible on the web, applications targeted on dual interfaces (NFC and USB)
may use the following protocol to communicate with the WebUSB on Chromium-based web browsers.

The communication is based on the Control Transfer. The interface with index 1 is used.

Note: you **need to implement this protocol on your own USB device** before communicating with it using the web version of FlutterNfcKit.

Currently, the following devices adopt this protocol:

* [CanoKey](https://www.canokeys.org/)

## Messages

Basically, the messages on the WebUSB interface are APDU commands.
To transceive a pair of APDU commands, two phases are required:

1. Send a command APDU
2. Get the response APDU

Each type of message is a vendor-specific request, defined as:

| bRequest | Value |
| -------- | ----- |
| CMD      | 00h   |
| RESP     | 01h   |
| STAT     | 02h   |
| PROBE    | FFh   |

1. Probe device

The following control pipe request is used to probe whether the device supports this protocol.

| bmRequestType | bRequest | wValue | wIndex | wLength | Data |
| ------------- | -------- | ------ | ------ | ------- | ---- |
| 11000001B     | PROBE    | 0000h  | 1      | 0       | N/A  |

The response data **MUST** begin with magic bytes `0x5f4e46435f494d5f` (`_NFC_IM_`) in order to be recognized.
The remaining bytes can be used as custom information provided by the device.

2. Send command APDU

The following control pipe request is used to send a command APDU.

| bmRequestType | bRequest | wValue | wIndex | wLength        | Data  |
| ------------- | -------- | ------ | ------ | -------------- | ----- |
| 01000001B     | CMD      | 0000h  | 1      | length of data | bytes |

3. Get execution status

The following control pipe request is used to get the status of the device.

| bmRequestType | bRequest | wValue | wIndex | wLength | Data |
| ------------- | -------- | ------ | ------ | ------- | ---- |
| 11000001B     | STAT     | 0000h  | 1      | 0       | N/A  |

The response data is 1-byte long, `0x01` for in progress and `0x00` for finishing processing,
and you can fetch the result using `RESP` command, and other values for invalid states.

If the command is still under processing, the response will be empty.

4. Get response APDU

The following control pipe request is used to get the response APDU.

| bmRequestType | bRequest | wValue | wIndex | wLength | Data |
| ------------- | -------- | ------ | ------ | ------- | ---- |
| 11000001B     | RESP     | 0000h  | 1      | 0       | N/A  |

The device will send the response no more than 1500 bytes.
