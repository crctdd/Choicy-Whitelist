// Copyright (c) 2019-2021 Lars Fröder

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <mach/mach.h>
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <xpc/xpc.h>
#include <libgen.h>
#include <os/log.h>
#include <dlfcn.h>
#include <roothide.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <ptrauth.h>
#include <litehook.h>
#include "dyld_interpose.h"
#include "nextstep_plist.h"
#include "CHWhitelistPolicy.h"

void *(*dlopen_orig)(const char*, int);
void *dlopen_hook(const char *path, int mode);

void *(*dyld_dlopen_orig)(const void *, const char*, int);
void *dyld_dlopen_hook(const void *dyld, const char *path, int mode);

bool gShouldLog = false;
#define os_log_dbg(args ...) if (gShouldLog) os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG, args)
#define os_log_err(args ...) if (gShouldLog) os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, args)

extern xpc_object_t xpc_create_from_plist(const void *buf, size_t len);
#define kEnvDeniedTweaksOverride "CHOICY_DENIED_TWEAKS_OVERRIDE"
#define kEnvAllowedTweaksOverride "CHOICY_ALLOWED_TWEAKS_OVERRIDE"
#define kEnvOverwriteGlobalConfigurationOverride "CHOICY_OVERWRITE_GLOBAL_TWEAK_CONFIGURATION_OVERRIDE"
#define kChoicyPrefsPlistPath jbroot("/var/mobile/Library/Preferences/com.crctdd.choicy-whitelist.plist")
#define kChoicyPrefsKeyGlobalDeniedTweaks "globalDeniedTweaks"
#define kChoicyPrefsKeyPrivilegedTweaks CH_PRIVILEGED_TWEAKS_KEY
#define kChoicyPrefsKeyAppSettings "appSettings"
#define kChoicyPrefsKeyDaemonSettings "daemonSettings"
#define kChoicyProcessPrefsKeyTweakInjectionEnabled "tweakInjectionEnabled"
#define kChoicyProcessPrefsKeyCustomTweakConfigurationEnabled "customTweakConfigurationEnabled"
#define kChoicyProcessPrefsKeyAllowDenyMode "allowDenyMode"
#define kChoicyProcessPrefsKeyDeniedTweaks "deniedTweaks"
#define kChoicyProcessPrefsKeyAllowedTweaks "allowedTweaks"
#define kChoicyProcessPrefsKeyOverwriteGlobalTweakConfiguration "overwriteGlobalTweakConfiguration"
#define kPreferencesBundleID "com.apple.Preferences"
#define kSpringboardBundleID "com.apple.springboard"

enum {
	PROCESS_TYPE_BINARY,
	PROCESS_TYPE_APP,
	PROCESS_TYPE_PLUGIN,
};

char *gExecutablePath = NULL;
char *gBundleIdentifier = NULL;
int gProcessType = 0;

bool gTweakInjectionDisabled = true;
bool gDisablePrivilegedTweaks = false;
bool gPrivilegeScopeAllowed = false;
CHLaunchMode gLaunchMode = CHLaunchNormal;
xpc_object_t gAllowedTweaks = NULL;
xpc_object_t gDeniedTweaks = NULL;
xpc_object_t gGlobalDeniedTweaks = NULL;
xpc_object_t gPrivilegedTweaks = NULL;
xpc_object_t gManualPrivilegedTweaks = NULL;
bool gCustomPrivilegeEnabled = false;
bool gPrivilegeDenyMode = false;
xpc_object_t gPrivilegeAllowedTweaks = NULL;
xpc_object_t gPrivilegeDeniedTweaks = NULL;

bool string_has_prefix(const char *str, const char* prefix)
{
	if (!str || !prefix) {
		return false;
	}

	size_t str_len = strlen(str);
	size_t prefix_len = strlen(prefix);

	if (str_len < prefix_len) {
		return false;
	}

	return !strncmp(str, prefix, prefix_len);
}

bool string_has_suffix(const char* str, const char* suffix)
{
	if (!str || !suffix) {
		return false;
	}

	size_t str_len = strlen(str);
	size_t suffix_len = strlen(suffix);

	if (str_len < suffix_len) {
		return false;
	}

	return !strcmp(str + str_len - suffix_len, suffix);
}

char *path_copy_basename(const char *path)
{
	char pathdup[strlen(path) + 1];
	strcpy(pathdup, path);
	return strdup(basename(pathdup));
}

char *path_copy_dirname(const char *path)
{
	char pathdup[strlen(path) + 1];
	strcpy(pathdup, path);
	return strdup(dirname(pathdup));
}

xpc_object_t xpc_object_from_plist(const char *path)
{
	if (!path) return NULL;
	int fd = open(path, O_RDONLY);
    if (fd < 0) return NULL;

    struct stat st = {0};
    if (fstat(fd, &st) != 0 || st.st_size == 0) {
        close(fd);
        return NULL;
    }

    void *data = mmap(NULL, st.st_size, PROT_READ, MAP_FILE | MAP_PRIVATE, fd, 0);
    close(fd);
    if (data == MAP_FAILED) return NULL;

    xpc_object_t plist = xpc_create_from_plist(data, st.st_size);
    if (plist == NULL) {
        char *plist_str = (char *)data;
        if (strnstr(plist_str, "bplist", st.st_size) ||
            strnstr(plist_str, "?xml", st.st_size) ||
            strnstr(plist_str, "!DOCTYPE plist", st.st_size)) {
            munmap(data, st.st_size);
            return NULL;
        }

        for (int i = 0; i < st.st_size; i++) {
            if (plist_str[i] < 0 || plist_str[i] > 127) {
                munmap(data, st.st_size);
                return NULL;
            }
        }

        nextstep_plist_t nextstep_plist = {0};
        nextstep_plist.index = 0;
        nextstep_plist.size = st.st_size;
        nextstep_plist.data = plist_str;
        plist = nxp_parse_object(&nextstep_plist);
    }

    munmap(data, st.st_size);
    return plist;
}

bool xpc_array_contains_string(xpc_object_t xArr, const char *string)
{
	if (!xArr) return false;

	__block bool found = false;
	xpc_array_apply(xArr, ^bool(size_t index, xpc_object_t value){
		if (xpc_get_type(value) == XPC_TYPE_STRING) {
			const char *thisString = xpc_string_get_string_ptr(value);
			if (!strcmp(thisString, string)) {
				found = true;
				return false;
			}
		}
		return true;
	});
	return found;
}

void parse_allow_deny_list(const char *listStr, xpc_object_t *arrOut)
{
	if (!listStr || !arrOut) return;

	xpc_object_t xArr = xpc_array_create(NULL, 0);
	char *listStrCopy = strdup(listStr);
	char *curString = strtok(listStrCopy, ":");
	while (curString != NULL) {
		xpc_array_set_string(xArr, XPC_ARRAY_APPEND, curString);
		curString = strtok(NULL, ":");
	}
	free(listStrCopy);

	*arrOut = xArr;
}

void load_global_preferences(xpc_object_t preferencesXdict, xpc_object_t processPreferencesXdict)
{
    xpc_object_t privileged = xpc_dictionary_get_value(preferencesXdict, kChoicyPrefsKeyPrivilegedTweaks);
    if (privileged && xpc_get_type(privileged) == XPC_TYPE_ARRAY) gPrivilegedTweaks = xpc_retain(privileged);
    xpc_object_t manual = xpc_dictionary_get_value(preferencesXdict, CH_MANUAL_PRIVILEGED_TWEAKS_KEY);
    if (manual && xpc_get_type(manual) == XPC_TYPE_ARRAY) gManualPrivilegedTweaks = xpc_retain(manual);
	bool overwriteGlobalConfig = false;
	char *overwriteEnvConfigStr = getenv(kEnvOverwriteGlobalConfigurationOverride);
	if (overwriteEnvConfigStr) {
		overwriteGlobalConfig = !strcmp(overwriteEnvConfigStr, "1");
	}
	else if (processPreferencesXdict && xpc_get_type(processPreferencesXdict) == XPC_TYPE_DICTIONARY) {
		overwriteGlobalConfig = xpc_dictionary_get_bool(processPreferencesXdict, kChoicyProcessPrefsKeyOverwriteGlobalTweakConfiguration);
	}

	if (!overwriteGlobalConfig) {
		xpc_object_t globalDeniedTweaks = xpc_dictionary_get_value(preferencesXdict, kChoicyPrefsKeyGlobalDeniedTweaks);
		if (globalDeniedTweaks && xpc_get_type(globalDeniedTweaks) == XPC_TYPE_ARRAY) {
			gGlobalDeniedTweaks = xpc_retain(globalDeniedTweaks);
		}
	}
}

void load_process_preferences(xpc_object_t preferencesXdict, xpc_object_t processPreferencesXdict)
{
    if (gLaunchMode != CHLaunchNormal) {
        gTweakInjectionDisabled = gLaunchMode == CHLaunchWithoutAllTweaks;
        return;
    }
    const char *name = strrchr(gExecutablePath, '/');
    bool forced = CHForcedInjection(gBundleIdentifier, name ? name + 1 : gExecutablePath);
    bool jailbreakApp = false;
    if (gProcessType == PROCESS_TYPE_APP && gBundleIdentifier) {
        char *directory = path_copy_dirname(gExecutablePath);
        char *appName = path_copy_basename(directory);
        char candidate[PATH_MAX];
        snprintf(candidate, sizeof(candidate), "%s/%s/Info.plist", jbroot("/Applications"), appName);
        xpc_object_t info = xpc_object_from_plist(candidate);
        if (info && xpc_get_type(info) == XPC_TYPE_DICTIONARY) {
            const char *identifier = xpc_dictionary_get_string(info, "CFBundleIdentifier");
            jailbreakApp = identifier && !strcmp(identifier, gBundleIdentifier);
        }
        if (info) xpc_release(info);
        free(appName);
        free(directory);
    }
    xpc_object_t enabled = processPreferencesXdict ? xpc_dictionary_get_value(processPreferencesXdict, kChoicyProcessPrefsKeyTweakInjectionEnabled) : NULL;
    bool valid = false, enabledValue = false;
    if (enabled && xpc_get_type(enabled) == XPC_TYPE_BOOL) { valid = true; enabledValue = xpc_bool_get_value(enabled); }
    else if (enabled && xpc_get_type(enabled) == XPC_TYPE_INT64) {
        int64_t value = xpc_int64_get_value(enabled);
        valid = value == 0 || value == 1; enabledValue = value == 1;
    }
    else if (enabled && xpc_get_type(enabled) == XPC_TYPE_DOUBLE) {
        double value = xpc_double_get_value(enabled);
        valid = value == 0.0 || value == 1.0; enabledValue = value == 1.0;
    }
    gTweakInjectionDisabled = !CHResolveInjection(forced, jailbreakApp, valid, enabledValue);
    if (getenv("_ChoicyInjectionEnabledFromSpringBoard")) gTweakInjectionDisabled = false;
    gDisablePrivilegedTweaks = CHProcessDisablesPrivilege(!gTweakInjectionDisabled,
        processPreferencesXdict && xpc_dictionary_get_bool(processPreferencesXdict, CH_DISABLE_PRIVILEGED_TWEAKS_KEY));
    if (gPrivilegeScopeAllowed && processPreferencesXdict) {
        gCustomPrivilegeEnabled = xpc_dictionary_get_bool(processPreferencesXdict, CH_CUSTOM_PRIVILEGE_ENABLED_KEY);
        gPrivilegeDenyMode = xpc_dictionary_get_int64(processPreferencesXdict, CH_CUSTOM_PRIVILEGE_MODE_KEY) == 2;
        xpc_object_t allowed = xpc_dictionary_get_value(processPreferencesXdict, CH_CUSTOM_PRIVILEGE_ALLOWED_KEY);
        xpc_object_t denied = xpc_dictionary_get_value(processPreferencesXdict, CH_CUSTOM_PRIVILEGE_DENIED_KEY);
        if (allowed && xpc_get_type(allowed) == XPC_TYPE_ARRAY) gPrivilegeAllowedTweaks = xpc_retain(allowed);
        if (denied && xpc_get_type(denied) == XPC_TYPE_ARRAY) gPrivilegeDeniedTweaks = xpc_retain(denied);
    }
    if (!processPreferencesXdict || gAllowedTweaks || gDeniedTweaks) return;

	bool customTweakConfigurationEnabled = xpc_dictionary_get_bool(processPreferencesXdict, kChoicyProcessPrefsKeyCustomTweakConfigurationEnabled);
	if (customTweakConfigurationEnabled) {
		int allowDenyMode = 1;
		xpc_object_t allowDenyModeVal = xpc_dictionary_get_value(processPreferencesXdict, kChoicyProcessPrefsKeyAllowDenyMode);
		if (allowDenyModeVal && xpc_get_type(allowDenyModeVal) == XPC_TYPE_INT64) {
			allowDenyMode = xpc_int64_get_value(allowDenyModeVal);
		}

		if (allowDenyMode == 2) {        
			xpc_object_t deniedTweaks = xpc_dictionary_get_value(processPreferencesXdict, kChoicyProcessPrefsKeyDeniedTweaks);
			if (deniedTweaks && xpc_get_type(deniedTweaks) == XPC_TYPE_ARRAY) {
				gDeniedTweaks = xpc_retain(deniedTweaks);
			}
		}
		else {                                          
			xpc_object_t allowedTweaks = xpc_dictionary_get_value(processPreferencesXdict, kChoicyProcessPrefsKeyAllowedTweaks);
			if (allowedTweaks && xpc_get_type(allowedTweaks) == XPC_TYPE_ARRAY) {
				gAllowedTweaks = xpc_retain(allowedTweaks);
			}
			else {
				gAllowedTweaks = xpc_array_create(NULL, 0);
			}
		}
	}
}

void load_process_info(void)
{
	                       
	uint32_t executablePathSize = 0;
	_NSGetExecutablePath(NULL, &executablePathSize);
	gExecutablePath = malloc(executablePathSize);
	_NSGetExecutablePath(gExecutablePath, &executablePathSize);

	                                                                                   
	if (!strcmp(gExecutablePath, "/usr/libexec/logd") || !strcmp(gExecutablePath, "/usr/sbin/notifyd")) gShouldLog = false;

	                    
	char *executableDir = path_copy_dirname(gExecutablePath);
	if (string_has_suffix(executableDir, ".app"))		 gProcessType = PROCESS_TYPE_APP;
	else if (string_has_suffix(executableDir, ".appex")) gProcessType = PROCESS_TYPE_PLUGIN;
	else												 gProcessType = PROCESS_TYPE_BINARY;

	os_log_dbg("Identified process type: %d\n", gProcessType);

	                              
	size_t infoPlistPathSize = strlen(executableDir) + strlen("/Info.plist") + 1;
	char infoPlistPath[infoPlistPathSize];
	strlcpy(infoPlistPath, executableDir, infoPlistPathSize);
	strlcat(infoPlistPath, "/Info.plist", infoPlistPathSize);
	free(executableDir);
	if ((gProcessType == PROCESS_TYPE_APP || gProcessType == PROCESS_TYPE_PLUGIN) ) {
		xpc_object_t infoXdict = xpc_object_from_plist(infoPlistPath);
        if (!infoXdict) infoXdict = xpc_object_from_plist(rootfs(infoPlistPath));
		if (infoXdict && xpc_get_type(infoXdict) == XPC_TYPE_DICTIONARY) {
			const char *bundleIdentifier = xpc_dictionary_get_string(infoXdict, "CFBundleIdentifier");
			if (bundleIdentifier) {
				gBundleIdentifier = strdup(bundleIdentifier);
				os_log_dbg("Identified bundle identifier: %{PUBLIC}s", gBundleIdentifier);
			}
			xpc_release(infoXdict);
		}
	}

    gLaunchMode = CHLaunchModeForProcess(getenv(CH_LAUNCH_MODE_ENV), getenv(CH_LAUNCH_TARGET_ENV),
        gBundleIdentifier, gProcessType == PROCESS_TYPE_APP);
    gPrivilegeScopeAllowed = CHPrivilegeScopeAllows(gProcessType == PROCESS_TYPE_APP,
        gBundleIdentifier, getenv(CH_PRIVILEGED_APP_ENV));
	                                   
	parse_allow_deny_list(getenv(kEnvDeniedTweaksOverride), &gDeniedTweaks);
	parse_allow_deny_list(getenv(kEnvAllowedTweaksOverride), &gAllowedTweaks);

	if (gDeniedTweaks && gShouldLog && os_log_debug_enabled(OS_LOG_DEFAULT)) {
		char *gDeniedTweaksDesc = xpc_copy_description(gDeniedTweaks);
		os_log_dbg("Loaded denied tweaks from environment: %{PUBLIC}s", gDeniedTweaksDesc ?: "<none>");
		if (gDeniedTweaksDesc) free(gDeniedTweaksDesc);
	}
	if (gAllowedTweaks && gShouldLog && os_log_debug_enabled(OS_LOG_DEFAULT)) {
		char *gAllowedTweaksDesc = xpc_copy_description(gAllowedTweaks);
		os_log_dbg("Loaded allowed tweaks from environment: %{PUBLIC}s", gAllowedTweaksDesc ?: "<none>");
		if (gAllowedTweaksDesc) free(gAllowedTweaksDesc);
	}

	                   
	xpc_object_t preferencesXdict = xpc_object_from_plist(kChoicyPrefsPlistPath);
    xpc_object_t processPreferencesXdict = NULL;
	if (preferencesXdict) {
		if (xpc_get_type(preferencesXdict) == XPC_TYPE_DICTIONARY) {


			if (gBundleIdentifier) {
				xpc_object_t appPreferencesXdict = xpc_dictionary_get_value(preferencesXdict, kChoicyPrefsKeyAppSettings);
				if (appPreferencesXdict && xpc_get_type(appPreferencesXdict) == XPC_TYPE_DICTIONARY) {
					xpc_object_t thisAppXdict = xpc_dictionary_get_value(appPreferencesXdict, gBundleIdentifier);
					if (thisAppXdict && xpc_get_type(thisAppXdict) == XPC_TYPE_DICTIONARY) {
						processPreferencesXdict = thisAppXdict;
					}
				}
			}
			else {
				xpc_object_t daemonPreferencesXdict = xpc_dictionary_get_value(preferencesXdict, kChoicyPrefsKeyDaemonSettings);
				if (daemonPreferencesXdict && xpc_get_type(daemonPreferencesXdict) == XPC_TYPE_DICTIONARY) {
					const char *executableName = strrchr(gExecutablePath, '/');
					if (executableName) {
						xpc_object_t thisDaemonXdict = xpc_dictionary_get_value(daemonPreferencesXdict, &executableName[1]);
						if (thisDaemonXdict && xpc_get_type(thisDaemonXdict) == XPC_TYPE_DICTIONARY) {
							processPreferencesXdict = thisDaemonXdict;
						}
					}
				}
			}

			if (processPreferencesXdict && gShouldLog && os_log_debug_enabled(OS_LOG_DEFAULT)) {
				char *processPreferencesXdictDesc = xpc_copy_description(processPreferencesXdict);
				os_log_dbg("Loaded process preferences: %{PUBLIC}s", processPreferencesXdictDesc ?: "<none>");
				if (processPreferencesXdictDesc) free(processPreferencesXdictDesc);
			}

			                          
			load_global_preferences(preferencesXdict, processPreferencesXdict);
			if (gGlobalDeniedTweaks && gShouldLog && os_log_debug_enabled(OS_LOG_DEFAULT)) {
				char *gGlobalDeniedTweaksDesc = xpc_copy_description(gGlobalDeniedTweaks);
				os_log_dbg("Loaded globally denied tweaks: %{PUBLIC}s", gGlobalDeniedTweaksDesc ?: "<none>");
				if (gGlobalDeniedTweaksDesc) free(gGlobalDeniedTweaksDesc);
			}


		}
		load_process_preferences(preferencesXdict, processPreferencesXdict);
		xpc_release(preferencesXdict);
	}
	else {
        load_process_preferences(NULL, NULL);
        os_log_err("Choicy-Whitelist: no preferences, using default policy");
    }
}

bool dylib_is_tweak(const char *dylibPath, bool *isUIKitOut)
{
	*isUIKitOut = false;
	if (!dylibPath) return false;

	__block bool isTweak = false;
	if (strstr(dylibPath, "/TweakInject/") || strstr(dylibPath, "/MobileSubstrate/DynamicLibraries/")) {
		size_t dylibPathLength = strlen(dylibPath)+1;
		char plistPath[dylibPathLength];
		strcpy(plistPath, dylibPath);
		strlcpy(&plistPath[dylibPathLength - 6], "plist", 6);

		if (access(plistPath, R_OK) == 0) {
			xpc_object_t tweakPlist = xpc_object_from_plist(plistPath);
			if (tweakPlist) {
				xpc_object_t filterXdict = xpc_dictionary_get_value(tweakPlist, "Filter");
				if (filterXdict && xpc_get_type(filterXdict) == XPC_TYPE_DICTIONARY) {
                    xpc_object_t bundles = xpc_dictionary_get_value(filterXdict, "Bundles");
                    if (bundles && xpc_get_type(bundles) == XPC_TYPE_ARRAY) {
                        for (size_t i = 0; i < xpc_array_get_count(bundles); i++) {
                            xpc_object_t item = xpc_array_get_value(bundles, i);
                            if (item && xpc_get_type(item) == XPC_TYPE_STRING && CHIsUIKitBundle(xpc_string_get_string_ptr(item))) {
                                *isUIKitOut = true;
                                break;
                            }
                        }
                    }
					xpc_dictionary_apply(filterXdict, ^bool(const char *key, xpc_object_t value) {
						if (value && xpc_get_type(value) == XPC_TYPE_ARRAY) {
							if (xpc_array_get_count(value) > 0) {
								isTweak = true;
								return false;
							}
						}
						return true;
					});
				}
				xpc_release(tweakPlist);
			}
		}
	}
	return isTweak;
}

bool should_load_dylib(const char *dylibPath)
{
	if (!string_has_suffix(dylibPath, ".dylib")) return true;

	char *dylibNameHeap = path_copy_basename(dylibPath);
	char dylibName[strlen(dylibNameHeap)+1];
	strcpy(dylibName, dylibNameHeap);
	free(dylibNameHeap);

	dylibName[strlen(dylibName)-6] = '\0';

	if (!strcmp(dylibName, "   ChoicyWhitelist") || !strcmp(dylibName, "MobileSafety")) return true;
    const char *executableName = strrchr(gExecutablePath, '/');
    executableName = executableName ? executableName + 1 : gExecutablePath;
    if (!strcmp(dylibName, "ChoicyWhitelistSB") && !strcmp(executableName, "runningboardd")) return true;

	os_log_dbg("Checking whether %{public}s.dylib should be loaded...", dylibName);

    bool isUIKit = false;
	if (dylib_is_tweak(dylibPath, &isUIKit)) {
        if (gLaunchMode != CHLaunchNormal) {
            return CHShouldLoadManagedTweakForLaunch(gLaunchMode, !gTweakInjectionDisabled,
                false, false, false, false, false);
        }
		                                           
		if (gProcessType == PROCESS_TYPE_APP) {
			if (gBundleIdentifier && !strcmp(gBundleIdentifier, kPreferencesBundleID)) {
				if (!strcmp(dylibName, "PreferenceLoader") || !strcmp(dylibName, "preferred")) {
					os_log_dbg("%{public}s.dylib ✅ (crucial)", dylibName);
					return true;
				}
			}
			else if (gBundleIdentifier && !strcmp(gBundleIdentifier, kSpringboardBundleID)) {
				if (!strcmp(dylibName, "ChoicyWhitelistSB")) {
					os_log_dbg("%{public}s.dylib ✅ (crucial)", dylibName);
					return true;
				}
			}
		}

		bool tweakIsAllowed = xpc_array_contains_string(gAllowedTweaks, dylibName);
		bool tweakIsDenied = xpc_array_contains_string(gDeniedTweaks, dylibName);
		bool tweakIsGloballyDenied = xpc_array_contains_string(gGlobalDeniedTweaks, dylibName);
        bool privileged = gPrivilegeScopeAllowed &&
            CHPrivilegeApplies(isUIKit, xpc_array_contains_string(gManualPrivilegedTweaks, dylibName),
                xpc_array_contains_string(gPrivilegedTweaks, dylibName));

        if (!CHShouldLoadConfiguredTweak(gLaunchMode, !gTweakInjectionDisabled, privileged,
            gDisablePrivilegedTweaks, gCustomPrivilegeEnabled, gPrivilegeDenyMode,
            xpc_array_contains_string(gPrivilegeAllowedTweaks, dylibName),
            xpc_array_contains_string(gPrivilegeDeniedTweaks, dylibName),
            tweakIsGloballyDenied, gAllowedTweaks != NULL, tweakIsAllowed, tweakIsDenied)) {
            os_log_dbg("%{public}s.dylib ❌ (process / privilege / global / custom policy)", dylibName);
            return false;
        }
	}
	else {
		os_log_dbg("%{public}s.dylib ✅ (not a tweak)", dylibName);
		return true;
	}

	os_log_dbg("%{public}s.dylib ✅ (allowed)", dylibName);
	return true;
}

void *(*dlopen_from_orig)(const char*, int, void *) = NULL;
void *dlopen_from_hook(const char *path, int mode, void *lr)
{
	if (path) {
		if (!should_load_dylib(path)) {
			return NULL;
		}
	}
	return dlopen_from_orig(path, mode, lr);
}

void *(*dyld_dlopen_from_orig)(const void *, const char*, int, void *) = NULL;
void *dyld_dlopen_from_hook(const void *dyld, const char *path, int mode, void *lr)
{
	if (path) {
		if (!should_load_dylib(path)) {
			return NULL;
		}
	}
	return dyld_dlopen_from_orig(dyld, path, mode, lr);
}

const struct mach_header *find_tweak_loader_mach_header(const char **pathOut)
{
	const char *tweakLoaderPaths[] = {
		jbroot("/usr/lib/TweakLoader.dylib"),													                               
		jbroot("/usr/lib/substitute-loader.dylib"),											              
		jbroot("/usr/lib/TweakInject.dylib"),													             
		jbroot("/usr/lib/substrate/SubstrateLoader.dylib"),									             
		jbroot("/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateLoader.dylib"),                              
		jbroot("/usr/lib/Sonar/libsonar.dylib"),												         
	};

	bool foundTweakLoader = false;
	struct stat tweakLoaderStat;
	for (int k = 0; k < sizeof(tweakLoaderPaths) / sizeof(*tweakLoaderPaths); k++) {
		if (access(tweakLoaderPaths[k], F_OK) == 0) {
			stat(tweakLoaderPaths[k], &tweakLoaderStat);
			foundTweakLoader = true;
			break;
		}
	}

	if (!foundTweakLoader) return NULL;

	for (int i = 0; i < _dyld_image_count(); i++) {
		const char *path = _dyld_get_image_name(i);
		struct stat pathStat;
		if (stat(path, &pathStat) == 0) {
			if (pathStat.st_dev == tweakLoaderStat.st_dev && pathStat.st_ino == tweakLoaderStat.st_ino) {
				os_log_dbg("Found tweak loader: %{public}s\n", path);
				if (pathOut) *pathOut = path;
				return _dyld_get_image_header(i);
			}
		}
	}

	return NULL;
}

int dyld_hook_routine(void **dyld, int idx, void *hook, void **orig, uint16_t pacSalt)
{
	if (!dyld) return -1;

	__unused uint64_t dyldPacDiversifier = ((uint64_t)dyld & ~(0xFFFFull << 48)) | (0x63FAull << 48);
	void **dyldFuncPtrs = ptrauth_auth_data(*dyld, ptrauth_key_process_independent_data, dyldPacDiversifier);
	if (!dyldFuncPtrs) return -1;

	if (vm_protect(mach_task_self_, (mach_vm_address_t)&dyldFuncPtrs[idx], sizeof(void *), false, VM_PROT_READ | VM_PROT_WRITE) == 0) {
	                                                                                                                                
	} else if (vm_protect(mach_task_self_, (mach_vm_address_t)&dyldFuncPtrs[idx], sizeof(void *), false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == 0) {
	} else {
		abort();
	}
	{
		uint64_t location = (uint64_t)&dyldFuncPtrs[idx];
		__unused uint64_t pacDiversifier = (location & ~(0xFFFFull << 48)) | ((uint64_t)pacSalt << 48);

		*orig = ptrauth_auth_and_resign(dyldFuncPtrs[idx], ptrauth_key_process_independent_code, pacDiversifier, ptrauth_key_function_pointer, 0);
		dyldFuncPtrs[idx] = ptrauth_auth_and_resign(hook, ptrauth_key_function_pointer, 0, ptrauth_key_process_independent_code, pacDiversifier);
		vm_protect(mach_task_self_, (mach_vm_address_t)&dyldFuncPtrs[idx], sizeof(void *), false, VM_PROT_READ);
		return 0;
	}

	return -1;
}

int replace_bss_pointers(const struct mach_header *mh, void *pointersToReplace[], void *replacementPointers[], uint32_t pointerCount)
{
	unsigned long bssSectionSize = 0;
	uint8_t *bssSection = getsectiondata((void *)mh, "__DATA", "__bss", &bssSectionSize);
	if (!bssSection) return 0;

	int replacementCount = 0;
	void **bssPtrs = (void **)bssSection;
	uint32_t bssPtrCount = (bssSectionSize / 8);
	for (uint32_t i = 0; i < bssPtrCount; i++) {
		void *curPtr = bssPtrs[i];
		for (uint32_t k = 0; k < pointerCount; k++) {
			if ((uintptr_t)curPtr == (uintptr_t)pointersToReplace[k]) {
				bssPtrs[i] = replacementPointers[k];
				replacementCount++;
			}
		}
	}
	return replacementCount;
}

__attribute__((constructor)) static void initializer(void)
{
	load_process_info();
	os_log_dbg("Choicy loaded");

	if (gLaunchMode != CHLaunchWithAllTweaks &&
        (gTweakInjectionDisabled || gAllowedTweaks || gDeniedTweaks || gGlobalDeniedTweaks || gCustomPrivilegeEnabled)) {
		os_log_dbg("Initializing Choicy...");

		void **dyld4Struct = litehook_find_dsc_symbol("/usr/lib/system/libdyld.dylib", "__ZN5dyld45gDyldE");
		if (dyld4Struct) {
			          
			                                                                                                 
			                                     

			dyld_hook_routine(*dyld4Struct, 14, (void *)&dyld_dlopen_hook, (void **)&dyld_dlopen_orig, 0xBF31);
			dyld_hook_routine(*dyld4Struct, 97, (void *)&dyld_dlopen_from_hook, (void **)&dyld_dlopen_from_orig, 0xD48C);
		}
		else {
			           
			                                                                                
			                                                                      

			void *libdyldHandle = dlopen("/usr/lib/system/libdyld.dylib", RTLD_NOW);
			void *dlopen_from = dlsym(libdyldHandle, "dlopen_from");

			dlopen_orig = dlopen;
			if (dlopen_from) dlopen_from_orig = dlopen_from;

			const char *tweakLoaderPath = NULL;
			const struct mach_header *tweakLoaderHeader = find_tweak_loader_mach_header(&tweakLoaderPath);
			if (tweakLoaderHeader) {
				                                                                                            
				                                                                                                                
				                                                                                                           
				if (!strcmp(tweakLoaderPath, "/usr/lib/substitute-loader.dylib")) {
					void *pointersToReplace[] = {
						dlopen,
						dlopen_from,
					};

					void *replacementPointers[] = {
						dlopen_hook,
						dlopen_from_hook,
					};

					uint32_t pointerCount = sizeof(pointersToReplace) / sizeof(*pointersToReplace);
					if (!dlopen_from) pointerCount--;
					__unused int c = replace_bss_pointers(tweakLoaderHeader, pointersToReplace, replacementPointers, pointerCount);
					os_log_dbg("Replaced %u dlopen/dlopen_from pointer(s) in bss section", c);

					                                                                                                                                 
				}
#ifdef __arm64e__
				                                                                                    
				                                               
				litehook_rebind_symbol((const mach_header_u *)tweakLoaderHeader, dlopen, dlopen_hook, NULL);
				if (dlopen_from) {
					litehook_rebind_symbol((const mach_header_u *)tweakLoaderHeader, dlopen_from, dlopen_from_hook, NULL);
				}
				return;
#endif
				                                                                                                       
				static struct dyld_interpose_tuple interposes[2];
				interposes[0] = (struct dyld_interpose_tuple){ .replacement = dlopen_hook, .replacee = dlopen };
				if (dlopen_from) {
					interposes[1] = (struct dyld_interpose_tuple){ .replacement = dlopen_from_hook, .replacee = dlopen_from };
				}
				dyld_dynamic_interpose(tweakLoaderHeader, interposes, dlopen_from ? 2 : 1);
				os_log_dbg("Initialized %u interpose(s) in tweak loader", dlopen_from ? 2 : 1);
			}
			else {
				os_log_dbg("Unable to find tweak loader");
			}
		}
	}
}
