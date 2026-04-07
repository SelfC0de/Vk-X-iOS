import Foundation

// MARK: - Enums (Android parity)
enum TypeStatus: String, CaseIterable {
    case none         = "none"
    case typing       = "typing"
    case audioMessage = "audiomessage"
    case videoMessage = "videomessage"
    case photo        = "photo"
    case file         = "file"

    var label: String {
        switch self {
        case .none:         return "Отключено"
        case .typing:       return "Печатает..."
        case .audioMessage: return "Записывает голосовое"
        case .videoMessage: return "Записывает видео"
        case .photo:        return "Загружает фото"
        case .file:         return "Отправляет файл"
        }
    }
    var emoji: String {
        switch self {
        case .none: return "❌"; case .typing: return "⌨️"
        case .audioMessage: return "🎤"; case .videoMessage: return "📹"
        case .photo: return "📸"; case .file: return "📎"
        }
    }
}

enum DeviceProfile: String, CaseIterable {
    case kate    = "kate"
    case android = "android"
    case iphone  = "iphone"
    case windows = "windows"

    var label: String {
        switch self {
        case .kate:    return "Kate Mobile"
        case .android: return "VK Android"
        case .iphone:  return "VK iPhone"
        case .windows: return "VK Windows"
        }
    }
    var ua: String {
        switch self {
        case .kate:
            return "KateMobileAndroid/56 lite-460 (Android 4.4.2; SDK 19; x86; unknown Android SDK built for x86; en)"
        case .android:
            return "VKAndroidApp/7.43-15079 (Android 12; SDK 31; arm64-v8a; Samsung Galaxy S21; ru; 2960x1440)"
        case .iphone:
            return "com.vk.vkclient/2316 CFNetwork/1240.0.4 Darwin/20.6.0"
        case .windows:
            return "VKDesktopApp/6.8.0 (Windows; 10; 19042)"
        }
    }
    var uaPreview: String { String(ua.prefix(52)) + "…" }
}

// MARK: - Hardware Spoofing
struct SpoofedDevice {
    let model: String; let brand: String
    let androidVersion: String; let sdkVersion: Int
    let screenWidth: Int; let screenHeight: Int
    let dpi: Int; let batteryLevel: Int; let userAgent: String

    var headers: [String: String] {
        [
            "User-Agent":          userAgent,
            "X-VK-Android-Client": "new",
            "X-Screen-Width":      "\(screenWidth)",
            "X-Screen-Height":     "\(screenHeight)",
            "X-Screen-DPI":        "\(dpi)",
            "X-Battery-Level":     "\(batteryLevel)",
            "X-Android-SDK":       "\(sdkVersion)",
            "X-Device-Model":      model,
        ]
    }
}

enum HardwareSpoofing {
    private static let devices: [(String, String, [(String, Int)])] = [
        ("Samsung Galaxy S23",    "samsung", [("13",33),("14",34)]),
        ("Samsung Galaxy S22",    "samsung", [("13",33),("12",32)]),
        ("Samsung Galaxy A54",    "samsung", [("13",33),("14",34)]),
        ("Google Pixel 7",        "google",  [("13",33),("14",34)]),
        ("Google Pixel 7a",       "google",  [("13",33),("14",34)]),
        ("Google Pixel 6",        "google",  [("12",32),("13",33)]),
        ("Xiaomi 13",             "xiaomi",  [("13",33)]),
        ("Xiaomi Redmi Note 12",  "xiaomi",  [("12",32),("13",33)]),
        ("OnePlus 11",            "oneplus", [("13",33)]),
        ("Realme GT 5",           "realme",  [("13",33)]),
    ]
    private static let screens: [(Int,Int,Int)] = [
        (1080,2340,420),(1080,2400,440),(1440,3200,560),
        (1080,2316,400),(1080,2408,420),(1440,3088,515),
    ]

    static func generate() -> SpoofedDevice {
        let (model, brand, versions) = devices.randomElement()!
        let (ver, sdk) = versions.randomElement()!
        let (w, h, dpi) = screens.randomElement()!
        let battery = Int.random(in: 15...94)
        let ua = "VKAndroidApp/8.10-17315 (Android \(ver); SDK \(sdk); arm64-v8a; \(brand) \(model); ru; \(w)x\(h))"
        return SpoofedDevice(model: model, brand: brand, androidVersion: ver,
                             sdkVersion: sdk, screenWidth: w, screenHeight: h,
                             dpi: dpi, batteryLevel: battery, userAgent: ua)
    }
}

// MARK: - SettingsStore
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let ud = UserDefaults.standard

    // Privacy — Режим невидимки
    @Published var ghostMode:       Bool { didSet { ud.set(ghostMode,       forKey: "ghost_mode")       } }
    @Published var antiTyping:      Bool { didSet { ud.set(antiTyping,      forKey: "anti_typing")      } }
    @Published var forceOffline:    Bool { didSet { ud.set(forceOffline,    forKey: "force_offline")    } }
    @Published var ghostOnline:     Bool { didSet { ud.set(ghostOnline,     forKey: "ghost_online")     } }
    @Published var ghostStory:      Bool { didSet { ud.set(ghostStory,      forKey: "ghost_story")      } }

    // Privacy — Антислежка
    @Published var antiTelemetry:   Bool { didSet { ud.set(antiTelemetry,   forKey: "anti_telemetry")   } }
    @Published var antiScreen:      Bool { didSet { ud.set(antiScreen,      forKey: "anti_screen")      } }
    @Published var bypassLinks:     Bool { didSet { ud.set(bypassLinks,     forKey: "bypass_links")     } }
    @Published var bypassShortUrl:  Bool { didSet { ud.set(bypassShortUrl,  forKey: "bypass_short_url") } }

    // Engine — Anti-Ban
    @Published var antiBan:         Bool { didSet { ud.set(antiBan,         forKey: "anti_ban")         } }
    @Published var offlinePost:     Bool { didSet { ud.set(offlinePost,     forKey: "offline_post")     } }
    @Published var bypassActivity:  Bool { didSet { ud.set(bypassActivity,  forKey: "bypass_activity")  } }
    @Published var longPollOnly:    Bool { didSet { ud.set(longPollOnly,    forKey: "longpoll_only")    } }

    // Engine — Silent VM
    @Published var silentVm:        Bool { didSet { ud.set(silentVm,        forKey: "silent_vm")        } }

    // Engine — Type Status Changer
    @Published var typeStatus:      String { didSet { ud.set(typeStatus,    forKey: "type_status")      } }

    // Engine — Bypass Copy
    @Published var bypassCopy:      Bool { didSet { ud.set(bypassCopy,     forKey: "bypass_copy")      } }

    // Local Privacy
    @Published var hideSender:      Bool { didSet { ud.set(hideSender,      forKey: "hide_sender")      } }
    @Published var blurScreen:      Bool { didSet { ud.set(blurScreen,      forKey: "blur_screen")      } }
    @Published var spoofAdId:        Bool { didSet { ud.set(spoofAdId,        forKey: "spoof_ad_id")      } }
    @Published var blockWifi:        Bool { didSet { ud.set(blockWifi,        forKey: "block_wifi")       } }
    @Published var spoofCarrier:       Bool { didSet { ud.set(spoofCarrier,       forKey: "spoof_carrier")      } }
    @Published var antiLinkPreview:    Bool { didSet { ud.set(antiLinkPreview,    forKey: "anti_link_preview") } }
    @Published var ghostForward:       Bool { didSet { ud.set(ghostForward,       forKey: "ghost_forward")     } }
    @Published var spoofDeviceModel:   Bool { didSet { ud.set(spoofDeviceModel,   forKey: "spoof_device_model") } }

    // Profile history (stored as JSON array of ids)
    @Published var profileHistory:  [Int] { didSet {
        ud.set(try? JSONEncoder().encode(profileHistory), forKey: "profile_history")
    }}

    // Notifications
    @Published var typePush:             Bool   { didSet { ud.set(typePush,             forKey: "type_push")             } }
    @Published var notifyStyle:          String { didSet { ud.set(notifyStyle,          forKey: "notify_style")           } } // "default" | "center" | "slide"
    @Published var tabBarStyle:          String { didSet { ud.set(tabBarStyle,          forKey: "tab_bar_style")          } } // "default" | "liquid" | "island" | "neon" | "ticker" | "gravity"
    // Predict Push System — filter settings
    @Published var predictFilterGroups:  Bool   { didSet { ud.set(predictFilterGroups,  forKey: "predict_filter_groups")  } } // ignore group chats
    @Published var predictMinGroupSize:  Int    { didSet { ud.set(predictMinGroupSize,  forKey: "predict_min_group_size") } } // ignore groups with N+ members
    @Published var predictOnlyDMs:       Bool   { didSet { ud.set(predictOnlyDMs,       forKey: "predict_only_dms")       } } // only direct messages
    @Published var predictFavoritesOnly: Bool   { didSet { ud.set(predictFavoritesOnly, forKey: "predict_favorites_only") } } // only favourite contacts
    @Published var predictFavoriteIds:   [Int]  { didSet {
        ud.set(try? JSONEncoder().encode(predictFavoriteIds), forKey: "predict_favorite_ids")
    }}

    // Device
    @Published var hardwareSpoof:   Bool { didSet { ud.set(hardwareSpoof,   forKey: "hardware_spoof")   } }
    @Published var liquidGlass:     Bool   { didSet { ud.set(liquidGlass,     forKey: "liquid_glass")     } }

    // Visual
    @Published var weatherGarland: Bool { didSet { ud.set(weatherGarland, forKey: "weather_garland") } }
    @Published var weatherRain:    Bool { didSet { ud.set(weatherRain,    forKey: "weather_rain")    } }
    @Published var weatherSnow:    Bool { didSet { ud.set(weatherSnow,    forKey: "weather_snow")    } }
    @Published var weatherFog:     Bool { didSet { ud.set(weatherFog,     forKey: "weather_fog")     } }
    @Published var weatherLeaves:  Bool { didSet { ud.set(weatherLeaves,  forKey: "weather_leaves")  } }
    @Published var weatherSakura:  Bool { didSet { ud.set(weatherSakura,  forKey: "weather_sakura")  } }
    @Published var weatherAurora:  Bool { didSet { ud.set(weatherAurora,  forKey: "weather_aurora")  } }
    @Published var weatherBubbles: Bool { didSet { ud.set(weatherBubbles, forKey: "weather_bubbles") } }
    @Published var weatherStars:   Bool { didSet { ud.set(weatherStars,   forKey: "weather_stars")   } }
    @Published var weatherFire:    Bool { didSet { ud.set(weatherFire,    forKey: "weather_fire")    } }
    @Published var weatherPixels:  Bool { didSet { ud.set(weatherPixels,  forKey: "weather_pixels")  } }
    @Published var showPet:        Bool   { didSet { ud.set(showPet,        forKey: "show_pet")         } }
    @Published var petType:        String { didSet { ud.set(petType,        forKey: "pet_type")         } }
    // Avatar shape settings
    @Published var avatarShape:         String { didSet { ud.set(avatarShape,         forKey: "avatar_shape")            } }
    @Published var avatarGlow:          Bool   { didSet { ud.set(avatarGlow,          forKey: "avatar_glow")             } }
    @Published var avatarGlowIntensity: Double { didSet { ud.set(avatarGlowIntensity, forKey: "avatar_glow_intensity")   } }
    // Per-shape stroke colors
    @Published var avatarColorCircle:   String { didSet { ud.set(avatarColorCircle,   forKey: "avatar_color_circle")     } }
    @Published var avatarColorNft:      String { didSet { ud.set(avatarColorNft,      forKey: "avatar_color_nft")        } }
    @Published var avatarColorRhomb:    String { didSet { ud.set(avatarColorRhomb,    forKey: "avatar_color_rhomb")      } }
    // Per-shape glow colors
    @Published var avatarGlowCircle:    String { didSet { ud.set(avatarGlowCircle,    forKey: "avatar_glow_circle")      } }
    @Published var avatarGlowNft:       String { didSet { ud.set(avatarGlowNft,       forKey: "avatar_glow_nft")         } }
    @Published var avatarGlowRhomb:     String { didSet { ud.set(avatarGlowRhomb,     forKey: "avatar_glow_rhomb")       } }
    // Status Changer
    @Published var statusChangerText:     String { didSet { ud.set(statusChangerText,     forKey: "status_changer_text")     } }
    @Published var statusChangerMode:     String { didSet { ud.set(statusChangerMode,     forKey: "status_changer_mode")     } } // "local" | "server"
    @Published var statusChangerPrevious: String { didSet { ud.set(statusChangerPrevious, forKey: "status_changer_prev")     } }
    @Published var statusChangerApplied:  Bool   { didSet { ud.set(statusChangerApplied,  forKey: "status_changer_applied")  } }

    // Computed: current shape color
    var avatarColorHex: String {
        switch avatarShape {
        case "nft":   return avatarColorNft
        case "rhomb": return avatarColorRhomb
        default:      return avatarColorCircle
        }
    }
    var avatarGlowHex: String {
        switch avatarShape {
        case "nft":   return avatarGlowNft
        case "rhomb": return avatarGlowRhomb
        default:      return avatarGlowCircle
        }
    }
    @Published var showClock:       Bool   { didSet { ud.set(showClock,       forKey: "show_clock")       } }
    @Published var clockStyle:      String { didSet { ud.set(clockStyle,      forKey: "clock_style")      } }
    @Published var clockAmPm:       Bool   { didSet { ud.set(clockAmPm,       forKey: "clock_ampm")       } }
    @Published var clockSeconds:    Bool   { didSet { ud.set(clockSeconds,    forKey: "clock_seconds")    } }
    @Published var clockColorHex:   String { didSet { ud.set(clockColorHex,   forKey: "clock_color_hex")  } }
    @Published var appTheme:        String { didSet { ud.set(appTheme,        forKey: "app_theme")         } }
    @Published var myBubbleHex:     String { didSet { ud.set(myBubbleHex,     forKey: "my_bubble_hex")     } }
    @Published var theirBubbleHex:  String { didSet { ud.set(theirBubbleHex,  forKey: "their_bubble_hex")  } }
    @Published var chatBgImageData:    Data? { didSet { ud.set(chatBgImageData,    forKey: "chat_bg_data")    } }
    @Published var feedBgImageData:    Data? { didSet { ud.set(feedBgImageData,    forKey: "feed_bg_data")    } }
    @Published var profileBgImageData: Data? { didSet { ud.set(profileBgImageData, forKey: "profile_bg_data") } }
    @Published var deviceUa:        String { didSet { ud.set(deviceUa,      forKey: "device_ua")        } }

    // Verification / Exploits
    @Published var verifyChecker:    Bool { didSet { ud.set(verifyChecker,   forKey: "verify_checker")   } }
    @Published var fakeVerification: Bool { didSet { ud.set(fakeVerification, forKey: "fake_verif")      } }

    // Computed
    var currentDeviceProfile: DeviceProfile {
        DeviceProfile.allCases.first { $0.ua == deviceUa } ?? .kate
    }
    var currentTypeStatus: TypeStatus { TypeStatus(rawValue: typeStatus) ?? .none }

    private init() {
        ghostMode        = ud.bool(forKey: "ghost_mode")
        antiTyping       = ud.bool(forKey: "anti_typing")
        forceOffline     = ud.bool(forKey: "force_offline")
        ghostOnline      = ud.bool(forKey: "ghost_online")
        ghostStory       = ud.bool(forKey: "ghost_story")
        antiTelemetry    = ud.bool(forKey: "anti_telemetry")
        antiScreen       = ud.bool(forKey: "anti_screen")
        bypassLinks      = ud.object(forKey: "bypass_links")    == nil ? true  : ud.bool(forKey: "bypass_links")
        bypassShortUrl   = ud.bool(forKey: "bypass_short_url")
        antiBan          = ud.bool(forKey: "anti_ban")
        offlinePost      = ud.bool(forKey: "offline_post")
        bypassActivity   = ud.bool(forKey: "bypass_activity")
        longPollOnly     = ud.bool(forKey: "longpoll_only")
        silentVm         = ud.bool(forKey: "silent_vm")
        typeStatus       = ud.string(forKey: "type_status")    ?? TypeStatus.none.rawValue
        bypassCopy       = ud.object(forKey: "bypass_copy")    == nil ? true  : ud.bool(forKey: "bypass_copy")
        typePush             = ud.bool(forKey: "type_push")
        notifyStyle          = ud.string(forKey: "notify_style") ?? "default"
        tabBarStyle          = ud.string(forKey: "tab_bar_style") ?? "default"
        predictFilterGroups  = ud.object(forKey: "predict_filter_groups")  == nil ? true : ud.bool(forKey: "predict_filter_groups")
        predictMinGroupSize  = ud.object(forKey: "predict_min_group_size") == nil ? 5    : ud.integer(forKey: "predict_min_group_size")
        predictOnlyDMs       = ud.bool(forKey: "predict_only_dms")
        predictFavoritesOnly = ud.bool(forKey: "predict_favorites_only")
        if let d = ud.data(forKey: "predict_favorite_ids"),
           let arr = try? JSONDecoder().decode([Int].self, from: d) {
            predictFavoriteIds = arr
        } else { predictFavoriteIds = [] }
        hardwareSpoof    = ud.bool(forKey: "hardware_spoof")
        liquidGlass      = ud.bool(forKey: "liquid_glass")
        weatherGarland   = ud.bool(forKey: "weather_garland")
        weatherRain    = ud.bool(forKey: "weather_rain")
        weatherSnow    = ud.bool(forKey: "weather_snow")
        weatherFog     = ud.bool(forKey: "weather_fog")
        weatherLeaves  = ud.bool(forKey: "weather_leaves")
        weatherSakura  = ud.bool(forKey: "weather_sakura")
        weatherAurora  = ud.bool(forKey: "weather_aurora")
        weatherBubbles = ud.bool(forKey: "weather_bubbles")
        weatherStars   = ud.bool(forKey: "weather_stars")
        weatherFire    = ud.bool(forKey: "weather_fire")
        weatherPixels  = ud.bool(forKey: "weather_pixels")
        showPet          = ud.bool(forKey: "show_pet")
        petType          = ud.string(forKey: "pet_type")         ?? "cat"
        avatarShape         = ud.string(forKey: "avatar_shape")          ?? "circle"
        avatarGlow          = ud.bool(forKey: "avatar_glow")
        avatarGlowIntensity = ud.object(forKey: "avatar_glow_intensity") == nil ? 0.6 : ud.double(forKey: "avatar_glow_intensity")
        avatarColorCircle   = ud.string(forKey: "avatar_color_circle")   ?? "#00B4FF"
        avatarColorNft      = ud.string(forKey: "avatar_color_nft")      ?? "#8B5CF6"
        avatarColorRhomb    = ud.string(forKey: "avatar_color_rhomb")    ?? "#00B4FF"
        avatarGlowCircle    = ud.string(forKey: "avatar_glow_circle")    ?? "#00B4FF"
        avatarGlowNft       = ud.string(forKey: "avatar_glow_nft")       ?? "#8B5CF6"
        avatarGlowRhomb     = ud.string(forKey: "avatar_glow_rhomb")     ?? "#00B4FF"
        showClock        = ud.bool(forKey: "show_clock")
        clockStyle       = ud.string(forKey: "clock_style")      ?? "digital"
        clockAmPm        = ud.bool(forKey: "clock_ampm")
        clockSeconds     = ud.bool(forKey: "clock_seconds")
        clockColorHex    = ud.string(forKey: "clock_color_hex") ?? "auto"
        appTheme         = ud.string(forKey: "app_theme")         ?? "dark"
        myBubbleHex      = ud.string(forKey: "my_bubble_hex")     ?? "#122846"
        theirBubbleHex   = ud.string(forKey: "their_bubble_hex")  ?? "#1A1E2E"
        chatBgImageData    = ud.data(forKey: "chat_bg_data")
        feedBgImageData    = ud.data(forKey: "feed_bg_data")
        profileBgImageData = ud.data(forKey: "profile_bg_data")
        deviceUa         = ud.string(forKey: "device_ua")      ?? DeviceProfile.kate.ua
        verifyChecker    = ud.object(forKey: "verify_checker") == nil ? true  : ud.bool(forKey: "verify_checker")
        fakeVerification = ud.bool(forKey: "fake_verif")
        hideSender       = ud.bool(forKey: "hide_sender")
        blurScreen       = ud.bool(forKey: "blur_screen")
        spoofAdId        = ud.object(forKey: "spoof_ad_id")   == nil ? true : ud.bool(forKey: "spoof_ad_id")
        blockWifi        = ud.object(forKey: "block_wifi")    == nil ? true : ud.bool(forKey: "block_wifi")
        spoofCarrier       = ud.bool(forKey: "spoof_carrier")
        antiLinkPreview    = ud.bool(forKey: "anti_link_preview")
        ghostForward       = ud.bool(forKey: "ghost_forward")
        spoofDeviceModel   = ud.bool(forKey: "spoof_device_model")
        if let d = ud.data(forKey: "profile_history"),
           let arr = try? JSONDecoder().decode([Int].self, from: d) {
            profileHistory = arr
        } else { profileHistory = [] }
        statusChangerText     = ud.string(forKey: "status_changer_text") ?? ""
        statusChangerMode     = ud.string(forKey: "status_changer_mode") ?? "local"
        statusChangerPrevious = ud.string(forKey: "status_changer_prev") ?? ""
        statusChangerApplied  = ud.bool(forKey: "status_changer_applied")
    }

    func addProfileHistory(_ id: Int) {
        var h = profileHistory.filter { $0 != id }
        h.insert(id, at: 0)
        profileHistory = Array(h.prefix(50))
    }
}
