package com.CallVia360.app

import android.content.Context
import android.net.Uri
import android.provider.ContactsContract

object ContactLookupHelper {

    fun resolveContactName(context: Context, phoneNumber: String?): String? {
        if (phoneNumber.isNullOrEmpty()) return null
        var contactName: String? = null
        try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            )
            val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        contactName = cursor.getString(nameIndex)
                    }
                }
            }
        } catch (_: Exception) {}
        return contactName
    }

    fun getAllContacts(context: Context): List<Map<String, String>> {
        val contactsList = mutableListOf<Map<String, String>>()
        try {
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
            )?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (cursor.moveToNext()) {
                    val name = if (nameIndex != -1) cursor.getString(nameIndex) else ""
                    val number = if (numberIndex != -1) cursor.getString(numberIndex) else ""
                    if (!number.isNullOrEmpty()) {
                        contactsList.add(
                            mapOf(
                                "name" to (name ?: "Unknown"),
                                "number" to number
                            )
                        )
                    }
                }
            }
        } catch (_: Exception) {}
        return contactsList
    }

    fun getQuickLookupMap(context: Context): Map<String, String> {
        val map = mutableMapOf<String, String>()
        try {
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                null,
                null,
                null
            )?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (cursor.moveToNext()) {
                    val name = if (nameIndex != -1) cursor.getString(nameIndex) else ""
                    val number = if (numberIndex != -1) cursor.getString(numberIndex) else ""
                    if (!number.isNullOrEmpty() && !name.isNullOrEmpty()) {
                        val digits = number.replace(Regex("[^0-9]"), "")
                        if (digits.length >= 10) {
                            map[digits.takeLast(10)] = name
                        }
                        map[number.trim()] = name
                    }
                }
            }
        } catch (_: Exception) {}
        return map
    }

    fun resolvePhoneNumberByName(context: Context, name: String?): String? {
        if (name.isNullOrEmpty()) return null
        try {
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.NUMBER,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
            )
            val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} = ?"
            val selectionArgs = arrayOf(name.trim())
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val numIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    if (numIdx != -1) {
                        val num = cursor.getString(numIdx)
                        if (!num.isNullOrEmpty()) return num
                    }
                }
            }
        } catch (_: Exception) {}
        return null
    }
}
