// Created by ruoyi.sjd on 2024/12/25.
// Copyright (c) 2024 Alibaba Group Holding Limited All rights reserved.
package com.alibaba.mnnllm.android.chat

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.alibaba.mnnllm.android.llm.ChatSession
import com.alibaba.mnnllm.android.R
import com.alibaba.mnnllm.android.audio.AudioPlayer
import com.alibaba.mnnllm.android.chat.chatlist.ChatListComponent
import com.alibaba.mnnllm.android.chat.input.ChatInputComponent
import com.alibaba.mnnllm.android.chat.model.ChatDataItem
import com.alibaba.mnnllm.android.databinding.ActivityChatBinding
import com.alibaba.mnnllm.android.llm.AudioDataListener
import com.alibaba.mnnllm.android.llm.LlmSession
import com.alibaba.mnnllm.android.modelsettings.SettingsBottomSheetFragment
import com.alibaba.mnnllm.android.utils.AudioPlayService
import com.alibaba.mnnllm.android.utils.ModelPreferences
import com.alibaba.mnnllm.android.utils.ModelUtils
import com.alibaba.mnnllm.android.utils.PreferenceUtils
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Locale

class ChatActivity : AppCompatActivity() {
    var isGenerating: Boolean
        get() = _isGenerating.value
        set(value) {
            _isGenerating.value = value
        }
    var dateFormat: DateFormat? = null
    var sessionId: String? = null
        private set
    var isLoading = false
    var isAudioModel = false
    var isDiffusion = false
    lateinit var chatSession: ChatSession

    private val _isGenerating = MutableStateFlow(false)
    private var layoutModelLoading: View? = null
    lateinit var modelName: String
    private var modelId: String? = null
    private var currentUserMessage: ChatDataItem? = null
    private var sessionName: String? = null
    private val configShowCustomToolbar = false
    private lateinit var binding: ActivityChatBinding
    private var audioPlayer: AudioPlayer? = null
    private lateinit var chatPresenter: ChatPresenter
    private lateinit var chatInputModule: ChatInputComponent
    private lateinit var chatListComponent: ChatListComponent
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityChatBinding.inflate(layoutInflater)
        setContentView(binding.root)
        val toolbar = binding.toolbar
        setSupportActionBar(toolbar)

        modelName = intent.getStringExtra("modelName")?:""
        modelId = intent.getStringExtra("modelId")
        if (modelName.isEmpty() || modelId.isNullOrEmpty()) {
            finish()
        }
        chatPresenter = ChatPresenter(this, modelName, modelId!!)
        isDiffusion = ModelUtils.isDiffusionModel(modelName)
        isAudioModel = ModelUtils.isAudioModel(modelName)
        chatInputModule = ChatInputComponent(this, binding, modelName,)
        layoutModelLoading = findViewById(R.id.layout_model_loading)
        updateActionBar()
        this.setupSession()
        dateFormat = SimpleDateFormat("hh:mm aa", Locale.getDefault())
        this.setupChatListComponent()
        setupInputModule()
    }

    private fun setupChatListComponent() {
        chatListComponent = ChatListComponent(this, binding)
    }

    private fun updateActionBar() {
        if (supportActionBar != null) {
            supportActionBar!!.setDisplayHomeAsUpEnabled(true)
            supportActionBar!!.setDisplayShowTitleEnabled(!configShowCustomToolbar)
            supportActionBar!!.title = getString(R.string.app_name)
        }
    }

    private fun setupInputModule() {
        this.chatInputModule.apply {
            setOnThinkingModeChanged {isThinking ->
                (chatSession as LlmSession).updateAssistantPrompt(if (isThinking) {
                    "<|im_start|>assistant\n%s<|im_end|>\n"
                } else {
                    "<|im_start|>assistant\n<think>\n</think>%s<|im_end|>\n"
                })
            }
            setOnAudioOutputModeChanged {
                chatPresenter.setEnableAudioOutput(it)
            }
            setOnSendMessage{
                this@ChatActivity.handleSendMessage(it)
            }
            setOnStopGenerating{
                chatPresenter.stopGenerate()
            }
        }
    }

    private fun setupSession() {
        chatSession = chatPresenter.createSession()
        sessionId = chatSession.sessionId
        Log.d(TAG, "current SessionId: $sessionId")
        chatPresenter.load()
    }

    private fun setupOmni() {
        audioPlayer = AudioPlayer()
        audioPlayer!!.start()
        (chatSession as LlmSession).setAudioDataListener(object : AudioDataListener {
            override fun onAudioData(data: FloatArray, isEnd: Boolean): Boolean {
                this@ChatActivity.lifecycleScope.launch {
                    audioPlayer?.playChunk(data)
                }
                return chatPresenter.stopGenerating
            }
        })
    }

    fun onLoadingChanged(loading: Boolean) {
        this.chatInputModule.onLoadingStatesChanged(loading)
        layoutModelLoading!!.visibility =
            if (loading) View.VISIBLE else View.GONE
        if (supportActionBar != null) {
            supportActionBar!!.setDisplayHomeAsUpEnabled(true)
            if (configShowCustomToolbar) {
            } else {
                supportActionBar!!.subtitle =
                    if (loading) getString(R.string.model_loading) else modelName
            }
        }
        if (!loading) {
            if (chatSession.supportOmni) {
                setupOmni()
            }
        }
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.menu_chat, menu)
        menu.findItem(R.id.show_performance_metrics)
            .setChecked(
                PreferenceUtils.getBoolean(
                    this,
                    PreferenceUtils.KEY_SHOW_PERFORMACE_METRICS,
                    true
                )
            )
        menu.findItem(R.id.menu_item_use_mmap).apply {
            isVisible = !isDiffusion
            if (!isDiffusion) {
                isChecked = ModelPreferences.getBoolean(
                    this@ChatActivity,
                    modelId!!,
                    ModelPreferences.KEY_USE_MMAP,
                    false
                )
            }
        }
        menu.findItem(R.id.menu_item_backend).apply {
            isVisible = !isDiffusion
            if (!isDiffusion) {
                isChecked = ModelPreferences.getBoolean(
                    this@ChatActivity,
                    modelId!!,
                    ModelPreferences.KEY_BACKEND,
                    false
                )
            }
        }
        menu.findItem(R.id.menu_item_model_settings).isVisible = !isDiffusion
        menu.findItem(R.id.menu_item_clear_mmap_cache).isVisible = !isDiffusion
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        if (item.itemId == R.id.start_new_chat) {
            handleNewSession()
        } else if (item.itemId == R.id.show_performance_metrics) {
            item.setChecked(!item.isChecked)
            chatListComponent.toggleShowPerformanceMetrics(item.isChecked)
        } else if (item.itemId == android.R.id.home) {
            finish()
        } else if (item.itemId == R.id.menu_item_clear_mmap_cache) {
            if (ModelPreferences.useMmap(this, modelId!!)) {
                Toast.makeText(this, R.string.mmap_cacche_cleared, Toast.LENGTH_LONG).show()
                (chatSession as LlmSession).clearMmapCache()
                recreate()
            } else {
                Toast.makeText(this, R.string.mmap_not_used, Toast.LENGTH_SHORT).show()
            }
        } else if (item.itemId == R.id.menu_item_use_mmap) {
            item.setChecked(!item.isChecked)
            Toast.makeText(this, R.string.reloading_session, Toast.LENGTH_LONG).show()
            ModelPreferences.setBoolean(
                this,
                modelId!!,
                ModelPreferences.KEY_USE_MMAP,
                item.isChecked
            )
            recreate()
        } else if (item.itemId == R.id.menu_item_backend) {
            item.setChecked(!item.isChecked)
            Toast.makeText(this, R.string.reloading_session, Toast.LENGTH_LONG).show()
            ModelPreferences.setBoolean(this, modelId!!, ModelPreferences.KEY_BACKEND, item.isChecked)
            recreate()
        } else if (item.itemId == R.id.menu_item_model_settings) {
            val settingsSheet = SettingsBottomSheetFragment()
            settingsSheet.setSession(chatSession as LlmSession)
            settingsSheet.show(supportFragmentManager, SettingsBottomSheetFragment.TAG)
            return true
        }
        return super.onOptionsItemSelected(item)
    }


    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        this.chatInputModule.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun handleNewSession() {
        if (!isGenerating) {
            currentUserMessage = null
            if (chatListComponent.reset()) {
                Toast.makeText(this, R.string.new_conversation_started, Toast.LENGTH_LONG).show()
            }
            this.sessionName = null
            chatPresenter.reset{newSessionId ->
                sessionId = newSessionId
            }
        } else {
            Toast.makeText(this, "Cannot Create New Session when generating", Toast.LENGTH_LONG).show()
        }
    }

    private fun setIsGenerating(isGenerating: Boolean) {
        this.isGenerating = isGenerating
        this.chatInputModule.setIsGenerating(isGenerating)
    }

    @Deprecated("This method has been deprecated in favor of using the Activity Result API\n      which brings increased type safety via an {@link ActivityResultContract} and the prebuilt\n      contracts for common intents available in\n      {@link androidx.activity.result.contract.ActivityResultContracts}, provides hooks for\n      testing, and allow receiving results in separate, testable classes independent from your\n      activity. Use\n      {@link #registerForActivityResult(ActivityResultContract, ActivityResultCallback)}\n      with the appropriate {@link ActivityResultContract} and handling the result in the\n      {@link ActivityResultCallback#onActivityResult(Object) callback}.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        this.chatInputModule.handleResult(requestCode, resultCode, data)
    }

    private fun handleSendMessage(userData: ChatDataItem) {
        setIsGenerating(true)
        chatListComponent.onStartSendMessage(userData)
        chatPresenter.onRequestGenerate(userData)
    }

    override fun onDestroy() {
        super.onDestroy()
        chatPresenter.destroy()
    }

    override fun onStop() {
        super.onStop()
        AudioPlayService.instance!!.destroy()
    }

    fun onGenerateStart() {
        setIsGenerating(true)
        val recentItem = chatListComponent.recentItem
        recentItem?.loading = true
    }

    fun onLlmGenerateProgress(progress: String?, generateResultProcessor:GenerateResultProcessor) {
        val chatDataItem = chatListComponent.recentItem!!
        chatDataItem.displayText = generateResultProcessor.getDisplayResult()
        chatDataItem.text = generateResultProcessor.getRawResult()
        chatListComponent.updateAssistantResponse(chatDataItem)
    }

    fun onDiffusionGenerateProgress(progress: String?, diffusionDestPath: String?) {
        val chatDataItem = chatListComponent.recentItem!!
        if ("100" == progress) {
            chatDataItem.text = getString(R.string.diffusion_generated_message)
            chatDataItem.displayText = chatDataItem.text
            chatDataItem.imageUri = Uri.parse(diffusionDestPath)
        } else {
            chatDataItem.text = getString(R.string.diffusion_generate_progress, progress)
            chatDataItem.displayText = chatDataItem.text
        }
        chatListComponent.updateAssistantResponse(chatDataItem)
    }

    fun onGenerateFinished(benchMarkResult: HashMap<String, Any>) {
        setIsGenerating(false)
        val recentItem = chatListComponent.recentItem!!
        recentItem.loading = false
        recentItem.benchmarkInfo = ModelUtils.generateBenchMarkString(benchMarkResult)
        chatListComponent.updateAssistantResponse(recentItem)
        chatPresenter.saveResponseToDatabase(recentItem)
    }

    val sessionDebugInfo: String
        get() = chatSession.debugInfo

    companion object {
        const val TAG: String = "ChatActivity"
    }
}