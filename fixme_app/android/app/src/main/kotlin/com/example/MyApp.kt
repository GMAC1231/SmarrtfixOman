package com.example.fixme_app

import android.app.Application
import android.util.Log

class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // Suppress OsmDroid debug logs
        Log.isLoggable("OsmDroid", Log.ASSERT) // forces Android to ignore DEBUG/INFO logs
    }
}
