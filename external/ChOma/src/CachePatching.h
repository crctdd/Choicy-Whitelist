/* -*- mode: C++; c-basic-offset: 4; tab-width: 4 -*-
 *
 * Copyright (c) 2003-2010 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */
#ifndef _CACHE_PATCHING_H_
#define _CACHE_PATCHING_H_

#include <stdint.h>

struct dyld_cache_patch_info_v1
{
    uint64_t    patchTableArrayAddr;
    uint64_t    patchTableArrayCount;
    uint64_t    patchExportArrayAddr;
    uint64_t    patchExportArrayCount;
    uint64_t    patchLocationArrayAddr;
    uint64_t    patchLocationArrayCount;
    uint64_t    patchExportNamesAddr;
    uint64_t    patchExportNamesSize;
};

struct dyld_cache_image_patches_v1
{
    uint32_t    patchExportsStartIndex;
    uint32_t    patchExportsCount;
};

struct dyld_cache_patchable_export_v1
{
    uint32_t            cacheOffsetOfImpl;
    uint32_t            patchLocationsStartIndex;
    uint32_t            patchLocationsCount;
    uint32_t            exportNameOffset;
};

struct dyld_cache_patchable_location_v1
{
    uint32_t            cacheOffset;
    uint64_t            high7                   : 7,
                        addend                  : 5,
                        authenticated           : 1,
                        usesAddressDiversity    : 1,
                        key                     : 2,
                        discriminator           : 16;
};

struct dyld_cache_patch_info_v2
{
    uint32_t    patchTableVersion;
    uint32_t    patchLocationVersion;
    uint64_t    patchTableArrayAddr;
    uint64_t    patchTableArrayCount;
    uint64_t    patchImageExportsArrayAddr;
    uint64_t    patchImageExportsArrayCount;
    uint64_t    patchClientsArrayAddr;
    uint64_t    patchClientsArrayCount;
    uint64_t    patchClientExportsArrayAddr;
    uint64_t    patchClientExportsArrayCount;
    uint64_t    patchLocationArrayAddr;
    uint64_t    patchLocationArrayCount;
    uint64_t    patchExportNamesAddr;
    uint64_t    patchExportNamesSize;
};

struct dyld_cache_image_patches_v2
{
    uint32_t    patchClientsStartIndex;
    uint32_t    patchClientsCount;
    uint32_t    patchExportsStartIndex;
    uint32_t    patchExportsCount;
};

struct dyld_cache_image_export_v2
{
    uint32_t    dylibOffsetOfImpl;
    uint32_t    exportNameOffset : 28;
    uint32_t    patchKind        : 4;
};

struct dyld_cache_image_clients_v2
{
    uint32_t    clientDylibIndex;
    uint32_t    patchExportsStartIndex;
    uint32_t    patchExportsCount;
};

struct dyld_cache_patchable_export_v2
{
    uint32_t    imageExportIndex;
    uint32_t    patchLocationsStartIndex;
    uint32_t    patchLocationsCount;
};

struct dyld_cache_patchable_location_v2
{
    uint32_t    dylibOffsetOfUse;
    uint32_t    high7                   : 7,
                addend                  : 5,
                authenticated           : 1,
                usesAddressDiversity    : 1,
                key                     : 2,
                discriminator           : 16;
};

struct dyld_cache_patch_info_v3
{
	struct dyld_cache_patch_info_v2 infoV2;

    uint64_t    gotClientsArrayAddr;
    uint64_t    gotClientsArrayCount;
    uint64_t    gotClientExportsArrayAddr;
    uint64_t    gotClientExportsArrayCount;
    uint64_t    gotLocationArrayAddr;
    uint64_t    gotLocationArrayCount;
};

struct dyld_cache_image_got_clients_v3
{
    uint32_t    patchExportsStartIndex;
    uint32_t    patchExportsCount;
};

struct dyld_cache_patchable_export_v3
{
    uint32_t    imageExportIndex;
    uint32_t    patchLocationsStartIndex;
    uint32_t    patchLocationsCount;
};

struct dyld_cache_patchable_location_v3
{
    uint64_t    cacheOffsetOfUse;
    uint32_t    high7                   : 7,
                addend                  : 5,
                authenticated           : 1,
                usesAddressDiversity    : 1,
                key                     : 2,
                discriminator           : 16;
};

struct dyld_cache_patchable_location_v4
{
    uint64_t    dylibOffsetOfUse;
    union {
        struct {
			uint32_t    authenticated           : 1,
                    	high7                   : 7,
                    	isWeakImport            : 1,
                    	addend                  : 5,
                    	usesAddressDiversity    : 1,
                    	keyIsD                  : 1,
                    	discriminator           : 16;
		} auth;
        struct {
			uint32_t    authenticated           : 1,
                    	high7                   : 7,
                    	isWeakImport            : 1,
                    	addend                  : 23;
		} regular;
    };
};

#endif

