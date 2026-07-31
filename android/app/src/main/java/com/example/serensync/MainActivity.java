package com.example.serensync;

import android.app.role.RoleManager;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "serensync/launcher";
    private static final String LAUNCHER_ALIAS =
            "com.example.serensync.LauncherAlias";

    private MethodChannel launcherChannel;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        launcherChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        );
        launcherChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "isEnabled":
                    result.success(isLauncherEnabled());
                    break;
                case "openedAsLauncher":
                    result.success(openedAsLauncher(getIntent()));
                    break;
                case "setEnabled":
                    Boolean enabled = call.arguments();
                    if (enabled == null) {
                        result.error("invalid_argument", "Missing launcher state.", null);
                        return;
                    }
                    setLauncherEnabled(enabled);
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (launcherChannel != null) {
            launcherChannel.invokeMethod(
                    openedAsLauncher(intent) ? "showLauncher" : "showMainApp",
                    null
            );
        }
    }

    private ComponentName launcherAlias() {
        return new ComponentName(this, LAUNCHER_ALIAS);
    }

    private boolean isLauncherEnabled() {
        return getPackageManager().getComponentEnabledSetting(launcherAlias())
                == PackageManager.COMPONENT_ENABLED_STATE_ENABLED;
    }

    private boolean openedAsLauncher(Intent intent) {
        ComponentName component = intent.getComponent();
        return component != null && LAUNCHER_ALIAS.equals(component.getClassName());
    }

    private void setLauncherEnabled(boolean enabled) {
        getPackageManager().setComponentEnabledSetting(
                launcherAlias(),
                enabled
                        ? PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        : PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
        );
        if (enabled) {
            openHomeAppPicker();
        }
    }

    private void openHomeAppPicker() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            RoleManager roleManager = getSystemService(RoleManager.class);
            if (roleManager != null
                    && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)
                    && !roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                startActivity(roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME));
                return;
            }
        }
        startActivity(new Intent(Settings.ACTION_HOME_SETTINGS));
    }
}
