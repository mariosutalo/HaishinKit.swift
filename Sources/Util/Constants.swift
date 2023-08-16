import Logboard

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

let lblogger = LBLogger.with(HaishinKitIdentifier)

var logger: LBLogger {
    #if DEBUG
        return lblogger
    #else
        lblogger.level = .error
        return lblogger
    #endif
}


