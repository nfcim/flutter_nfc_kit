package im.nfc.flutter_nfc_kit;

import android.nfc.tech.IsoDep;

import com.github.devnied.emvnfccard.exception.CommunicationException;
import com.github.devnied.emvnfccard.parser.IProvider;

import java.io.IOException;

public class Provider  implements IProvider {

  private final IsoDep isoDep;

  public Provider(final IsoDep isoDep) {
    this.isoDep = isoDep;
  }

  @Override
  public byte[] transceive(final byte[] pCommand) throws CommunicationException {

    byte[] response;

    if (isoDep == null) {
      response = new byte[0];

      return  response;
    }

    try {
      // send command to emv card
      response = isoDep.transceive(pCommand);
    } catch (IOException e) {
      throw new CommunicationException(e.getMessage());
    }

    return response;
  }

  @Override
  public byte[] getAt() {
    // For NFC-A
    return isoDep.getHistoricalBytes();
    // For NFC-B
    // return mTagCom.getHiLayerResponse();
  }
}
