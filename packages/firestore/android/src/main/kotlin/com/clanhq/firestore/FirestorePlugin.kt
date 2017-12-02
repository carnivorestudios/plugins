package com.clanhq.firestore

import android.util.SparseArray
import com.google.android.gms.tasks.Continuation
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.firebase.firestore.*
import com.google.firebase.firestore.EventListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.util.*
import com.google.firebase.firestore.FirebaseFirestoreSettings
import java.lang.Exception


class FirestorePlugin internal constructor(private val channel: MethodChannel) : MethodCallHandler {
    private var nextHandle = 0
    private val queryObservers = SparseArray<QueryObserver>()
    private val documentObservers = SparseArray<DocumentObserver>()
    private val listenerRegistrations = SparseArray<ListenerRegistration>()


    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar): Unit {
            val channel = MethodChannel(registrar.messenger(), "firestore")
            channel.setMethodCallHandler(FirestorePlugin(channel))
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result): Unit {
        when (call.method) {
            "Firestore#setPersistenceEnabled" -> {
                val arguments = call.arguments<Map<String, Any?>>()
                val enabled = arguments["enabled"] as Boolean
                val settings = FirebaseFirestoreSettings.Builder()
                        .setPersistenceEnabled(enabled)
                        .build()
                FirebaseFirestore.getInstance().setFirestoreSettings(settings)
                result.success(null)
            }
            "DocumentReference#setData" -> {
                val arguments = call.arguments<Map<String, Any?>>()
                val documentReference = getDocumentReference(arguments["path"] as String)
                val data = arguments["data"] as Map<*, *>

                val newValues = HashMap<String, Any?>()

                data.entries.forEach {
                    if (it.value == ".sv") {
                        newValues[it.key as String] = FieldValue.serverTimestamp()
                    } else {
                        newValues[it.key as String] = it.value
                    }
                }
                documentReference.set(newValues)

                result.success(null)
            }
            "DocumentReference#update" -> {
                val arguments = call.arguments<Map<String, Any?>>()
                val documentReference = getDocumentReference(arguments["path"] as String)
                val data = arguments["data"] as Map<*, *>

                val newValues = HashMap<String, Any?>()

                data.entries.forEach {
                    if (it.value == ".sv") {
                        newValues[it.key as String] = FieldValue.serverTimestamp()
                    } else {
                        newValues[it.key as String] = it.value
                    }
                }
                documentReference.update(newValues)

                result.success(null)
            }
            "DocumentReference#getSnapshot" -> {
                val arguments = call.arguments<Map<String, Any?>>()
                val path = arguments["path"] as String
                val documentReference = getDocumentReference(path)
                documentReference.get().addOnCompleteListener { task ->
                    if (task.isSuccessful) {
                        val documentSnapshot: DocumentSnapshot = task.result

                        val resultArguments =
                                if (documentSnapshot.exists()) documentSnapshotToMap(documentSnapshot)
                                else HashMap<String, Any>()

                        result.success(resultArguments)
                    }
                }.addOnFailureListener { e ->
                    resultErrorForArguments(result, arguments, e)
                }
            }
            "DocumentReference#delete" -> {
                val arguments = call.arguments<Map<String, Any?>>()
                val documentReference = getDocumentReference(arguments["path"] as String)
                documentReference.delete().addOnCompleteListener { task ->
                    result.success(null)
                }.addOnFailureListener { e ->
                    resultErrorForArguments(result, arguments, e)
                }
            }
            "Query#addSnapshotListener" -> {
                val arguments = call.arguments<Map<String, Any>>()
                val path = arguments["path"] as String

                val queryParameterTask = getQueryParameters(path, arguments["parameters"] as Map<*, *>?)
                queryParameterTask.addOnSuccessListener {
                    val qp: QueryParameters = it

                    if (qp.startAtId != null && qp.startAtSnap != null && !qp.startAtSnap.exists()) {
                        resultErrorForDocumentId(result, qp.startAtId)
                    } else if (qp.startAfterId != null && qp.startAfterSnap != null && !qp.startAfterSnap.exists()) {
                        resultErrorForDocumentId(result, qp.startAfterId)
                    } else if (qp.endAtId != null && qp.endAtSnap != null && !qp.endAtSnap.exists()) {
                        resultErrorForDocumentId(result, qp.endAtId)
                    } else if (qp.endBeforeId != null && qp.endBeforeSnap != null && !qp.endBeforeSnap.exists()) {
                        resultErrorForDocumentId(result, qp.endBeforeId)
                    } else {
                        registerSnapshotListener(result, path, limit = qp.limit,
                                orderBy = qp.orderBy,
                                startAt = qp.startAtSnap, startAfter = qp.startAfterSnap,
                                endAt = qp.endAtSnap, endBefore = qp.endBeforeSnap,
                                endAtTimestamp = qp.endAtTimestamp, where = qp.where)
                    }
                }
                queryParameterTask.addOnFailureListener { e ->
                    resultErrorForArguments(result, arguments, e)
                }
            }
            "Query#getSnapshot" -> {
                val arguments = call.arguments<Map<String, Any>>()
                val path = arguments["path"] as String
                val queryParameterTask = getQueryParameters(path, arguments["parameters"] as Map<*, *>?)

                queryParameterTask.addOnSuccessListener {
                    val qp: QueryParameters = it

                    try {
                        val query = getQuery(path = path, limit = qp.limit, orderBy = qp.orderBy, startAt = qp.startAtSnap,
                                startAfter = qp.startAfterSnap, endAt = qp.endAtSnap,
                                endBefore = qp.endBeforeSnap, endAtTimestamp = qp.endAtTimestamp, where = qp.where)

                        query.get().addOnCompleteListener { task ->
                            val querySnapshot = task.result
                            val documents = querySnapshot.documents.map(::documentSnapshotToMap)
                            val resultArguments = HashMap<String, Any>()
                            resultArguments.put("documents", documents)
                            resultArguments.put("documentChanges", HashMap<String, Any>())
                            result.success(resultArguments)
                        }.addOnFailureListener { e ->
                            if (qp.startAtId != null) resultErrorForDocumentId(result, qp.startAtId)
                            else if (qp.startAfterId != null) resultErrorForDocumentId(result, qp.startAfterId)
                            else if (qp.endAtId != null) resultErrorForDocumentId(result, qp.endAtId)
                            else if (qp.endBeforeId != null) resultErrorForDocumentId(result, qp.endBeforeId)
                            else resultErrorForArguments(result, arguments, e)
                        }
                    } catch (e: Throwable) {
                        result.error("ERR", e.message, null);
                    }
                }
                queryParameterTask.addOnFailureListener { e ->
                    resultErrorForArguments(result, arguments, e)
                }
            }

            "Query#addDocumentListener" -> {
                val arguments = call.arguments<Map<String, Any>>()
                val handle = nextHandle++
                val observer = DocumentObserver(handle)
                documentObservers.put(handle, observer)
                listenerRegistrations.put(
                        handle, getDocumentReference(arguments["path"] as String).addSnapshotListener(observer))
                result.success(handle)
            }
            "Query#removeQueryListener" -> {
                val arguments = call.arguments<Map<String, Any>>()
                val handle = arguments["handle"] as Int
                listenerRegistrations.get(handle).remove()
                listenerRegistrations.remove(handle)
                queryObservers.remove(handle)
                result.success(null)
            }
            "Query#removeDocumentListener" -> {
                val arguments = call.arguments<Map<String, Any>>()
                val handle = arguments["handle"] as Int
                listenerRegistrations.get(handle).remove()
                listenerRegistrations.remove(handle)
                documentObservers.remove(handle)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun registerSnapshotListener(
            result: Result,
            path: String,
            limit: Int?,
            orderBy: List<OrderByParameters>?,
            startAt: DocumentSnapshot? = null,
            startAfter: DocumentSnapshot? = null,
            endAt: DocumentSnapshot? = null,
            endBefore: DocumentSnapshot? = null,
            endAtTimestamp: Long? = null,
            where: List<*>? = null
    ) {
        val handle = nextHandle++
        val observer = QueryObserver(handle)
        val query = getQuery(
                path = path,
                limit = limit,
                orderBy = orderBy,
                startAt = startAt,
                startAfter = startAfter,
                endAt = endAt,
                endBefore = endBefore,
                endAtTimestamp = endAtTimestamp, where = where)

        queryObservers.put(handle, observer)
        listenerRegistrations.put(handle, query.addSnapshotListener(observer))
        result.success(handle)
    }

    private inner class DocumentObserver internal constructor(private val handle: Int) : EventListener<DocumentSnapshot?> {
        override fun onEvent(documentSnapshot: DocumentSnapshot?, e: FirebaseFirestoreException?) {
            if (documentSnapshot == null) return

            val arguments =
                    if (documentSnapshot.exists()) documentSnapshotToMap(documentSnapshot)
                    else HashMap<String, Any>()
            arguments.put("handle", handle)
            channel.invokeMethod("DocumentSnapshot", arguments)
        }
    }


    private inner class QueryObserver internal constructor(private val handle: Int) : EventListener<QuerySnapshot?> {
        override fun onEvent(querySnapshot: QuerySnapshot?, e: FirebaseFirestoreException?) {
            if (querySnapshot == null) return

            val arguments = HashMap<String, Any>()
            arguments.put("handle", handle)

            val documents = querySnapshot.documents.map(::documentSnapshotToMap)
            arguments.put("documents", documents)

            val documentChanges = ArrayList<Map<String, Any>>()
            for (documentChange in querySnapshot.documentChanges) {
                val change = HashMap<String, Any>()
                change.put("type", documentChange.type.ordinal)
                change.put("oldIndex", documentChange.oldIndex)
                change.put("newIndex", documentChange.newIndex)
                change.put("document", documentSnapshotToMap(documentChange.document))
                documentChanges.add(change)
            }
            arguments.put("documentChanges", documentChanges)

            channel.invokeMethod("QuerySnapshot", arguments)
        }
    }

    private fun getQuery(
            path: String,
            limit: Int?,
            orderBy: List<OrderByParameters>?,
            startAt: DocumentSnapshot?,
            startAfter: DocumentSnapshot?,
            endAt: DocumentSnapshot?,
            endBefore: DocumentSnapshot?,
            endAtTimestamp: Long?, where: List<*>?): Query {

        var query: Query = getCollectionReference(path)

        where?.forEach {
            val condition = it as List<*>

            val fieldName = condition[0] as String
            val operator = condition[1] as String
            val value = condition[2] as Any

            if ("==" == operator) {
                query = query.whereEqualTo(fieldName, value)
            } else if ("<" == operator) {
                query = query.whereLessThan(fieldName, value)
            } else if ("<=" == operator) {
                query = query.whereLessThanOrEqualTo(fieldName, value)
            } else if (">" == operator) {
                query = query.whereGreaterThan(fieldName, value)
            } else if (">=" == operator) {
                query = query.whereGreaterThanOrEqualTo(fieldName, value)
            } else {
                // Invalid operator.
            }
        }

        if (limit != null) query = query.limit(limit.toLong())

        orderBy?.forEach {
            query.orderBy(it.field, if (it.descending) Query.Direction.DESCENDING else Query.Direction.ASCENDING)
        }

        if (startAt != null) query = query.startAt(startAt)
        if (startAfter != null) query = query.startAfter(startAfter)
        if (endAt != null) query = query.endAt(endAt)
        if (endBefore != null) query = query.endBefore(endBefore)
        if (endAtTimestamp != null) query = query.endAt(Date(endAtTimestamp))

        return query
    }

    private fun resultErrorForDocumentId(result: Result, id: String) = result.error("ERR", "Error retrieving document with ID $id", null)
    private fun resultErrorForArguments(result: Result, arguments: Map<String, Any?>, exception: Exception?) = result.error("ERR", "Error for arguments $arguments", exception.toString())

}

private fun getDocumentReference(path: String): DocumentReference = FirebaseFirestore.getInstance().document(path)
private fun getCollectionReference(path: String): CollectionReference = FirebaseFirestore.getInstance().collection(path)

fun getQueryParameters(path: String, parameters: Map<*, *>?): Task<QueryParameters> {
    val limit = parameters?.get("limit") as? Int
    val orderByParameters = parameters?.get("orderBy") as? List<List<*>>
    val startAtId = parameters?.get("startAtId") as? String
    val startAfterId = parameters?.get("startAfterId") as? String
    val endAtId = parameters?.get("endAtId") as? String
    val endBeforeId = parameters?.get("endBeforeId") as? String
    val endAtTimestamp = parameters?.get("endAtTimestamp") as? Long
    val where = parameters?.get("where") as? List<*>;

    val actualOrderBy = orderByParameters?.map {
        val field: String = it[0] as String
        val descending: Boolean? = it[1] as Boolean?

        if (descending != null) {
            OrderByParameters(field, descending)
        } else {
            OrderByParameters(field)
        }
    }

    val startAtTask: Task<DocumentSnapshot?> =
            if (startAtId != null) getDocumentReference("$path/$startAtId").get()
            else Tasks.forResult(null)

    val startAfterTask: Task<DocumentSnapshot?> =
            if (startAfterId != null) getDocumentReference("$path/$startAfterId").get()
            else Tasks.forResult(null)

    val endAtTask: Task<DocumentSnapshot?> =
            if (endAtId != null) getDocumentReference("$path/$endAtId").get()
            else Tasks.forResult(null)

    val endBeforeTask: Task<DocumentSnapshot?> =
            if (endBeforeId != null) getDocumentReference("$path/$endBeforeId").get()
            else Tasks.forResult(null)

    val x: Task<Void> = Tasks.whenAll(startAtTask, startAfterTask, endAtTask, endBeforeTask)

    val y = Continuation<Void, QueryParameters> {
        val startAtSnap: DocumentSnapshot? = startAtTask.result
        val startAfterSnap: DocumentSnapshot? = startAfterTask.result
        val endAtSnap: DocumentSnapshot? = endAtTask.result
        val endBeforeSnap: DocumentSnapshot? = endBeforeTask.result

        QueryParameters(limit, actualOrderBy, startAtId, startAtSnap, startAfterId,
                startAfterSnap, endAtId, endAtSnap, endBeforeId, endBeforeSnap, endAtTimestamp, where)
    }
    return x.continueWith(y)
}

data class QueryParameters(val limit: Int?, val orderBy: List<OrderByParameters>?,
                           val startAtId: String?, val startAtSnap: DocumentSnapshot?,
                           val startAfterId: String?, val startAfterSnap: DocumentSnapshot?,
                           val endAtId: String?, val endAtSnap: DocumentSnapshot?,
                           val endBeforeId: String?, val endBeforeSnap: DocumentSnapshot?,
                           val endAtTimestamp: Long?, val where: List<*>?)

data class OrderByParameters(val field: String, val descending: Boolean = false)
