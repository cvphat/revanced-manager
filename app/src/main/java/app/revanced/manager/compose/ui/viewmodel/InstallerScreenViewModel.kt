package app.revanced.manager.compose.ui.viewmodel

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModel
import androidx.work.*
import app.revanced.manager.compose.R
import app.revanced.manager.compose.patcher.SignerService
import app.revanced.manager.compose.patcher.worker.PatcherProgressManager
import app.revanced.manager.compose.patcher.worker.PatcherWorker
import app.revanced.manager.compose.patcher.worker.StepGroup
import app.revanced.manager.compose.service.InstallService
import app.revanced.manager.compose.service.UninstallService
import app.revanced.manager.compose.util.PM
import app.revanced.manager.compose.util.PackageInfo
import app.revanced.manager.compose.util.toast
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.nio.file.Files

class InstallerScreenViewModel(
    input: PackageInfo,
    selectedPatches: List<String>,
    private val app: Application,
    private val signerService: SignerService
) : ViewModel() {
    var stepGroups by mutableStateOf<List<StepGroup>>(PatcherProgressManager.generateGroupsList(app, selectedPatches))
        private set

    val packageName = input.packageName

    private val workManager = WorkManager.getInstance(app)

    // TODO: get rid of these and use stepGroups instead.
    var installStatus by mutableStateOf<Boolean?>(null)
    var pmStatus by mutableStateOf(-999)
    var extra by mutableStateOf("")

    private val outputFile = File(app.cacheDir, "output.apk")
    private val signedFile = File(app.cacheDir, "signed.apk").also { if (it.exists()) it.delete() }
    private var hasSigned = false
    private var patcherStatus by mutableStateOf<Boolean?>(null)
    private var isInstalling by mutableStateOf(false)

    val canInstall by derivedStateOf { patcherStatus == true && !isInstalling }


    private val patcherWorker =
        OneTimeWorkRequest.Builder(PatcherWorker::class.java) // create Worker
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST).setInputData(
                workDataOf(
                    PatcherWorker.ARGS_KEY to
                            Json.Default.encodeToString(
                                PatcherWorker.Args(
                                    input.apk.path,
                                    outputFile.path,
                                    selectedPatches,
                                    input.packageName,
                                    input.version,
                                )
                            )
                )
            ).build()

    private val liveData = workManager.getWorkInfoByIdLiveData(patcherWorker.id) // get LiveData

    private val observer = Observer { workInfo: WorkInfo -> // observer for observing patch status
        when (workInfo.state) {
            WorkInfo.State.RUNNING -> workInfo.progress
            WorkInfo.State.FAILED, WorkInfo.State.SUCCEEDED -> workInfo.outputData.also {
                patcherStatus = workInfo.state == WorkInfo.State.SUCCEEDED
            }

            else -> null
        }?.let { PatcherProgressManager.groupsFromWorkData(it) }?.let { stepGroups = it }
    }

    private val installBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                InstallService.APP_INSTALL_ACTION -> {
                    pmStatus = intent.getIntExtra(InstallService.EXTRA_INSTALL_STATUS, -999)
                    extra = intent.getStringExtra(InstallService.EXTRA_INSTALL_STATUS_MESSAGE)!!
                    postInstallStatus()
                }

                UninstallService.APP_UNINSTALL_ACTION -> {
                }
            }
        }
    }

    init {
        workManager.enqueueUniqueWork("patching", ExistingWorkPolicy.KEEP, patcherWorker)
        liveData.observeForever(observer)
        app.registerReceiver(installBroadcastReceiver, IntentFilter().apply {
            addAction(InstallService.APP_INSTALL_ACTION)
            addAction(UninstallService.APP_UNINSTALL_ACTION)
        })
    }

    private fun signApk(): Boolean {
        if (!hasSigned) {
            try {
                signerService.createSigner().signApk(outputFile, signedFile)
            } catch (e: Throwable) {
                e.printStackTrace()
                app.toast(app.getString(R.string.sign_fail, e::class.simpleName))
                return false
            }
        }

        return true
    }

    fun export(uri: Uri?) = uri?.let {
        if (signApk()) {
            Files.copy(signedFile.toPath(), app.contentResolver.openOutputStream(it))
            app.toast(app.getString(R.string.export_app_success))
        }
    }

    fun installApk() {
        isInstalling = true
        try {
            if (!signApk()) return
            PM.installApp(listOf(signedFile), app)
        } finally {
            isInstalling = false
        }
    }

    fun postInstallStatus() {
        installStatus = pmStatus == PackageInstaller.STATUS_SUCCESS
    }

    override fun onCleared() {
        super.onCleared()
        liveData.removeObserver(observer)
        app.unregisterReceiver(installBroadcastReceiver)
        workManager.cancelWorkById(patcherWorker.id)
        // logs.clear()

        outputFile.delete()
        signedFile.delete()
    }
}