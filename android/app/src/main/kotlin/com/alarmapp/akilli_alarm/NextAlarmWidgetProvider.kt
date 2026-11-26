package com.alarmapp.akilli_alarm

// Ana ekran widget'ı: Flutter tarafının kaydettiği "sonraki alarm" bilgisini gösterir.
// Widget'a dokununca uygulama açılır.

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NextAlarmWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.next_alarm_widget).apply {
                // Flutter'ın WidgetService ile kaydettiği değerler
                setTextViewText(R.id.widget_time, widgetData.getString("next_time", "--:--"))
                setTextViewText(R.id.widget_info, widgetData.getString("next_info", "Açık alarm yok"))
                // Dokununca uygulamayı aç
                val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, openApp)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
