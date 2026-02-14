#include <fcntl.h>
#include <iostream>
#include <termios.h>
#include <unistd.h>

class Player {
public:
  int x[4];
  int y[4];
  char playerChar;
  bool isJumping = false;
  int jumpStartY[4];

  int jumpPhase = 0;
  int stepCounter = 0;
  const int UP_STEPS = 4;
  const int HANG_FRAMES = 1;
  const int DOWN_STEPS = 8;

  void jump() {
    if (isJumping)
      return;
    isJumping = true;
    for (int i = 0; i < 4; i++) {
      jumpStartY[i] = y[i];
    }
  }
  void updateJump() {
    if (!isJumping)
      return;

    if (jumpPhase == 0) {
      if (stepCounter < UP_STEPS) {
        for (int i = 0; i < 4; i++) {
          y[i]--;
        }
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
      return;
    }

    if (jumpPhase == 2) {
      if (stepCounter % 2 == 1) {
        stepCounter++;
        return;
      }
      if (stepCounter < DOWN_STEPS) {
        for (int i = 0; i < 4; i++) {
          y[i]++;
        }
        stepCounter++;

        for (int i = 0; i < 4; i++) {
          if (y[i] >= jumpStartY[i]) {
            y[i] = jumpStartY[i];
          }
        }
        return;
      }
      isJumping = false;
      jumpPhase = 0;
      stepCounter = 0;
    }
  }

  Player(int x[], int y[], char playerChar) {
    int size = 4;
    for (int i = 0; i < size; i++) {
      this->x[i] = x[i];
      this->y[i] = y[i];
    }
    this->playerChar = playerChar;
  }
};

bool isRunning = true;
const int WIDTH = 80;
const int HEIGHT = 10;

Player *pPlayer = nullptr;

void inputOn() {
  struct termios tty;
  tcgetattr(STDIN_FILENO, &tty);
  tty.c_lflag &= ~(ICANON | ECHO); // Kein Enter, kein Echo
  tcsetattr(STDIN_FILENO, TCSANOW, &tty);

  fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK); // Non-blocking input
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
    };
  }
};
bool isPlayer(int x, int y) {
  if (pPlayer == nullptr)
    return false;

  for (int i = 0; i < 4; i++) {
    if (x == pPlayer->x[i] && y == pPlayer->y[i]) {
      return true;
    }
  }
  return false;
}

bool isBottom(int x, int y) { return y >= 8; }

void drawCanvas() {
  // std::cout << "\033[2J\033[1;1H";
  system("clear");

  for (int y = 1; y <= HEIGHT; y++) {
    for (int x = 1; x <= WIDTH; x++) {
      if (isPlayer(x, y)) {
        std::cout << pPlayer->playerChar;
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
  int xCoords[4] = {5, 5, 6, 6};
  int yCoords[4] = {6, 7, 6, 7};

  Player player(xCoords, yCoords, '0');

  pPlayer = &player;

  inputOn();
  do {
    handleInput();
    pPlayer->updateJump();
    drawCanvas();
    usleep(50000);
  } while (isRunning);

  inputOff();
  return 0;
}
