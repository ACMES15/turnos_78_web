package com.liverpool.turnos78;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.os.Build;
import android.Manifest;
import android.content.pm.PackageManager;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.io.IOException;
import java.io.OutputStream;
import java.util.UUID;

public class MainActivity extends FlutterActivity {
	private static final String CHANNEL = "com.liverpool.turnos78/rfcomm";
	private static final String TAG = "TurnosRfcomm";
	private static final UUID SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

	@Override
	public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
				.setMethodCallHandler((call, result) -> {
					if (call.method.equals("sendZpl")) {
						String address = call.argument("address");
						String zpl = call.argument("zpl");
						Log.d(TAG, "MethodChannel sendZpl requested for " + address);
						boolean sent = sendZplToAddress(address, zpl);
						Log.d(TAG, "sendZpl result: " + sent);
						result.success(sent);
					} else {
						result.notImplemented();
					}
				});
	}

	private boolean hasBluetoothPermission() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			return checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED;
		}
		return true;
	}

	private boolean sendZplToAddress(String address, String zpl) {
		BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
		if (adapter == null) {
			Log.e(TAG, "No Bluetooth adapter");
			return false;
		}
		if (!hasBluetoothPermission()) {
			Log.e(TAG, "Missing BLUETOOTH_CONNECT permission");
			return false;
		}
		BluetoothDevice device = adapter.getRemoteDevice(address);
		BluetoothSocket socket = null;
		try {
			// Intentar socket seguro primero
			try {
				Log.d(TAG, "Trying createRfcommSocketToServiceRecord");
				socket = device.createRfcommSocketToServiceRecord(SPP_UUID);
			} catch (Exception ex) {
				Log.w(TAG, "secure socket failed, will try insecure: " + ex.getMessage());
			}

			// Si no se creó, intentar socket inseguro
			if (socket == null) {
				try {
					Log.d(TAG, "Trying createInsecureRfcommSocketToServiceRecord");
					socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID);
				} catch (Exception ex) {
					Log.w(TAG, "insecure socket failed: " + ex.getMessage());
				}
			}

			// Fallback por reflexión si aún es null
			if (socket == null) {
				try {
					Log.d(TAG, "Trying reflection fallback createRfcommSocket(int)");
					java.lang.reflect.Method m = device.getClass().getMethod("createRfcommSocket", new Class[]{int.class});
					socket = (BluetoothSocket) m.invoke(device, 1);
				} catch (Exception ex) {
					Log.e(TAG, "reflection fallback failed: " + ex.getMessage());
				}
			}

			if (socket == null) {
				Log.e(TAG, "Could not create Bluetooth socket");
				return false;
			}

			adapter.cancelDiscovery();
			Log.d(TAG, "Connecting socket...");
			socket.connect();
			Log.d(TAG, "Socket connected");

			// Esperar un momento para estabilizar la conexión
			try { Thread.sleep(150); } catch (InterruptedException ignored) {}

			OutputStream out = socket.getOutputStream();
			byte[] bytes = zpl.getBytes("UTF-8");
			// Añadir terminador por si la impresora lo requiere
			byte[] terminator = new byte[]{0x0D, 0x0A};
			byte[] toSend = new byte[bytes.length + terminator.length];
			System.arraycopy(bytes, 0, toSend, 0, bytes.length);
			System.arraycopy(terminator, 0, toSend, bytes.length, terminator.length);

			out.write(toSend);
			out.flush();
			Log.d(TAG, "Wrote " + toSend.length + " bytes to printer");

			try { out.close(); } catch (IOException ignored) {}
			try { socket.close(); } catch (IOException ignored) {}
			return true;
		} catch (IOException e) {
			Log.e(TAG, "IOException during send: " + e.getMessage(), e);
			try {
				if (socket != null) socket.close();
			} catch (IOException ignored) {}
			return false;
		}
	}
}
