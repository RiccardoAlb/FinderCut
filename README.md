# FinderCut

Open-source ⌘X / ⌘V for Finder: cut and paste (move) files like on Windows.

## How it works
- **⌘X** in Finder → does a normal copy and remembers it as a "cut".
- **⌘V** → if nothing else was copied in the meantime, sends **⌥⌘V** ("Move Item Here").
- Text fields (renaming, search) are untouched; ⌘V after a plain ⌘C still copies.

## Build & run
```bash
./build.sh
open build/FinderCut.app
```
Grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility).
The menu bar scissors icon shows status, an on/off toggle and launch-at-login.

Note: ad-hoc signing means macOS may ask you to re-grant the permission after each rebuild.

## License
MIT

## Tests
```bash
swift test
```
