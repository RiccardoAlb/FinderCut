<p align="center">
  <img src="Resources/icon_1024.png" width="128" alt="FinderCut icon">
</p>

<h1 align="center">FinderCut</h1>

<p align="center">
  <b>Cut &amp; paste (move) files in Finder with ⌘X / ⌘V — like on Windows.</b><br>
  <b>Taglia e incolla (sposta) i file nel Finder con ⌘X / ⌘V — come su Windows.</b>
</p>

<p align="center">
  <a href="#english">English</a> · <a href="#italiano">Italiano</a>
</p>

---

## English

macOS Finder has no "cut". You have to copy with ⌘C and then remember to move with ⌥⌘V.
FinderCut is a tiny, free and open-source menu bar app that lets you simply press **⌘X** and then **⌘V**.

### Features
- **⌘X** on files/folders in Finder, then **⌘V** in the destination → the items are **moved**.
- Optional **Hide cut files**: cut items disappear until you paste (or cancel), then show up again at their new place.
- Safe by design: everything hidden is tracked on disk and restored on cancel, quit, or next launch.
- Text fields (renaming, search) keep the normal ⌘X / ⌘V behaviour; a plain ⌘C then ⌘V still copies.
- Menu bar icon with status, on/off switch and launch at login.
- No network, no tracking, no ads. MIT licensed.

### How it works
1. ⌘X in Finder → FinderCut performs a normal copy and remembers the clipboard state.
2. ⌘V → if nothing else was copied meanwhile, it sends **⌥⌘V** ("Move Item Here"); otherwise ⌘V works as usual.

### Build & run
Requires macOS 13+ and Xcode / Swift toolchain.
```bash
git clone https://github.com/RiccardoAlb/FinderCut.git && cd FinderCut
./build.sh
open build/FinderCut.app
```
Grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility).
With ad-hoc signing macOS may ask you to grant it again after each rebuild.

If you moved a cross-volume item with "Hide cut files", macOS asks once for **Automation** permission (to read the destination folder from Finder).

### Tests
```bash
swift test
```
If your checkout is inside an iCloud-synced folder (e.g. Documents), codesign of the test bundle can fail. Build outside it:
```bash
swift test --scratch-path ~/Library/Caches/FinderCut-build
```

### Contributing
Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

### License
[MIT](LICENSE)

---

## Italiano

Il Finder di macOS non ha "taglia": devi copiare con ⌘C e poi ricordarti di spostare con ⌥⌘V.
FinderCut è una piccola app gratuita e open source nella barra dei menu che ti permette di premere semplicemente **⌘X** e poi **⌘V**.

### Funzionalità
- **⌘X** su file/cartelle nel Finder, poi **⌘V** nella destinazione → gli elementi vengono **spostati**.
- **Nascondi i file tagliati** (opzionale): gli elementi tagliati spariscono finché non incolli (o annulli), poi riappaiono nella nuova posizione.
- Sicura per progetto: tutto ciò che viene nascosto è salvato su disco e ripristinato in caso di annullamento, uscita o al lancio successivo.
- I campi di testo (rinomina, ricerca) mantengono il normale ⌘X / ⌘V; un semplice ⌘C poi ⌘V continua a copiare.
- Icona nella barra dei menu con stato, interruttore on/off e avvio al login.
- Nessuna rete, nessun tracciamento, nessuna pubblicità. Licenza MIT.

### Come funziona
1. ⌘X nel Finder → FinderCut esegue una normale copia e ricorda lo stato degli appunti.
2. ⌘V → se nel frattempo non hai copiato altro, invia **⌥⌘V** ("Sposta qui"); altrimenti ⌘V funziona come sempre.

### Compilare e avviare
Richiede macOS 13+ e Xcode / toolchain Swift.
```bash
git clone https://github.com/RiccardoAlb/FinderCut.git && cd FinderCut
./build.sh
open build/FinderCut.app
```
Concedi il permesso **Accessibilità** quando richiesto (Impostazioni di Sistema → Privacy e sicurezza → Accessibilità).
Con la firma ad-hoc macOS può chiederti di riconcederlo a ogni ricompilazione.

Se sposti elementi su un altro volume con "Nascondi i file tagliati", macOS chiede una volta il permesso **Automazione** (per leggere dal Finder la cartella di destinazione).

### Test
```bash
swift test
```
Se la cartella è dentro una posizione sincronizzata con iCloud (es. Documenti), il codesign del bundle di test può fallire. Compila fuori da lì:
```bash
swift test --scratch-path ~/Library/Caches/FinderCut-build
```

### Contribuire
Issue e pull request sono benvenute — vedi [CONTRIBUTING.md](CONTRIBUTING.md).

### Licenza
[MIT](LICENSE)
