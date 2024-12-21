package im.nfc.flutter_nfc_kit.example

import android.app.PendingIntent
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import io.flutter.embedding.android.FlutterActivity
import im.nfc.flutter_nfc_kit.FlutterNfcKitPlugin

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(this)
        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this, 0, Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_MUTABLE
        )
        // Read the docs for reading specific technologies
        adapter?.enableForegroundDispatch(this, pendingIntent, null, null)
    }

    override fun onPause() {
        super.onPause()
        val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(this)
        adapter?.disableForegroundDispatch(this)
    }

    override fun onNewIntent(intent: Intent) {
        val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        tag?.apply(FlutterNfcKitPlugin::handleTag)
    }
}
