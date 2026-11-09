package com.basivo.fit

import android.bluetooth.BluetoothManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Small Bluetooth bridge for things flutter_reactive_ble does not do:
 * secure pairing (bonding) with a heart rate band, and clearing a stuck pairing.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "basivo/ble")
            .setMethodCallHandler { call, result ->
                try {
                    val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("args", "Missing device id", null)
                        return@setMethodCallHandler
                    }
                    val device = manager.adapter.getRemoteDevice(id)
                    when (call.method) {
                        // 10 = not paired, 11 = pairing, 12 = paired
                        "bondState" -> result.success(device.bondState)
                        // Pair over Bluetooth Low Energy: the default can pick
                        // classic Bluetooth for a band with a random address.
                        "createBond" -> {
                            val ok = try {
                                val m = device.javaClass.getMethod(
                                    "createBond",
                                    Int::class.javaPrimitiveType,
                                )
                                m.invoke(device, 2 /* TRANSPORT_LE */) as Boolean
                            } catch (e: Exception) {
                                device.createBond()
                            }
                            result.success(ok)
                        }
                        // Plain Android pairing, used if the LE request does not take.
                        "createBondDefault" -> result.success(device.createBond())
                        "removeBond" -> {
                            val m = device.javaClass.getMethod("removeBond")
                            result.success(m.invoke(device) as Boolean)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: SecurityException) {
                    result.error("permission", e.message, null)
                } catch (e: Exception) {
                    result.error("error", e.message, null)
                }
            }
    }
}
