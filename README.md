# Facharbeit:

Dieses Repository enthält den praktischen Teil meiner Facharbeit zum Thema:

**"Einfluss von Programmiersprachen auf die Ressourceneffizienz von Computerspielen"**
Eine Analyse am Beispiel von RollerCoaster Tycoon und einem Vergleich von Assembly x86-64, C++ und JavaScript anhand eines Minispiels

=> Ein Chrome Dino Minispiel implementiert in drei Sprachen: **Assembly (x86-64)**, **C++** und **JavaScript**.

## 📁 Repository-Struktur

facharbeit/

├── asm/ # Assembly (x86-64) Implementierung
│ ├── dino.asm # Quellcode
│ ├── dino # Kompilierte Binärdatei
│ └── ...
├── cpp/ # C++ Implementierung
│ ├── dino.cpp # Quellcode
│ └── dino
├── js/ # JavaScript (Node.js) Implementierung
│ └── dino.js
├── videos/ # Dokumentationsvideos
│ ├── asm_demo.mp4 # Assembly Version
│ ├── cpp_demo.mp4 # C++ Version
│ └── js_demo.mp4 # JavaScript Version
├── logs/ # Messergebnisse & Rohdaten
│ ├── asm.csv # Assembly Version
│ ├── cpp.csv # C++ Version
│ └── js.csv # JS Version
└── README.md # Diese Datei

in logs/ sind messungen zur Ressourceneffizienz
in videos sind demo-videos

# Installation

## Schnellstart

Die ausführbaren Dateien sind bereits kompiliert. Du musst nur das Repository klonen:

```bash
git clone https://github.com/iveltier/facharbeit.git
cd facharbeit
```

dann einfach:

```bash
./asm/game
./cpp/game
node ./js/game.js
```

beachte das ein x86_64 System benötigt wird (Arch & Ubuntu erfolgreich getestet)
um das JS-File auszuführen wird Node.js benötigt

## Neu kompelieren (optional)

x86_64 Assembly
Nasm muss installiert sein (!)

```bash
nasm -f elf64 dino.asm -o dino.o
ld dino.o -o dino
```

C++
gcc muss installiert sein (!)

```bash
g++ -O2 -o dino dino.cpp
```

Dieses Projekt wurde im Rahmen einer schulischen Facharbeit erstellt.
Der Code dient ausschließlich zu Demonstrationszwecken.

Die Implementierung der drei Sprachversionen erfolgte eigenständig; zur Umsetzung selbst entworfener Konzepte wurde teilweise generative KI als unterstützendes Werkzeug eingesetzt, der resultierende Code jedoch eigenständig angepasst und validiert.
