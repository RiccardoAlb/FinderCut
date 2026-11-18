# Contributing / Contribuire

## English
Thanks for helping! 
- Open an issue to discuss bigger changes before sending a PR.
- Keep the decision logic in `Sources/FinderCutCore` (pure, unit tested) and the system glue (event tap, menu) in `Sources/FinderCut`.
- Run `swift test` before opening a PR (see the README for the iCloud `--scratch-path` note).
- Never leave user files hidden: any change touching `HideManager` needs a test.
- Be kind — see the MIT [LICENSE](LICENSE).

Ideas: dimmed/“ghost” feedback for cut items, notarized releases, Homebrew cask, localization.

## Italiano
Grazie per l'aiuto!
- Apri una issue per discutere le modifiche più grandi prima di una PR.
- Tieni la logica decisionale in `Sources/FinderCutCore` (pura, con test) e il codice di sistema (event tap, menu) in `Sources/FinderCut`.
- Esegui `swift test` prima di aprire una PR (vedi nel README la nota su `--scratch-path` per iCloud).
- Non lasciare mai file dell'utente nascosti: ogni modifica a `HideManager` richiede un test.
- Sii gentile — vedi la [LICENSE](LICENSE) MIT.

Idee: feedback "fantasma" per i file tagliati, release notarizzate, Homebrew cask, localizzazione.
