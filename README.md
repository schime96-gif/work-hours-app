# Work Hours Tracker (Flutter)

Mobilna aplikacija: korisnik upisuje od-kad do-kad je radio za svaki dan, a aplikacija zbraja sate po mjesecu i godini.
Uključeno:
- Godina -> 12 mjeseci (prikaz ukupno sati po mjesecu)
- Mjesečni pregled sa svim danima i unosom vremena (Od/Do)
- Smjene preko ponoći (npr. 22:00-06:00)
- Default smjena (promjenjiva, pamti se)
- Gumb "Kopiraj jučer -> danas" (radi unutar trenutnog mjeseca)
- Export u PDF (print/share kroz native dialog)

## Pokretanje

1) Instaliraj Flutter: https://docs.flutter.dev/get-started/install
2) U rootu projekta:
   flutter pub get
3) Pokreni:
   flutter run

## Build APK (Android)
flutter build apk --release

## Napomena za iOS
Za iOS build treba macOS + Xcode.
