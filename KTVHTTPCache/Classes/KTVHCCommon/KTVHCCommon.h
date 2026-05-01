//
//  KTVHCCommon.h
//  KTVHTTPCache
//
//  Created by Gary on 2025/9/4.
//  Copyright © 2025 Single. All rights reserved.
//

#if TARGET_OS_OSX
    #define KTVHC_MAC 1
#else
    #define KTVHC_MAC 0
#endif

#if TARGET_OS_IOS
    #define KTVHC_IOS 1
#else
    #define KTVHC_IOS 0
#endif

#if TARGET_OS_TV
    #define kTVHC_TV 1
#else
    #define kTVHC_TV 0
#endif

#ifdef TARGET_OS_VISION
#if TARGET_OS_VISION
    #define KTVHC_VISION 1
#endif
#endif

#if KTVHC_IOS || kTVHC_TV || KTVHC_VISION
    #define KTVHC_UIKIT 1
#else
    #define KTVHC_UIKIT 0
#endif

#if KTVHC_MAC
    #define KTVHC_APPKIT 1
#else
    #define KTVHC_APPKIT 0
#endif
