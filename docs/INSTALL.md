# Instalacja Klawy na iPhonie (z Linuxa)

Jednorazowo ~30–60 min. Potem co 7 dni odświeżenie z samego telefonu (~1 min).

## Wariant bez SideStore (aktualnie używany)

Logowanie Apple ID w SideStore na telefonie nie działało, więc Klawę instaluje sam iloader z komputera:

1. Pobierz `Klawa.ipa` na komputer:
   ```bash
   curl -L -o ~/Downloads/Klawa.ipa https://github.com/exdede/klawa/releases/download/nightly/Klawa.ipa
   ```
2. Podłącz iPhone'a kablem → iloader → zaloguj Apple ID → **Import IPA** → wybierz `~/Downloads/Klawa.ipa`.
3. Na iPhonie: Settings → General → VPN & Device Management → twój Apple ID → **Trust**.
4. Klawiaturę włączasz jak w punkcie 11 niżej.

**Co 7 dni** powtórz kroki 1–2 (~2 min, kablem). Dane Klawy zostają. Ten sam sposób instaluje nowe wersje.
Developer Mode musi zostać włączony, dopóki używasz Klawy. Po wyłączeniu Klawa przestaje działać.

## 1. Raz, na Linuxie

1. Sterownik do iPhone'a po kablu:
   ```bash
   sudo apt install usbmuxd
   ```
2. Pobierz **iloader** tylko z oficjalnego miejsca: <https://github.com/nab138/iloader/releases> (wersja dla Linuxa).
3. Podłącz iPhone'a kablem, odblokuj, stuknij „Zaufaj” i wpisz kod.
4. W iloaderze zaloguj się Apple ID i wybierz instalację SideStore. iloader sam wgra plik parowania.
   - Apple ID może być poboczne, nie musi to być główne konto z iPhone'a. Hasło wpisujesz bezpośrednio w iloaderze. Trafia do Apple, nie do mnie.

## 2. Raz, na iPhonie

5. Ustawienia → Prywatność i ochrona → **Tryb dewelopera** → włącz → restart → potwierdź.
   (Opcja pojawia się dopiero po zainstalowaniu SideStore.)
6. Ustawienia → Ogólne → **VPN i zarządzanie urządzeniami** → twój Apple ID → **Ufaj**.
7. Z App Store zainstaluj **LocalDevVPN**. SideStore potrzebuje go do instalowania i odświeżania bez komputera. Włączaj go przed użyciem SideStore.
8. Otwórz SideStore i zaloguj się tym samym Apple ID.

## 3. Instalacja Klawy

9. W Safari na iPhonie otwórz link i pobierz plik:
   <https://github.com/exdede/klawa/releases/download/nightly/Klawa.ipa>
10. SideStore → **My Apps** → **+** → Pliki → folder Pobrane → `Klawa.ipa`.
11. Ustawienia → Ogólne → Klawiatura → Klawiatury → **Dodaj nową klawiaturę** → Klawa.
    Potem stuknij „Klawa” na liście → **Pozwól na pełny dostęp**.

## 4. Test etapu 0 (wyślij mi wyniki)

- [ ] W Notatkach przełącz globusem na Klawę. Działają litery, ⇧, ⌫, spacja, enter?
- [ ] Górna linijka klawiatury: przepisz dokładnie, co pokazuje (np. „Pełny dostęp: tak · grupa: ok”).
- [ ] Czy pod klawiaturą widać **mikrofon**? Czy dyktowanie działa przy Klawie? Po polsku czy po angielsku?
- [ ] Otwórz apkę Klawa → sekcja „Test etapu 0”: przepisz wszystkie 4 wiersze.
- [ ] SideStore → My Apps → **Refresh All** przy włączonym LocalDevVPN: przeszło czy był błąd (jaki)?

## Co 7 dni

Włącz LocalDevVPN → SideStore → **Refresh All**.
Kiedy Klawa wygaśnie, iPhone sam wraca do klawiatury Apple. Dane zostają, a po odświeżeniu Klawa znowu działa.
Można to zautomatyzować: Skróty → Automatyzacja → codziennie o stałej porze → akcja SideStore „Refresh All” (jeśli SideStore ją udostępnia).

## Nowa wersja Klawy

Link z punktu 9 zawsze prowadzi do najnowszego buildu. Pobierz go i zainstaluj przez SideStore, nadpisując starą wersję.

## Test etapu 1 (napisz, co nie działa albo co ci przeszkadza)

- [ ] Szybkie pisanie dwoma kciukami: nie gubi liter, kolejność się zgadza.
- [ ] Przytrzymanie: `e` daje 3 ę é…, `a` daje ą…, `.` daje interpunkcję. Przesuń palec, puść i wstawi się wybrany znak. Także przy lewej i prawej krawędzi.
- [ ] Shift raz = jedna wielka litera. Dwa szybkie stuknięcia = caps lock (ikona z kreską).
- [ ] Backspace przytrzymany: najpierw litery, po ~1,5 s całe słowa (też emoji na końcu tekstu).
- [ ] Spacja przytrzymana albo przesunięta w bok przesuwa kursor, także przez emoji i polskie litery.
- [ ] Dwie szybkie spacje po słowie dają `. `, ale po `?` czy `!` nie.
- [ ] `123` i `#+=`: cyfry i symbole, spacja wraca do liter.
- [ ] 😊 otwiera emoji, ostatnio użyte są na górze, `ABC` wraca.
- [ ] Pole e-mail ma `@`, pole adresu WWW ma `/`.
- [ ] Apka Klawa → Układ → Colemak / Colemak-DH, potem otwórz klawiaturę ponownie.
- [ ] Klawisz `A` / `PL` / `EN`: czy zmienia język **dyktowania Apple** (mikrofon pod klawiaturą)?
- [ ] Wygląd w trybie jasnym i ciemnym, wibracje.
