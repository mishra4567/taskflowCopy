// android/app/src/main/kotlin/com/example/taskflow/MainActivity.kt
package com.example.taskflow

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException

/**
 * Backs the "taskflow/ringtone" MethodChannel used by
 * lib/services/alarm_sound_service.dart. Calls:
 *   import(path, name)  -> copies a picked audio file into the
 *                           Alarms/TaskFlow MediaStore collection and
 *                           returns its content:// uri (as a String).
 *   delete(uri)          -> removes a previously-imported file.
 *   exists(uri)          -> true if the uri can still be opened. Saved
 *                           sound uris can outlive the MediaStore row
 *                           behind them (backup restore after a
 *                           reinstall, Files-app delete, OEM media
 *                           cleanup), and a dead uri fails later with
 *                           "FileNotFoundException: No item at ...".
 *   preview(uri)          -> plays a short preview of a sound (default or
 *                           imported) on the alarm audio stream.
 *   stopPreview()         -> stops whatever preview is currently playing.
 *   pickSystemRingtone()  -> opens the phone's own ringtone picker.
 *
 * Using MediaStore.Audio (scoped storage, Android 10/API 29+) rather than
 * raw file paths is what lets a plain notification channel's `sound`
 * point at a user-uploaded file at all — a channel can only play a sound
 * the system's media framework can resolve a Uri for, and a file sitting
 * in this app's private storage doesn't qualify.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "taskflow/ringtone"
    private var previewPlayer: MediaPlayer? = null

    // The system ringtone picker is a separate Activity, so unlike every
    // other call on this channel it can't return synchronously — the
    // pending Flutter `result` gets parked here and resolved later, from
    // onActivityResult, once the person has actually picked something
    // (or backed out).
    private var pendingRingtoneResult: MethodChannel.Result? = null
    private val ringtonePickerRequestCode = 4201

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "import" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name") ?: "Custom alarm"
                        if (path == null) {
                            result.error("bad_args", "Missing path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(importRingtone(path, name))
                        } catch (e: Exception) {
                            result.error("import_failed", e.message, null)
                        }
                    }

                    "delete" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("bad_args", "Missing uri", null)
                            return@setMethodCallHandler
                        }
                        try {
                            contentResolver.delete(Uri.parse(uri), null, null)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("delete_failed", e.message, null)
                        }
                    }

                    "exists" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(uriExists(uri))
                    }

                    "preview" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("bad_args", "Missing uri", null)
                            return@setMethodCallHandler
                        }
                        try {
                            playPreview(uri)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("preview_failed", e.message, null)
                        }
                    }

                    "stopPreview" -> {
                        stopPreview()
                        result.success(null)
                    }

                    "pickSystemRingtone" -> {
                        if (pendingRingtoneResult != null) {
                            // A previous pick is still in flight (shouldn't
                            // normally happen — the UI disables itself while
                            // waiting) — fail it rather than silently
                            // dropping the new caller's result.
                            pendingRingtoneResult?.error(
                                "superseded", "Another pick was started", null
                            )
                        }
                        pendingRingtoneResult = result
                        launchRingtonePicker()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * True if [uriString] still resolves to something that can be opened.
     * The phone's own default-sound pointer (content://settings/...) is
     * a live reference to whatever the system currently has selected, so
     * it's always treated as present. Anything else is checked by
     * actually opening it — a MediaStore row whose file or database
     * entry is gone throws FileNotFoundException here instead of later,
     * inside a notification channel or the preview player.
     */
    private fun uriExists(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        if (uri.scheme == "content" && uri.authority == "settings") return true
        return try {
            contentResolver.openAssetFileDescriptor(uri, "r")?.use { true } ?: false
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Copies the file at [sourcePath] (a path from file_picker — already
     * readable by this app, since the system picker granted access) into
     * MediaStore's alarms collection, marked IS_ALARM so it shows up as
     * a valid alarm/notification sound, under Alarms/TaskFlow so it's
     * easy for the user to find/remove by hand if they ever want to.
     */
    private fun importRingtone(sourcePath: String, displayName: String): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, mimeTypeFor(sourcePath))
            put(MediaStore.Audio.Media.IS_ALARM, 1)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_MUSIC, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_ALARMS}/TaskFlow")
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val itemUri = resolver.insert(collection, values)
            ?: throw FileNotFoundException("Could not create MediaStore entry")

        resolver.openOutputStream(itemUri)?.use { out ->
            File(sourcePath).inputStream().use { input -> input.copyTo(out) }
        } ?: throw FileNotFoundException("Could not open output stream for $itemUri")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)
        }

        return itemUri.toString()
    }

    private fun mimeTypeFor(path: String): String {
        val ext = path.substringAfterLast('.', "").lowercase()
        return when (ext) {
            "mp3" -> "audio/mpeg"
            "wav" -> "audio/wav"
            "ogg" -> "audio/ogg"
            "m4a", "aac" -> "audio/mp4"
            "flac" -> "audio/flac"
            else -> "audio/*"
        }
    }

    /**
     * Opens the same ringtone-picker UI the phone's own Settings app uses
     * for "Alarm sound", filtered to TYPE_ALARM so results are things
     * actually meant to ring loudly, not quiet notification blips.
     * Pre-selects the person's current choice so the picker opens with
     * the right item highlighted rather than always defaulting to "None".
     */
    private fun launchRingtonePicker() {
        val currentUri = try {
            RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
        } catch (_: Exception) {
            null
        }

        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, currentUri)
        }
        startActivityForResult(intent, ringtonePickerRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ringtonePickerRequestCode) return

        val pending = pendingRingtoneResult
        pendingRingtoneResult = null

        val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (uri == null) {
            // Cancelled, or the person picked "Silent"/"None" — either
            // way there's nothing to switch to, so this is a no-op, not
            // an error. Dart's pickSystemRingtone() treats a null result
            // as "cancelled".
            pending?.success(null)
            return
        }

        val name = try {
            val ringtone: Ringtone? = RingtoneManager.getRingtone(this, uri)
            ringtone?.getTitle(this)
        } catch (_: Exception) {
            null
        }

        pending?.success(mapOf("uri" to uri.toString(), "name" to name))
    }

    private fun playPreview(uriString: String) {
        stopPreview()
        val player = MediaPlayer()
        player.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        player.setDataSource(this, Uri.parse(uriString))
        player.setOnCompletionListener { stopPreview() }
        player.isLooping = false
        player.prepare()
        player.start()
        previewPlayer = player
    }

    private fun stopPreview() {
        previewPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (_: Exception) {
                // Already stopped/released — nothing to clean up.
            }
            it.release()
        }
        previewPlayer = null
    }

    override fun onDestroy() {
        stopPreview()
        super.onDestroy()
    }
}