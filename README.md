# Facharbeit:

Dieses Repository enthält den praktischen Teil meiner Facharbeit zum Thema:

**"Einfluss von Programmiersprachen auf die Ressourceneffizienz von Computerspielen"**
Eine Analyse am Beispiel von RollerCoaster Tycoon und einem Vergleich von Assembly x86-64, C++ und JavaScript anhand eines Minispiels

=> Ein Chrome Dino Minispiel implementiert in drei Sprachen: **Assembly (x86-64)**, **C++** und **JavaScript**.

## 📁 Repository-Struktur

in asm/ ist die ausführbare Assembly-Datei, der Source-Code und das Object-File

in cpp/ ist die ausführbare CPP-Datei und der Source-Code

in js/ ist der Javascript source code

in logs/ sind messungen zur Ressourceneffizienz
in videos/ sind demo-videos

unter facharbeit.pdf ist die komplette anonyme facharbeit

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
