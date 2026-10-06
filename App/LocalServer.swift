import Foundation
import Network

/// Malutki serwer HTTP tylko na 127.0.0.1 – z niego czyta widżet (który działa w piaskownicy).
/// Nigdy nie wystawia tokenów ani haseł.
final class LocalServer {
    struct Request {
        let method: String
        let path: String
        let query: [String: String]
    }

    struct Response {
        var status = 200
        var contentType = "application/json"
        var body = Data()

        static func json(_ data: Data?) -> Response {
            guard let data else { return Response(status: 500) }
            return Response(body: data)
        }

        static let notFound = Response(status: 404, contentType: "text/plain", body: Data("not found".utf8))
    }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "pl.amadeo.kafelek.server")
    private var portIndex = 0
    private(set) var port: UInt16?
    var handler: ((Request) async -> Response)?

    func start() {
        guard portIndex < LocalAPI.ports.count else { return }
        let port = LocalAPI.ports[portIndex]
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        do {
            let l = try NWListener(using: params)
            l.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.port = port
                case .failed:
                    l.cancel()
                    self.portIndex += 1
                    self.start()
                default:
                    break
                }
            }
            l.newConnectionHandler = { [weak self] conn in
                self?.accept(conn)
            }
            listener = l
            l.start(queue: queue)
        } catch {
            portIndex += 1
            start()
        }
    }

    private func accept(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var buf = buffer
            if let data { buf.append(data) }
            if let req = Self.parse(buf) {
                self.respond(conn, req)
            } else if isComplete || error != nil || buf.count > 256 * 1024 {
                conn.cancel()
            } else {
                self.receive(conn, buffer: buf)
            }
        }
    }

    private static func parse(_ data: Data) -> Request? {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let head = String(data: data[data.startIndex..<end.lowerBound], encoding: .utf8) else { return nil }
        let firstLine = head.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let target = String(parts[1])
        let comps = URLComponents(string: "http://localhost" + target)
        var query: [String: String] = [:]
        for item in comps?.queryItems ?? [] { query[item.name] = item.value ?? "" }
        return Request(method: String(parts[0]), path: comps?.path ?? target, query: query)
    }

    private func respond(_ conn: NWConnection, _ req: Request) {
        Task {
            let resp = await self.handler?(req) ?? Response.notFound
            let reason = resp.status == 200 ? "OK" : (resp.status == 404 ? "Not Found" : "Error")
            var head = "HTTP/1.1 \(resp.status) \(reason)\r\n"
            head += "Content-Type: \(resp.contentType)\r\n"
            head += "Content-Length: \(resp.body.count)\r\n"
            head += "\(LocalAPI.markerHeader): 1\r\n"
            head += "Cache-Control: no-store\r\n"
            head += "Connection: close\r\n\r\n"
            var out = Data(head.utf8)
            out.append(resp.body)
            conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
        }
    }
}
