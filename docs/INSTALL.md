# Instalacja Klawy na iPhonie (z Linuxa)

Jednorazowo ~30–60 min. Potem co 7 dni odświeżenie z samego telefonu (~1 min).

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
