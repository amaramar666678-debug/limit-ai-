# multi mause

**A lightweight, smooth AI workspace for OpenCode — with a ten-cursor mouse team that works together on Windows.**

`multi mause` is a Flutter desktop client for [OpenCode](https://opencode.ai/). It combines a fast AI chat interface, live model selection, and a **Multi Mause** mode that sends ten real mouse clicks to different positions at high speed. The app UI is **English by default**; Arabic can be switched on from Settings.

---

## 📥 Download & run (easiest way)

1. Go to the latest [Release](https://github.com/amaramar666678-debug/limit-ai-/releases/latest).
2. Download `multi-mause-windows-x64.zip`.
3. Extract it and run `limit_ai.exe`.
4. In Settings (⚙️):
   - Set the **OpenCode endpoint** (or click *Auto-detect*).
   - Set the **Project directory** — the folder your agent will work in.

> A running OpenCode server (`opencode serve` or the desktop app) is required for chat and model selection. Multi Mause works even without it.

---

## ✨ Features

### AI chat
- Fast, dark, fluent interface in English (Arabic available in Settings).
- Model picker loaded from `/api/model` with a built-in fallback list and support for variants such as `high` / `max`.
- Live agent status animation: **Thinking → Writing → Running tool → Waiting**.
- Delete sessions from the sidebar or the top bar, with confirmation.
- Tool calls, code blocks, copy button, and interrupt support.

### Multi Mause — the ten-cursor team
- **10 cursors** that move and click in patterns: row, column, 5×2 grid, circle, and diagonal.
- **Agent team control**: type something like `open Chrome and search for cat images`; the instruction is sent to the agent while the team carries it out on the desktop.
- Real keyboard automation (Win+R, paste, Enter) to launch Chrome and search for images or information.
- **Precise control** with manual `X / Y` coordinates plus Move/Click buttons.
- Adjustable spacing and click interval, double-click mode, 3-second countdown, live preview, and instant stop with **Esc**.

### Language
- English is the default language.
- Open **Settings → Language** and choose **العربية** to switch the interface to Arabic.

---

## 🛠️ Build from source

Requires **Flutter 3.44+** and **Windows 10/11**:

```powershell
git clone https://github.com/amaramar666678-debug/limit-ai-.git
cd limit-ai-
flutter pub get
dart run tool/generate_icon.dart
flutter build windows
```

Output: `build\x64\runner\Release\` — copy the whole `Release` folder (all DLLs are required).

For development:

```powershell
flutter run -d windows
```

---

## ℹ️ Important notes

- Windows exposes **only one physical cursor**. The ten team actions are therefore executed in rapid sequence with a visual indicator for each cursor, rather than ten independent system cursors.
- Clicks are real and affect open applications. Use the Stop button or **Esc** at any time.
- The official logo lives at `assets/logo_multi_mause.webp` and is also used as the Windows app icon.

---

## 📁 Repository

- Source: https://github.com/amaramar666678-debug/limit-ai-
- Built with Flutter + Dart on top of the OpenCode HTTP API.

---

## نسخة عربية مختصرة

**multi mause** — مساحة عمل ذكية لـ OpenCode مع فريق من 10 مؤشرات فأرة حقيقية على Windows. اللغة الافتراضية هي الإنجليزية، ويمكن تغييرها إلى العربية من الإعدادات. التحميل: [أحدث إصدار](https://github.com/amaramar666678-debug/limit-ai-/releases/latest).
