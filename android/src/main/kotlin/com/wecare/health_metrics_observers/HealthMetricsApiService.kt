package com.wecare.health_metrics_observers

import com.google.gson.FieldNamingPolicy
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.wecare.health_metrics_observers.AppConstants
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class HealthMetricsApiService {
    companion object {
        private const val USER_ID_HEADER_NAME = "we_uid"
        private const val API_KEY_HEADER_NAME = "we_api_key"
        private const val APP_VERSION_HEADER_NAME = "app_version"
        private const val X_API_KEY_HEADER_NAME = "x-api-key"

        fun sendSteps(
            userId: String,
            apiKey: String,
            xApiKey: String,
            apiUrl: String,
            stepRecords: List<Map<String, Any>>,
            appVersion: String,
            completion: (Boolean)->Unit
        ) {
            val client = OkHttpClient()
            val endpointMetrics = "/api/profile/public/metrics"
            val url = URL("$apiUrl$endpointMetrics")

            var bodyMap = HashMap<String, Any>()
            bodyMap.put("metrics", stepRecords)
            bodyMap.put("type","STEP")
            bodyMap.put("source","OBSERVER")
            bodyMap.put("mobile_platform","ANDROID")

            val gson = Gson()
            val jsonString = gson.toJson(bodyMap).toString()
            val mediaType = "application/json".toMediaType()
            val body: RequestBody = jsonString.toRequestBody(mediaType)

            val requestBuilder = Request.Builder()
                .url(url)
                .addHeader("Content-Type", "application/json")
                .addHeader(name = USER_ID_HEADER_NAME, userId)
                .addHeader(name = API_KEY_HEADER_NAME, apiKey)
                .addHeader(name = APP_VERSION_HEADER_NAME, appVersion)
                .post(body)

            if (xApiKey != "") {
                requestBuilder.addHeader(name = X_API_KEY_HEADER_NAME, xApiKey)
            }
            val request = requestBuilder.build()
            client.newCall(request).enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    //TODO: send error to bugsnag
                    completion(false)
                }

                override fun onResponse(call: Call, response: Response) {
                    response.use {
                        if (!response.isSuccessful) {
                            //TODO: send error to bugsnag
                            print("error pushing metrics to server")
                        }
                        completion(response.isSuccessful)
                    }
                }
            })
        }
        
        fun getLastTimeStepsSavedServer(
            userId: String,
            apiKey: String,
            xApiKey: String,
            apiUrl: String,
            appVersion: String,
            httpClient: OkHttpClient?,
            completion: (Date?)->Unit
        ) {
            val client = httpClient ?: OkHttpClient()
            val endpointLastSteps = "/api/profile/public/health_metrics/last_steps"
            val url = URL("$apiUrl$endpointLastSteps")
            val requestBuilder = Request.Builder()
                .url(url)
                .addHeader("Content-Type", "application/json")
                .addHeader(name = USER_ID_HEADER_NAME, userId)
                .addHeader(name = API_KEY_HEADER_NAME, apiKey)
                .addHeader(name = APP_VERSION_HEADER_NAME, appVersion)
                .get()

            if (xApiKey != "") {
                requestBuilder.addHeader(name = X_API_KEY_HEADER_NAME, xApiKey)
            }
            val request = requestBuilder.build()

            client.newCall(request).enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    //TODO: send error to bugsnag
                    completion(null)
                }

                override fun onResponse(call: Call, response: Response) {
                    response.use {
                        if (!response.isSuccessful) {
                            //TODO: send error to bugsnag
                            completion(null)
                            return@use
                        }
                        try {
                            val decoder =
                                GsonBuilder()
                                    .setFieldNamingPolicy(FieldNamingPolicy.LOWER_CASE_WITH_UNDERSCORES)
                                    .create()
                            val bodyString = response.body?.string() ?: ""
                            val stepRecord = decoder.fromJson(bodyString, StepRecord::class.java)
                            val endDateStr = stepRecord.measurementEndDate
                            val dateFormatStr = getDateFormatForDateStr(endDateStr)
                            val dateFormat = SimpleDateFormat(dateFormatStr)
                            val lastTimeStepsSaved = dateFormat.parse(endDateStr)
                            completion(lastTimeStepsSaved)
                        } catch (e: Exception) {
                            completion(null)
                        }
                    }
                }
            })
        }

        fun getDateFormatForDateStr(dateStr: String): String {
            var dateFormatStr = AppConstants.defaultDateFormat
            if(!dateStr.contains(".")){
                dateFormatStr = dateFormatStr.replace(".SSS", "")
            }
            return dateFormatStr
        }
    }
}

class StepRecord (val id: String, val value: String, val type: String, val measurementStartDate: String,
                  val measurementEndDate: String, val mobilePlatform: String)