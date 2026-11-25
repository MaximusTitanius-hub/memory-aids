# Memory Aids

A Mac app that turns your study notes (typed, pasted or a PDF) into visual memory aids using 20 memory techniques: exaggeration, absurdity, animation, personification, emotional association, memory palace, story chaining, colour coding, symbol association, acronyms, formula triangles, size distortion, multisensory association, rhymes and songs, mind maps, dual coding, gamification (collectible cards), chunking, active recall and spaced repetition.

## Install

1. Open the latest release on this repository's **Releases** page and download `MemoryAids.dmg`.
2. Open it and drag **Memory Aids** into **Applications**.
3. First launch only: right-click **Memory Aids** in Applications, choose **Open**, then **Open** again. (The app isn't signed with a paid Apple Developer account, so macOS asks once.) On macOS 15 or later, if there's no Open button, go to System Settings > Privacy & Security and click **Open Anyway**.

## Which AI makes the aids

- **Apple on-device AI (free, offline)**: needs a Mac with an Apple chip (M1 or later), macOS 26, and Apple Intelligence turned on (System Settings > Apple Intelligence & Siri).
- **Claude (optional)**: add an API key from console.anthropic.com in Memory Aids > Settings. Richer aids, a drawn illustration for each aid, and it can read scanned PDFs. Costs a few pence per study set.

## Using it

1. **New study set**: paste notes or import a PDF, choose techniques (or "All 20"), press **Create memory aids**.
2. Browse the aids: mind maps, formula triangles, memory palace floor plans, colour-coded groups, story chains, collectible cards and more. **Read aloud** speaks an aid (good for rhymes and songs).
3. **Study**: answer flashcards from memory, then rate yourself. Cards come back after 1, 2, 4, 8, 16, 32 and 64 days.

## For developers

SwiftUI + Swift Package Manager, macOS 14+. `scripts/build_dmg.sh` builds a universal app and disk image on macOS; GitHub Actions (`.github/workflows/build.yml`) runs it on every push and publishes a release from `main`.
