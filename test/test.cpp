#include <cstdlib>
#include <ctime>
#include <fcntl.h>
#include <iostream>
#include <termios.h>
#include <unistd.h>
#include <vector>

class Player {
public:
  int x[4];
  int y[4];
  char playerChar;
  bool isJumping = false;
  int jumpStartY[4];
  int jumpPhase = 0;
  int stepCounter = 0;
  int fallWait = 0;
  const int UP_STEPS = 3;
  const int HANG_FRAMES = 6;
  const int DOWN_STEPS = 3;
  const int FALL_DELAY = 2;

  void jump() {
    if (isJumping)
      return;
    isJumping = true;
    jumpPhase = 0;
    stepCounter = 0;
    fallWait = 0;
    for (int i = 0; i < 4; i++) {
      jumpStartY[i] = y[i];
    }
  }

  void updateJump() {
    if (!isJumping)
      return;

    if (jumpPhase == 0) {
      if (stepCounter < UP_STEPS) {
        for (int i = 0; i < 4; i++)
          y[i]--;
        stepCounter++;
        return;
      }
      jumpPhase = 1;
      stepCounter = 0;
      return;
    }

    if (jumpPhase == 1) {
      if (stepCounter < HANG_FRAMES) {
        stepCounter++;
        return;
      }
      jumpPhase = 2;
      stepCounter = 0;
      fallWait = 0;
      return;
    }

    if (jumpPhase == 2) {
      fallWait++;
      if (fallWait < FALL_DELAY)
        return;
      fallWait = 0;

      if (stepCounter < DOWN_STEPS) {
        for (int i = 0; i < 4; i++) {
          y[i]++;
          if (y[i] >= jumpStartY[i])
            y[i] = jumpStartY[i];
        }
        stepCounter++;
        return;
      }
      isJumping = false;
      jumpPhase = 0;
      stepCounter = 0;
      fallWait = 0;
    }
  }

  Player(int x[], int y[], char pc) : playerChar(pc) {
    for (int i = 0; i < 4; i++) {
      this->x[i] = x[i];
      this->y[i] = y[i];
    }
  }
};

class Obstacle {
public:
  int width;
  int height;
  int *pX;
  int *pY;
  char obstacleChar;

  Obstacle(int w, int h, int startX, int startY, char oc)
      : width(w), height(h), obstacleChar(oc) {
    int size = width * height;
    pX = new int[size];
    pY = new int[size];

    int index = 0;
    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        pX[index] = startX + j;
        pY[index] = startY + i;
        index++;
      }
    }
  }

  ~Obstacle() {
    delete[] pX;
    delete[] pY;
  }

  // Bewegung nach links
  void move() {
    int size = width * height;
    for (int i = 0; i < size; i++) {
      pX[i]--;
    }
  }

  // Prüfen ob noch im sichtbaren Bereich
  bool isVisible() const {
    int size = width * height;
    for (int i = 0; i < size; i++) {
      if (pX[i] > 0)
        return true; // Noch mindestens ein Teil sichtbar
    }
    return false;
  }

  // Rechte Kante für Abstandsberechnung
  int getRightEdge() const {
    int maxX = 0;
    int size = width * height;
    for (int i = 0; i < size; i++) {
      if (pX[i] > maxX)
        maxX = pX[i];
    }
    return maxX;
  }
};

bool isRunning = true;
const int WIDTH = 80;
const int HEIGHT = 10;
const int GROUND_Y = 8;
const int MIN_OBSTACLE_DISTANCE = 4; // Mindestabstand zwischen Hindernissen

Player *pPlayer = nullptr;
std::vector<Obstacle *> obstacles; // ← Alle Hindernisse
int frameCounter = 0;              // ← Für Spawn-Timing
int lastObstacleX = WIDTH + 10;    // ← Letzte Hindernis-Position

void inputOn() {
  struct termios tty;
  tcgetattr(STDIN_FILENO, &tty);
  tty.c_lflag &= ~(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &tty);
  fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);
}

void inputOff() {
  struct termios tty;
  tcgetattr(STDIN_FILENO, &tty);
  tty.c_lflag |= (ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &tty);
}

void handleInput() {
  char c;
  if (read(STDIN_FILENO, &c, 1) == 1) {
    switch (c) {
    case 'q':
      isRunning = false;
      break;
    case ' ':
      pPlayer->jump();
      break;
    }
  }
}

bool isPlayer(int x, int y) {
  if (!pPlayer)
    return false;
  for (int i = 0; i < 4; i++) {
    if (x == pPlayer->x[i] && y == pPlayer->y[i])
      return true;
  }
  return false;
}

bool isObstacle(int x, int y) {
  for (auto *obs : obstacles) {
    int size = obs->width * obs->height;
    for (int i = 0; i < size; i++) {
      if (x == obs->pX[i] && y == obs->pY[i])
        return true;
    }
  }
  return false;
}

bool checkCollision() {
  if (!pPlayer)
    return false;
  for (int i = 0; i < 4; i++) {
    if (isObstacle(pPlayer->x[i], pPlayer->y[i])) {
      return true;
    }
  }
  return false;
}

bool isBottom(int x, int y) { return y >= GROUND_Y; }

void spawnObstacle() {
  // Zufällige Größe: 1-3 breit, 1-2 hoch
  int w = 1 + rand() % 3;
  int h = 1 + rand() % 2;

  // Startposition: Rechts außerhalb des Bildschirms
  int startX = WIDTH + 1;

  // Y-Position: Auf dem Boden (GROUND_Y - Höhe)
  int startY = GROUND_Y - h;

  char chars[] = {'#', '@', '%', '&', 'X'};
  char oc = chars[rand() % 5];

  obstacles.push_back(new Obstacle(w, h, startX, startY, oc));
  lastObstacleX = startX + w;
}

void updateObstacles() {
  // Alle Hindernisse bewegen
  for (auto *obs : obstacles) {
    obs->move();
  }

  // Invisible Hindernisse löschen
  for (auto it = obstacles.begin(); it != obstacles.end();) {
    if (!(*it)->isVisible()) {
      delete *it;
      it = obstacles.erase(it);
    } else {
      ++it;
    }
  }

  // Neues Hindernis spawnen?
  // Prüfe Abstand zum rechtesten Hindernis
  int rightmostX = 0;
  for (auto *obs : obstacles) {
    int right = obs->getRightEdge();
    if (right > rightmostX)
      rightmostX = right;
  }

  // Wenn genug Abstand (oder keine Hindernisse), erstelle neues
  if (rightmostX < WIDTH - MIN_OBSTACLE_DISTANCE || obstacles.empty()) {
    // Zusätzlich: Zufällige Verzögerung damit nicht zu viele kommen
    if (rand() % 30 == 0) { // 1/30 Chance pro Frame
      spawnObstacle();
    }
  }
}

void drawCanvas() {
  system("clear");

  for (int y = 1; y <= HEIGHT; y++) {
    for (int x = 1; x <= WIDTH; x++) {
      if (isPlayer(x, y)) {
        std::cout << pPlayer->playerChar;
      } else if (isObstacle(x, y)) {
        // Finde welches Hindernis und zeige dessen Char
        for (auto *obs : obstacles) {
          int size = obs->width * obs->height;
          for (int i = 0; i < size; i++) {
            if (x == obs->pX[i] && y == obs->pY[i]) {
              std::cout << obs->obstacleChar;
              goto nextChar; // Einfacher Break aus verschachtelten Loops
            }
          }
        }
      nextChar:;
      } else if (isBottom(x, y)) {
        std::cout << "*";
      } else {
        std::cout << " ";
      }
    }
    std::cout << "\n";
  }
}

int main() {
  srand(time(nullptr)); // Zufall initialisieren

  int xCoords[4] = {5, 5, 6, 6};
  int yCoords[4] = {6, 7, 6, 7};
  Player player(xCoords, yCoords, '0');
  pPlayer = &player;

  inputOn();

  do {
    handleInput();
    pPlayer->updateJump();
    updateObstacles(); // ← Hindernisse bewegen & spawnen

    // Kollisionsprüfung
    if (checkCollision()) {
      // Game Over - einfache Version
      system("clear");
      std::cout << "GAME OVER!\n";
      sleep(2);
      isRunning = false;
    }

    drawCanvas();
    usleep(50000); // 20 FPS
  } while (isRunning);

  // Aufräumen
  for (auto *obs : obstacles)
    delete obs;
  obstacles.clear();

  inputOff();
  return 0;
}
