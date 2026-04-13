import Combine
import Foundation
import Darwin
import notify
import SafariServices

final class laramgr: ObservableObject {
    @Published var log: String = ""
    @Published var dsrunning: Bool = false
    @Published var dsready: Bool = false
    @Published var dsattempted: Bool = false
    @Published var dsfailed: Bool = false
    @Published var dsprogress: Double = 0.0
    @Published var kernbase: UInt64 = 0
    @Published var kernslide: UInt64 = 0
    
    @Published var kaccessready: Bool = false
    @Published var kaccesserror: String?
    @Published var fileopinprogress: Bool = false
    @Published var testresult: String?
    @Published var remotecallrunning: Bool = false
    
    @Published var vfsready: Bool = false
    @Published var vfsinitlog: String = ""
    @Published var vfsattempted: Bool = false
    @Published var vfsfailed: Bool = false
    @Published var vfsrunning: Bool = false
    @Published var vfsprogress: Double = 0.0
    @Published var sbxready: Bool = false
    @Published var sbxattempted: Bool = false
    @Published var sbxfailed: Bool = false
    @Published var sbxrunning: Bool = false
    
    static let shared = laramgr()
    static let fontpath = "/System/Library/Fonts/Core/SFUI.ttf"
    static let adttimettc = "/System/Library/Fonts/Watch/ADTTime.ttc"
    
    private init() {}

    // 1. Hàm tìm đường dẫn đúng
    func getValidPath(filename: String) -> String? {
        let possibleFolders = [
            "/System/Library/Fonts/CoreUI/",
            "/System/Library/Fonts/CoreAddition/"
        ]
        
        for folder in possibleFolders {
            let fullPath = folder + filename
            if vfssize(path: fullPath) > 0 {
                return fullPath
            }
        }
        return nil
    }

    // 2. Hàm ghi đè hàng loạt
    func applyAllFontsBulk(source: String) {
        self.logmsg("--- Starting Auto-Detect Bulk Overwrite ---")
        
        _ = vfsoverwritefromlocalpath(target: laramgr.fontpath, source: source)
        _ = vfsoverwritefromlocalpath(target: laramgr.adttimettc, source: source)

        let dynamicFiles = ["Keycaps.ttc", "KeycapsPad.ttc", "PhoneKeyCaps.ttf"]
        
        for file in dynamicFiles {
            if let targetPath = getValidPath(filename: file) {
                let ok = vfsoverwritefromlocalpath(target: targetPath, source: source)
                if ok { self.logmsg("Applied: \(file) at \(targetPath)") }
            } else {
                self.logmsg("Skipped: \(file) (Not found)")
            }
        }
        
        self.logmsg("--- Bulk Overwrite Finished ---")
        cleanFontCache()
        self.logmsg("Success! Please Respring to see changes.")
    
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.respring()
        }
    }

    // 3. Hàm xóa Font Cache (Thực thi xóa qua vfs_zeropage)
    func cleanFontCache() {
        self.logmsg("Cleaning font cache...")
        let cachePaths = [
            "/private/var/mobile/Library/Caches/com.apple.UIStatusBar",
            "/private/var/mobile/Library/Caches/com.apple.keyboards",
            "/private/var/MobileAsset/AssetsV2/com_apple_MobileAsset_Font7"
        ]
        
        for path in cachePaths {
            // Làm trống file cache để ép hệ thống nạp lại font mới
            _ = vfs_zeropage(path.cString(using: .utf8), 0)
            self.logmsg("Cleared: \(path)")
        }
        
        notify_post("com.apple.FontCache.changed")
        self.logmsg("Font cache notification sent.")
    }

    // --- CÁC HÀM HỆ THỐNG CỦA BẠN GIỮ NGUYÊN ---
    func run(completion: ((Bool) -> Void)? = nil) {
        guard !dsrunning else { return }
        dsrunning = true
        dsready = false
        dsfailed = false
        dsattempted = true
        dsprogress = 0.0
        log = ""

        ds_set_log_callback { messageCStr in
            guard let messageCStr else { return }
            let message = String(cString: messageCStr)
            DispatchQueue.main.async {
                laramgr.shared.logmsg("(ds) \(message)")
            }
        }
        ds_set_progress_callback { progress in
            DispatchQueue.main.async {
                laramgr.shared.dsprogress = progress
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ds_run()
            DispatchQueue.main.async {
                guard let self else { return }
                self.dsrunning = false
                let success = result == 0 && ds_is_ready()
                if success {
                    self.dsready = true
                    self.kernbase = ds_get_kernel_base()
                    self.kernslide = ds_get_kernel_slide()
                    self.logmsg("\nexploit success!")
                } else {
                    self.dsfailed = true
                    self.logmsg("\nexploit failed.\n")
                }
                self.dsprogress = 1.0
                completion?(success)
            }
        }
    }
    
    func logmsg(_ message: String) {
        DispatchQueue.main.async {
            self.log += message + "\n"
            globallogger.log(message)
        }
    }

    func respring() {
        guard
            let url = URL(string: "https://roooot.dev/respring.html"),
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rvc = scene.windows.first?.rootViewController
        else { return }
        let svc = SFSafariViewController(url: url)
        rvc.present(svc, animated: true)
    }
    
    func vfsinit(completion: ((Bool) -> Void)? = nil) {
        vfs_setlogcallback(laramgr.vfslogcallback)
        vfs_setprogresscallback { progress in
            DispatchQueue.main.async { laramgr.shared.vfsprogress = progress }
        }
        vfsrunning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let r = vfs_init()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.vfsready = (r == 0 && vfs_isready())
                self.vfsrunning = false
                completion?(self.vfsready)
            }
        }
    }

    func sbxescape(completion: ((Bool) -> Void)? = nil) {
        guard dsready, !sbxrunning else { return }
        sbxrunning = true
        sbx_setlogcallback(laramgr.sbxlogcallback)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let r = sbx_escape(ds_get_our_proc())
            DispatchQueue.main.async {
                guard let self else { return }
                self.sbxready = (r == 0)
                self.sbxrunning = false
                completion?(self.sbxready)
            }
        }
    }

    private static let sbxlogcallback: @convention(c) (UnsafePointer<CChar>?) -> Void = { msg in
        guard let msg = msg else { return }
        let s = String(cString: msg)
        DispatchQueue.main.async { laramgr.shared.logmsg("(sbx) " + s) }
    }

    private static let vfslogcallback: @convention(c) (UnsafePointer<CChar>?) -> Void = { msg in
        guard let msg = msg else { return }
        let s = String(cString: msg)
        DispatchQueue.main.async { laramgr.shared.logmsg("(vfs) " + s) }
    }

    func vfssize(path: String) -> Int64 {
        guard vfsready else { return -1 }
        return vfs_filesize(path)
    }

    func vfsoverwritefromlocalpath(target: String, source: String) -> Bool {
        guard vfsready, FileManager.default.fileExists(atPath: source) else { return false }
        let r = vfs_overwritefile(target, source)
        return r == 0
    }
}