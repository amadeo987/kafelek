import Foundation
import IOKit.ps

private let webSession: URLSession = {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.timeoutIntervalForRequest = 20
    return URLSession(configuration: cfg)
}()

private func getJSON(_ url: URL) async -> Any? {
    var req = URLRequest(url: url)
    req.setValue("Kafelek (macOS)", forHTTPHeaderField: "User-Agent")
    guard let result = try? await webSession.data(for: req),
          let http = result.1 as? HTTPURLResponse, http.statusCode == 200 else { return nil }
    return try? JSONSerialization.jsonObject(with: result.0)
}

// MARK: - Pogoda (Open‑Meteo: darmowe, bez klucza)

struct GeoPlace: Identifiable, Hashable {
    var id: String { "\(latitude),\(longitude)" }
    let name: String
    let detail: String
    let latitude: Double
    let longitude: Double
}

enum WeatherSource {
    static func search(_ query: String) async -> [GeoPlace] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(q)&count=8&language=pl&format=json"),
              let json = await getJSON(url) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        return results.compactMap { r in
            guard let name = r["name"] as? String, let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double else { return nil }
            let detail = [r["admin1"] as? String, r["country"] as? String].compactMap { $0 }.joined(separator: ", ")
            return GeoPlace(name: name, detail: detail, latitude: lat, longitude: lon)
        }
    }

    static func fetch(_ o: WeatherOptions) async -> WeatherData? {
        let base = "https://api.open-meteo.com/v1/forecast"
        let params = [
            "latitude=\(o.latitude)", "longitude=\(o.longitude)",
            "current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m",
            "hourly=temperature_2m,weather_code,is_day",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset",
            "timezone=auto", "timeformat=unixtime", "forecast_days=7", "forecast_hours=24",
        ].joined(separator: "&")
        guard let url = URL(string: base + "?" + params),
              let json = await getJSON(url) as? [String: Any],
              let current = json["current"] as? [String: Any] else { return nil }

        func num(_ v: Any?) -> Double { (v as? Double) ?? Double((v as? Int) ?? 0) }
        func nums(_ v: Any?) -> [Double] { (v as? [Any])?.map { num($0) } ?? [] }

        let hourly = json["hourly"] as? [String: Any] ?? [:]
        let hTimes = nums(hourly["time"]), hTemps = nums(hourly["temperature_2m"])
        let hCodes = nums(hourly["weather_code"]), hDay = nums(hourly["is_day"])
        var hours: [HourPoint] = []
        for i in 0..<min(hTimes.count, hTemps.count, hCodes.count) {
            hours.append(HourPoint(time: Date(timeIntervalSince1970: hTimes[i]), temperature: hTemps[i],
                                   code: Int(hCodes[i]), isDay: i < hDay.count ? hDay[i] > 0 : true))
        }

        let daily = json["daily"] as? [String: Any] ?? [:]
        let dTimes = nums(daily["time"]), dMax = nums(daily["temperature_2m_max"]), dMin = nums(daily["temperature_2m_min"])
        let dCodes = nums(daily["weather_code"]), rise = nums(daily["sunrise"]), sets = nums(daily["sunset"])
        var days: [DayPoint] = []
        for i in 0..<min(dTimes.count, dMax.count, dMin.count, dCodes.count) {
            days.append(DayPoint(date: Date(timeIntervalSince1970: dTimes[i]), high: dMax[i], low: dMin[i], code: Int(dCodes[i])))
        }

        return WeatherData(placeName: o.placeName,
                           temperature: num(current["temperature_2m"]),
                           apparent: num(current["apparent_temperature"]),
                           code: Int(num(current["weather_code"])),
                           isDay: num(current["is_day"]) > 0,
                           humidity: num(current["relative_humidity_2m"]),
                           wind: num(current["wind_speed_10m"]),
                           high: dMax.first ?? 0,
                           low: dMin.first ?? 0,
                           sunrise: rise.first.map { Date(timeIntervalSince1970: $0) },
                           sunset: sets.first.map { Date(timeIntervalSince1970: $0) },
                           hourly: hours,
                           daily: days,
                           updatedAt: Date())
    }
}

// MARK: - Krypto (publiczne API Binance, bez klucza)

enum CryptoSource {
    static func fetch(_ symbol: String) async -> CryptoQuote? {
        guard let tickerURL = URL(string: "https://api.binance.com/api/v3/ticker/24hr?symbol=\(symbol)"),
              let t = await getJSON(tickerURL) as? [String: Any],
              let price = Double(t["lastPrice"] as? String ?? ""),
              let change = Double(t["priceChangePercent"] as? String ?? "") else { return nil }
        var spark: [Double] = []
        if let kURL = URL(string: "https://api.binance.com/api/v3/klines?symbol=\(symbol)&interval=1h&limit=24"),
           let rows = await getJSON(kURL) as? [[Any]] {
            spark = rows.compactMap { $0.count > 4 ? Double($0[4] as? String ?? "") : nil }
        }
        return CryptoQuote(symbol: symbol, price: price, changePercent: change, sparkline: spark, updatedAt: Date())
    }
}

// MARK: - Bateria (IOKit, lokalnie)

enum BatterySource {
    static func read() -> BatteryInfo? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let cur = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let toEmpty = desc[kIOPSTimeToEmptyKey] as? Int ?? -1
            let toFull = desc[kIOPSTimeToFullChargeKey] as? Int ?? -1
            let minutes = charging ? toFull : toEmpty
            return BatteryInfo(percent: max > 0 ? Int(Double(cur) / Double(max) * 100) : cur,
                               charging: charging, onAC: onAC,
                               minutesRemaining: minutes > 0 ? minutes : nil)
        }
        return nil
    }
}
