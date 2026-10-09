# Kafelek ▦

Własne widżety na pulpit Maca, jak Widgetsmith, tylko za darmo, lokalnie i bez kont.
Projektujesz w aplikacji dowolnie dużo kafelków, a potem stawiasz je na pulpicie jako **natywne widżety macOS** (1×1, 2×1, 2×2, 4×2) albo jako **kafelki pływające** (bez żadnych limitów systemu).

## Instalacja (jedna linijka)

Otwórz **Terminal** i wklej:

```bash
curl -fsSL https://github.com/amadeo987/kafelek/releases/latest/download/install.sh | bash
```

Skrypt pobierze najnowszą wersję, wrzuci `Kafelek.app` do **Aplikacji** i ją uruchomi. Ta sama komenda służy do aktualizacji. Aplikacja umie też aktualizować się sama (Ustawienia → Aktualizacje).

**Odinstalowanie** (Twoje widżety zostają i wrócą po ponownej instalacji):

```bash
curl -fsSL https://github.com/amadeo987/kafelek/releases/latest/download/uninstall.sh | bash
```

Żeby usunąć też wszystkie widżety i zdjęcia, dopisz na końcu ` -s -- --all`.

**Bez Terminala:** pobierz `Kafelek.dmg` z [Releases](https://github.com/amadeo987/kafelek/releases/latest), otwórz go i przeciągnij ikonę do **Aplikacji**. Przy pierwszym uruchomieniu macOS powie, że nie może zweryfikować dewelopera. Wtedy wejdź w **Ustawienia systemowe → Prywatność i ochrona**, przewiń w dół i kliknij **Otwórz mimo to**. To jednorazowe.

> Aplikacja jest podpisana lokalnie („Sign to Run Locally”). Nie potrzebuje płatnego konta Apple, Xcode ani App Store i **nic nie wygasa po 7 dniach**.

## Dodawanie widżetu

1. Kliknij prawym na tapecie i wybierz **Edytuj widżety…**
2. Wyszukaj **Kafelek** i przeciągnij rozmiar na pulpit.
3. Kliknij prawym na widżecie, wybierz **Edytuj „Kafelek”** i wskaż swój projekt.

Każdy widżet może pokazywać inny projekt, więc dodajesz ich tyle, ile chcesz.

## Co potrafi

| Kafelek | Co pokazuje |
|---|---|
| **Limity AI** | Claude i Codex: sesja (5 h) i tydzień, ile zostało, czas do resetu. Pierścienie albo paski, jedno albo oba konta |
| **Zegar** | cyfrowy, analogowy, duże cyfry, dwie strefy czasowe. Na kafelkach pływających także sekundy |
| **Data** | duży dzień, pełna data, tydzień roku i postęp roku |
| **Kalendarz** | najbliższe wydarzenie, agenda, miesiąc z kropkami. Dane z Apple Kalendarza |
| **Przypomnienia** | lista z **odhaczaniem kliknięciem** albo licznik. Dane z Apple Przypomnień |
| **Notatka / cytat** | dowolny tekst, autor cytatu, 17 czcionek (Marker Felt, Snell Roundhand, New York…) |
| **Odliczanie** | dni do daty albo od daty |
| **Zdjęcie** | zdjęcie z podpisem. Zdjęcie może też być tłem każdego innego kafelka |
| **Pogoda** | teraz, godzinowa, 5 dni (Open‑Meteo, bez klucza) |
| **Kurs krypto** | BTC, ETH… z wykresem 24 h (publiczne API Binance) |
| **Bateria** | bateria Maca |
| **Słońce i Księżyc** | wschód i zachód słońca, faza Księżyca |
| **Skróty i akcje** | przyciski uruchamiające Skróty Apple, aplikacje i linki |
| **System Maca** | procesor, RAM, dysk, bateria – pierścienie albo paski |

Do tego:
- **Styl:** 12 motywów, kolor albo gradient albo zdjęcie w tle, kolor tekstu i akcentu, czcionka, grubość, wyrównanie, wielkość, ramka.
- **Harmonogramy** (jak w Widgetsmith): jeden widżet pokazuje różne kafelki o różnych porach i w różne dni.
- **Kafelki pływające:** okienka na tapecie bez limitów macOS, z dowolną skalą. Odblokowujesz układ i przeciągasz myszką.
- **Działa niewidocznie:** bez ikonki na pasku menu (można włączyć w Ustawieniach). Okno otwierasz z Launchpada albo Spotlight.
- **Trzy rodzaje widżetów w macOS:** Kafelek (Twoje projekty), Zdjęcia (zdjęcie albo zmieniający się album) i Limity AI.

## Limity Claude i Codex

Działa tak samo jak CodexBar:
- **Claude** korzysta z logowania **Claude Code**. Przy pierwszym razie macOS zapyta o dostęp do „Claude Code-credentials” w Pęku kluczy. Kliknij **Zawsze pozwalaj**. Zapasowo możesz wkleić `sessionKey` z claude.ai (Konta AI).
- **Codex** czyta `~/.codex/auth.json`, czyli logowanie Codex CLI kontem ChatGPT.

Tokeny nie opuszczają Maca. Kafelek wysyła je tylko do Anthropic i OpenAI, tak samo jak oficjalne narzędzia.

## Lekkość

- Pobiera tylko to, czego używają Twoje kafelki: AI co 5 min (do ustawienia), kalendarz po każdej zmianie, pogodę co 30 min, krypto co 2 min.
- Natywne widżety rysuje system. Aplikacja w tle tylko podaje im dane przez lokalne połączenie `127.0.0.1` (nie wychodzi poza Maca).

## Jak to działa (dla ciekawskich)

- `App/` to aplikacja na pasku menu: edytor, źródła danych, kafelki pływające, aktualizacje.
- `Widget/` to rozszerzenie WidgetKit z jednym widżetem „Kafelek” we wszystkich rozmiarach, z wyborem projektu w „Edytuj widżet”.
- `Shared/` to model i widoki kafelków, wspólne dla widżetu, podglądu i kafelków pływających.
- Widżet działa w piaskownicy, a wspólny folder (App Group) wymaga płatnego konta Apple. Dlatego aplikacja wystawia mały serwer tylko na `127.0.0.1`, z którego widżet czyta projekty i dane.
- GitHub Actions buduje uniwersalną aplikację (Apple Silicon + Intel) przy każdym pushu i publikuje ją w Releases.

Budowanie u siebie (opcjonalne): `./Scripts/build-local.sh` (Xcode + Homebrew).
