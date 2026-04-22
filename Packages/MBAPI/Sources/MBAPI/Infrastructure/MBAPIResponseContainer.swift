import Foundation

struct MBAPIResponseContainer<Response: Decodable>: Decodable {
    let items: [Response]
}
