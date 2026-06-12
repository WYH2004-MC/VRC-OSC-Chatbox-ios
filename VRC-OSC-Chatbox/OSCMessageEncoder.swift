import Foundation

enum OSCMessageEncoder {
    static func chatboxInput(
        _ text: String,
        sendImmediately: Bool = true,
        playNotificationSound: Bool = true
    ) -> Data {
        var data = Data()
        appendOSCString("/chatbox/input", to: &data)
        appendOSCString(",s\(sendImmediately ? "T" : "F")\(playNotificationSound ? "T" : "F")", to: &data)
        appendOSCString(text, to: &data)
        return data
    }

    static func chatboxTyping(_ isTyping: Bool) -> Data {
        var data = Data()
        appendOSCString("/chatbox/typing", to: &data)
        appendOSCString(isTyping ? ",T" : ",F", to: &data)
        return data
    }

    private static func appendOSCString(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
        data.append(0)

        let padding = (4 - data.count % 4) % 4
        if padding > 0 {
            data.append(contentsOf: repeatElement(UInt8(0), count: padding))
        }
    }
}
