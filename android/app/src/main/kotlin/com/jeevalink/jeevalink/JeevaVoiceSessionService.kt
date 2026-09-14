package com.jeevalink.jeevalink

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService

class JeevaVoiceSessionService : VoiceInteractionSessionService() {
    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return JeevaVoiceSession(this)
    }
}

class JeevaVoiceSession(context: Context) : VoiceInteractionSession(context) {

    override fun onShow(args: Bundle?, flags: Int) {
        super.onShow(args, flags)

        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
            putExtra("EXTRA_VOICE_ASSISTANT_TRIGGER", "POWER_BUTTON_ASSIST")
            putExtra("EXTRA_START_RECORDING", true)
        }

        try {
            startAssistantActivity(intent)
        } catch (e: Exception) {
            try {
                context.startActivity(intent)
            } catch (ex: Exception) {
                ex.printStackTrace()
            }
        }

        try {
            finish()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
