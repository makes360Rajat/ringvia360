package com.ringvia360.phonewhtsapp.mobile_phone_whatsapp

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import androidx.core.content.ContextCompat

object ContactLookupHelper {

    /**
     * Resolves saved contact name from Android Contacts provider using phone number.
     * Checks PhoneLookup first, then falls back to normalized digit suffix search.
     */
    fun resolveContactName(context: Context, rawNumber: String?): String? {
        if (rawNumber.isNullOrBlank()) return null
        val number = rawNumber.trim()
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            return null
        }

        // 1. Primary lookup via ContactsContract.PhoneLookup
        try {
            val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
            val projection = arrayOf(
                ContactsContract.PhoneLookup.DISPLAY_NAME,
                ContactsContract.PhoneLookup._ID
            )
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME)
                    if (idx >= 0) {
                        val name = cursor.getString(idx)?.trim()
                        if (!name.isNullOrEmpty() && name != number) {
                            return name
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        // 2. Normalized digit suffix fallback search on CommonDataKinds.Phone
        try {
            val digits = number.replace(Regex("[^0-9]"), "")
            if (digits.length >= 7) {
                val lastDigits = digits.takeLast(10)
                val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                val projection = arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val selection = "${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?"
                val selectionArgs = arrayOf("%$lastDigits")
                context.contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                        if (idx >= 0) {
                            val name = cursor.getString(idx)?.trim()
                            if (!name.isNullOrEmpty() && name != number) {
                                return name
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        return null
    }

    /**
     * Retrieves all saved phonebook contacts with name and number.
     */
    fun getAllContacts(context: Context): List<Map<String, String>> {
        val list = mutableListOf<Map<String, String>>()
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            return list
        }
        try {
            val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            context.contentResolver.query(
                uri,
                projection,
                null,
                null,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )?.use { cursor ->
                val nameIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (cursor.moveToNext()) {
                    val name = if (nameIdx >= 0) cursor.getString(nameIdx)?.trim() ?: "" else ""
                    val num = if (numIdx >= 0) cursor.getString(numIdx)?.trim() ?: "" else ""
                    if (num.isNotEmpty()) {
                        list.add(mapOf("name" to (if (name.isNotEmpty()) name else num), "phoneNumber" to num))
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return list
    }
}
