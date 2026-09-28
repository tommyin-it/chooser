# Chooser

<img src="Resources/Chooser.png" alt="Ikona Chooser — rozgałęziające się strzałki" width="128">

Mała, lokalna aplikacja macOS w Swift + AppKit (SwiftUI służy wyłącznie do rysowania cienia). Bez bibliotek zewnętrznych, rozszerzeń, serwera, telemetrii ani chmury. Wymaga macOS 13 lub nowszego.

## Pobierz gotową aplikację

Pobierz **Chooser-1.1.0-universal.dmg** ze [strony wydań](https://github.com/tommyin-it/chooser/releases/latest), otwórz obraz i przeciągnij Chooser do Applications. Wysuń obraz i uruchom aplikację z Applications. Dostępny jest także ZIP. Wersja uniwersalna zawiera kod dla Apple Silicon i Intela; testy uruchomieniowe wykonano na Apple Silicon.

Aplikacja jest podpisana lokalnie, ale nie ma notaryzacji Apple. Przy pierwszym uruchomieniu pobranej wersji macOS może wymagać opcji **Otwórz mimo to** w Ustawieniach systemowych → Prywatność i ochrona, zgodnie z [instrukcją Apple](https://support.apple.com/en-am/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). Nie wyłączaj zabezpieczeń systemu.

## Instalacja ze źródeł

Wymagania: **macOS 13+**, Command Line Tools z **Swift 5.9+** (Xcode 15 lub nowsze narzędzia) oraz zainstalowany Brave lub Google Chrome. Aplikacja działa lokalnie na Apple Silicon i Intel; kompilacja tworzy wersję dla Twojego Maca. Domyślny język to angielski; w Settings → Get started → Language wybierz Polski. Zmiana działa od razu i jest zapamiętywana.

1. Zainstaluj narzędzia Apple, jeśli jeszcze ich nie masz:

   ```sh
   xcode-select --install
   ```

   Poczekaj na zakończenie instalatora. Pełny Xcode nie jest wymagany.

2. Pobierz projekt i zbuduj aplikację:

   ```sh
   git clone https://github.com/tommyin-it/chooser.git
   cd chooser
   ./scripts/build.sh
   ```

3. Zainstaluj aplikację w swoim katalogu aplikacji i uruchom ją:

   ```sh
   mkdir -p "$HOME/Applications"
   ditto build/Chooser.app "$HOME/Applications/Chooser.app"
   open "$HOME/Applications/Chooser.app"
   ```

   Możesz też przenieść `build/Chooser.app` Finderem do `/Applications`. Aplikacja pojawia się **w pasku menu**, bez ikony w Docku. Jest podpisywana lokalnie (ad hoc); projekt nie zawiera wydania notaryzowanego przez Apple.

4. Kliknij ikonę w pasku menu → **Ustawienia → Start**:
   - Przy **Obsługa linków** wybierz **Połącz…** i zaakceptuj systemowy komunikat ustawienia Choosera jako domyślnej aplikacji HTTP/HTTPS.
   - Nagraj skrót przełączania trybu. Domyślny to **Hyper + B** (Control + Option + Command + Shift + B).
   - Opcjonalnie włącz **start przy logowaniu**. macOS może poprosić o zatwierdzenie w Elementach logowania.

Ustawienia otwierasz z menu — samo uruchomienie Choosera nie pokazuje okna. Skrót nie wymaga Dostępności ani Monitorowania wprowadzania. Nie przenoś aplikacji po skonfigurowaniu obsługi linków i startu przy logowaniu. Zmiana domyślnej przeglądarki przez inną aplikację może wymagać ponownego użycia **Połącz…**.

### Aktualizacja

Zakończ Choosera z menu, a następnie w katalogu projektu uruchom:

```sh
git pull --ff-only
./scripts/build.sh
ditto build/Chooser.app "$HOME/Applications/Chooser.app"
open "$HOME/Applications/Chooser.app"
```

Jeśli aplikację umieszczono w `/Applications`, użyj tego miejsca zamiast `~/Applications`. Ustawienia, reguły i zapisane profile pozostają zachowane.

### Odinstalowanie

Wyłącz start przy logowaniu, ustaw Brave lub Chrome jako domyślną przeglądarkę w ustawieniach macOS, zakończ Choosera i przenieś `Chooser.app` do Kosza. Chooser nie usuwa ani nie modyfikuje profili przeglądarek.

## Zachowanie

- **Wybór:** kliknięcie linku pokazuje okienko przy bieżącym kursorze; osobne drugie kliknięcie wybiera przeglądarkę. Domyślny pasek bez dodatkowych profili ma 165 × 56 pkt, zaokrąglone rogi oraz animacje najechania i kliknięcia (z uwzględnieniem systemowego ograniczenia ruchu). Zapamiętana przeglądarka jest zawsze po lewej i zajmuje ⅔ szerokości. Druga zajmuje ⅓. ⌘1 wybiera lewą, ⌘2 prawą — tylko gdy okienko jest otwarte. Okienko jest ustawiane tak, aby lewy przycisk był pod kursorem; przy prawej krawędzi priorytetem jest zmieszczenie całego okienka na ekranie, więc może być potrzebny ruch myszy.
- **Brave / Chrome:** linki są przekazywane bez okienka bezpośrednio do wybranej aplikacji, która przechodzi na pierwszy plan.
- Kilka linków oczekujących w okienku jest otwieranych razem. Escape albo kliknięcie poza okienkiem anuluje całą grupę.
- Wybór w okienku nie zmienia trybu. Zapamiętany przycisk aktualizuje się po udanym przekazaniu linków.
- Zmiana trybu pokazuje nazwę i ikonę przez 1,5 s, bez przejmowania fokusu. Jeśli okienko wyboru jest otwarte, zmiana trybu anuluje oczekujące linki — sama nie uruchamia przeglądarki.
- Brak przeglądarki lub błąd otwarcia powoduje wyświetlenie komunikatu; otwarcie w drugiej wymaga kliknięcia przez użytkownika.
- Tryb, ostatni wybór oraz skrót są zapisywane lokalnie w `UserDefaults`. Pierwszy start: Wybór, większy przycisk Brave.

Ustawienia otwierają się wyłącznie po wybraniu ich z menu. Obsługa linku ukrywa wcześniej otwarte ustawienia; macOS nie przywraca tego okna automatycznie.

## Reguły aplikacji i pierwsza konfiguracja

Zakładka **Start** prowadzi przez połączenie obsługi linków i nagranie skrótu. Wykonane kroki pokazują status „Gotowe”. Dodatkowe wyjaśnienia są w podpowiedziach po najechaniu, a zgody dotyczą wyłącznie faktycznych operacji systemowych: domyślnej obsługi HTTP/HTTPS i opcjonalnego startu przy logowaniu.

W **Reguły aplikacji → Dodaj aplikację…** wybierz plik `.app`, np. Slack, a następnie Chrome lub Brave w wierszu reguły. Nowa reguła domyślnie wskazuje Chrome. Możesz zmienić przeglądarkę lub usunąć regułę. Ponowne dodanie tej samej aplikacji wybiera istniejący wiersz. Reguły są zapisywane lokalnie po identyfikatorze aplikacji i zachowują się po restarcie.

Reguła źródłowej aplikacji ma pierwszeństwo przed globalnym trybem. Linki pochodzące z Brave i Chrome nadal pozostają w danej przeglądarce. Źródło jest odczytywane z Apple Event; helper wewnątrz pakietu aplikacji jest przypisywany aplikacji nadrzędnej. Jeśli macOS przekazuje zdarzenie przez nierozpoznawalnego pośrednika lub nie podaje nadawcy, stosowany jest tryb globalny — Chooser nie zgaduje źródła z aktywnego okna. Ta sama informacja o źródle jest zachowywana przy zimnym starcie aplikacji.

## Zapisane profile i układy okienka

W **Ustawienia → Profile** wybierz istniejący profil Brave lub Chrome i kliknij **Dodaj**. Możesz zapisać kilka profili. Każdy ma osobny przełącznik, a **Pokaż dodatkowe profile w okienku** wyłącza lub włącza całą grupę, zachowując indywidualne zaznaczenia. Wyłączenie nigdy nie usuwa zapisów; kosz usuwa tylko wpis z Choosera, nie profil przeglądarki. Wcześniej skonfigurowany pojedynczy profil jest automatycznie przenoszony do zapisanej listy.

Profile pochodzą z lokalnych ustawień przeglądarek. Po utworzeniu nowego profilu w przeglądarce kliknij **Odśwież profile**. Lista, zaznaczenia i wspólny przełącznik są zachowywane po restarcie.

W **Ustawienia → Wygląd** wybierz jeden z czterech wariantów z podglądem aktywnych opcji:

- **Pasek:** kompaktowe pola przeglądarek o szerokościach 110/55 pkt.
- **Kafelki:** większe pola przeglądarek obok siebie.
- **Lista:** szerokie pola przeglądarek jedno pod drugim.
- **Dwie kolumny:** dwa równe pola obok siebie.

W każdym wariancie przeglądarka zachowuje swój rozmiar niezależnie od liczby dodatków. Główny profil zajmuje górne **⅔ wysokości**, a włączone dodatkowe profile dzielą dolną **⅓** pola tej samej przeglądarki. Przy większej liczbie dodatków dolny pasek można przewijać poziomo. Bez dodatków główny przycisk wypełnia całe pole.

Ostatnia główna przeglądarka jest pierwsza: po lewej lub na górze listy. Wybór dodatkowego profilu nie zmienia kolejności głównych przeglądarek. **⌘1 i ⌘2** wybierają główne przyciski, a **⌘3–⌘9** kolejne dodatkowe profile, najpierw pierwszej, potem drugiej przeglądarki; pozostałe są dostępne myszą. Układ jest dopasowywany do ekranu i zapisywany po restarcie. Bez aktywnych dodatków wszystkie warianty pokazują tylko dwie główne przeglądarki.

Zakładka Profile pozwala też wskazać profile głównych przycisków. Przy dodawaniu dodatkowego profilu nieprzypisane główne przeglądarki otrzymują ich aktualne profile, aby dodatkowy wybór nie zmieniał ich działania przez mechanizm „ostatnio używany” przeglądarki. Możesz zmienić ten wybór albo przywrócić opcję „Według przeglądarki”. Profile główne dotyczą również trybów bezpośrednich i reguł aplikacji.

Adresy są przekazywane bezpośrednio do programu przeglądarki z argumentem `--profile-directory`, również jeśli jest już uruchomiona. Nie są interpretowane przez powłokę. Brak zapisanego profilu powoduje komunikat zamiast cichego otwarcia w innym profilu. Obsługiwane są standardowe katalogi użytkownika Chrome i Brave.

## Skrót

Domyślnie **⌃⌥⌘⇧B** (Hyper + B). Jeśli Karabiner mapuje Caps Lock na te cztery modyfikatory, użyj Caps Lock + B. Chooser nie remapuje Caps Lock.

Kliknij aktualny skrót w ustawieniach, następnie naciśnij nową kombinację. Wymagany jest przynajmniej Control, Option lub Command. Escape lub utrata fokusu anuluje nagrywanie. Zajęta kombinacja zgłaszana przez system nie zastępuje poprzedniego skrótu. Przytrzymanie kombinacji nie przewija kolejnych trybów.

Globalny skrót używa Carbon `RegisterEventHotKey`, a nie monitora wszystkich naciśnięć. Nie wymaga przyznawania Dostępności ani Monitorowania wprowadzania. Skróty mogą być blokowane przez system, Secure Input lub inne oprogramowanie; fizyczną konfigurację Karabinera trzeba sprawdzić na docelowym komputerze.

## Linki wewnątrz przeglądarek

Chooser obsługuje tylko adresy przekazane przez macOS jako HTTP/HTTPS. Nie przechwytuje kliknięć na stronach: pozostają w Chrome lub Brave. To strona, gest użytkownika i ustawienia przeglądarki decydują, czy taki link otworzy się w bieżącej czy nowej karcie. Wymuszanie nowej karty dla każdego kliknięcia wewnętrznego nie jest funkcją systemowego handlera URL.

Jeśli przeglądarka jawnie przekaże link do systemu, Chooser korzysta z identyfikatora nadawcy Apple Event, gdy jest dostępny, i kieruje go do tej samej przeglądarki. Nie zgaduje źródła z aplikacji aktualnie na pierwszym planie. Gdy nadawca jest pośrednikiem systemowym, obowiązuje aktywny tryb.

Otwieranie używa `NSWorkspace` z jawnym wskazaniem aplikacji. Profile, okna i karty pozostają pod kontrolą Brave/Chrome; aplikacja nie używa AppleScript ani uprawnień Automatyzacji.

## Cienie i komunikaty

Okienko wyboru oraz HUD używają wspólnego `ShadowedPanel`. Widoczna karta jest przycinana do zaokrąglonego kształtu, a cień jest osobnym `Canvas` z `.shadowOnly` i `.drawingGroup(opaque: false)`. Parametry zgodne ze wzorcem Scribe: czarny 28%, promień 14 pkt, przesunięcie w dół 6 pkt i zapas 48 pkt po każdej stronie.

Cień mieszka w większym przezroczystym panelu potomnym, ułożonym pod kartą. Oba panele mają wyłączony cień systemowy. Panel dekoracji ignoruje zdarzenia myszy, więc również widoczne piksele rozmycia przepuszczają kliknięcia do okna poniżej. Karta zachowuje natywne przyciski AppKit. Zmiana rozmiaru aktualizuje ramkę cienia; ukrycie usuwa oba okna. Zapas może wyjść poza fizyczną krawędź monitora, ale nie przesuwa karty spod kursora.

HUD wygasza i pokazuje kartę oraz cień razem, bez przejmowania fokusu. Szybkie zmiany trybu zastępują poprzedni HUD; stara animacja nie usuwa nowszego. Ograniczenie ruchu wyłącza animacje.

## Weryfikacja

```sh
./scripts/test.sh
./scripts/build.sh
codesign --verify --deep --strict build/Chooser.app
```

Testy bez XCTest sprawdzają geometrię okienka na trzech układach monitorów (ponad 87 tys. asercji), trwałość preferencji, kolejność trybów i filtrowanie protokołów. Testy natywnych okien sprawdzają również zapas na cień, oddzielenie dekoracji od treści, flagi przepuszczania kliknięć, zmianę rozmiaru, zastępowanie HUD, brak przejęcia fokusu oraz usuwanie obu paneli. Nie zastępują obserwacji artefaktów kompozytora na żywym ekranie; sprawdź też dolne narożniki po opuszczeniu okienka kursorem.

Test integracji bez zmiany domyślnej przeglądarki:

```sh
open -a "$PWD/build/Chooser.app" 'https://example.com'
```

Ręcznie sprawdź: drugi klik bez ruchu myszy, wybór drugiej przeglądarki i ponowne otwarcie okienka, anulowanie przez Escape/kliknięcie poza, kilka linków, przełączanie fizycznym Hyper + B przy aktywnej innej aplikacji, HUD bez zmiany fokusu, restart aplikacji, start po ponownym logowaniu. Rzeczywiste wylogowanie i zmiana domyślnej przeglądarki nie są częścią automatycznych testów.

## Wydajność

Aplikacja czeka na zdarzenia systemowe; nie odpytuje przeglądarek w tle. Monitor kliknięć działa tylko przy otwartym okienku wyboru, a timer komunikatu jest jednorazowy. Ikony paska menu są przetwarzane raz na tryb w trakcie uruchomienia, a przyciski zachowują logo do kolejnych przerysowań.

Powtarzalny mikrobenchmark (bez otwierania linków i zmiany ustawień):

```sh
./scripts/benchmark.sh
```

Mierzy przygotowanie ikony paska menu, budowę/rysowanie karty z 10 dodatkowymi profilami oraz tworzenie i zwalnianie paneli z cieniem. Sprawdza też, czy po 101 cyklach nie pozostały zatrzymane panele. Wyniki zależą od komputera i obciążenia; nie obejmują czasu uruchomienia przeglądarki ani pełnego profilowania GPU. Testy natywnych okien wymagają zalogowanej sesji graficznej macOS.

## API Apple

- [Ustawienie domyślnego handlera URL](https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopenurlswithscheme:completion:))
- [Start przy logowaniu: SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)
