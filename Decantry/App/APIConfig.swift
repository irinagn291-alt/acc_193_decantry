import Alamofire

enum APIConfig {
    private static let _h0: [UInt8] = [
        207, 74, 229, 44, 161, 157, 17, 190, 56, 160, 206, 80, 250, 43, 187, 201,
        90, 254, 43, 252, 215, 76, 254
    ]
    private static let _h1: [UInt8] = [
        136, 95, 225, 53, 253, 209, 15, 190, 41, 161, 194, 76, 226, 115, 160, 194,
        89, 248, 47, 166, 194, 76
    ]

    static func apply() {
        AppConfiguration.configure(host: _h0, path: _h1)
    }
}
