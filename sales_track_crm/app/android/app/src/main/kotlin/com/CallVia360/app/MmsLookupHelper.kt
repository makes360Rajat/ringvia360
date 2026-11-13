package com.CallVia360.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object MmsLookupHelper {
    private const val TAG = "MmsLookupHelper"

    /**
     * Queries MMS and RCS chat messages stored by Android/Google Messages.
     * Google Messages stores RCS (Rich Communication Services) chats inside the MMS database.
     */
    fun queryMmsMessages(context: Context, limit: Int = 1000, sinceMs: Long = 0): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return list
        }

        try {
            // 1. Preload text parts from content://mms/part
            val textParts = mutableMapOf<String, String>()
            val partUri = Uri.parse("content://mms/part")
            val partProjection = arrayOf("_id", "mid", "ct", "text")
            val partSelection = "ct = 'text/plain'"
            context.contentResolver.query(partUri, partProjection, partSelection, null, null)?.use { cursor ->
                val midIdx = cursor.getColumnIndex("mid")
                val textIdx = cursor.getColumnIndex("text")
                val idIdx = cursor.getColumnIndex("_id")
                while (cursor.moveToNext()) {
                    val mid = cursor.getString(midIdx) ?: continue
                    var text = if (textIdx != -1) cursor.getString(textIdx) else null
                    if (text == null && idIdx != -1) {
                        val partId = cursor.getString(idIdx)
                        try {
                            context.contentResolver.openInputStream(Uri.parse("content://mms/part/$partId"))?.use { inputStream ->
                                text = inputStream.bufferedReader().readText()
                            }
                        } catch (_: Exception) {}
                    }
                    if (!text.isNullOrEmpty()) {
                        textParts[mid] = text!!
                    }
                }
            }

            // 2. Preload addresses from content://mms/addr
            // Type 137 = PduHeaders.FROM, Type 151 = PduHeaders.TO
            val fromAddresses = mutableMapOf<String, String>()
            val toAddresses = mutableMapOf<String, String>()
            val addrUri = Uri.parse("content://mms/addr")
            val addrProjection = arrayOf("msg_id", "type", "address")
            context.contentResolver.query(addrUri, addrProjection, null, null, null)?.use { cursor ->
                val msgIdIdx = cursor.getColumnIndex("msg_id")
                val typeIdx = cursor.getColumnIndex("type")
                val addrIdx = cursor.getColumnIndex("address")
                while (cursor.moveToNext()) {
                    val msgId = cursor.getString(msgIdIdx) ?: continue
                    val type = if (typeIdx != -1) cursor.getInt(typeIdx) else 0
                    val addr = if (addrIdx != -1) cursor.getString(addrIdx) else null
                    if (addr.isNullOrEmpty() || addr.contains("insert-address-token")) continue
                    if (type == 137) {
                        fromAddresses[msgId] = addr
                    } else if (type == 151) {
                        toAddresses[msgId] = addr
                    }
                }
            }

            // 3. Query content://mms messages
            val mmsUri = Uri.parse("content://mms")
            val mmsProjection = arrayOf("_id", "date", "msg_box")
            var selection: String? = null
            var selectionArgs: Array<String>? = null
            if (sinceMs > 0) {
                selection = "date >= ?"
                selectionArgs = arrayOf((sinceMs / 1000L).toString())
            }
            val sortOrder = "date DESC LIMIT $limit"
            val contactsMap = ContactLookupHelper.getQuickLookupMap(context)
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)

            context.contentResolver.query(mmsUri, mmsProjection, selection, selectionArgs, sortOrder)?.use { cursor ->
                val idIdx = cursor.getColumnIndex("_id")
                val dateIdx = cursor.getColumnIndex("date")
                val msgBoxIdx = cursor.getColumnIndex("msg_box")

                while (cursor.moveToNext()) {
                    val id = cursor.getString(idIdx) ?: continue
                    val dateSec = cursor.getLong(dateIdx)
                    val dateMs = dateSec * 1000L
                    val msgBox = cursor.getInt(msgBoxIdx)
                    // msg_box: 1 = Inbox (incoming), 2 = Sent (outgoing)
                    val direction = if (msgBox == 1) "incoming" else "outgoing"

                    val body = textParts[id] ?: ""
                    if (body.isEmpty()) continue

                    val address = if (direction == "incoming") {
                        fromAddresses[id] ?: toAddresses[id] ?: ""
                    } else {
                        toAddresses[id] ?: fromAddresses[id] ?: ""
                    }
                    if (address.isEmpty()) continue

                    val digits = address.replace(Regex("[^0-9]"), "")
                    val key = if (digits.length >= 10) digits.takeLast(10) else address
                    val resolvedName = contactsMap[key] ?: contactsMap[address] ?: address
                    val dateIso = isoFormat.format(Date(dateMs))

                    list.add(mapOf(
                        "uid" to "mms-$id-$dateMs",
                        "kind" to "sms",
                        "direction" to direction,
                        "number" to address,
                        "name" to resolvedName,
                        "sim" to 1,
                        "text" to body,
                        "time" to dateMs,
                        "timestamp" to dateIso,
                        "source" to "auto"
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error querying MMS/RCS messages: ${e.message}")
        }
        return list
    }
}
