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
      if (stepCounter < 4) {
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

      if (stepCounter < 1) {
        stepCounter++;
        return;
      }
      jumpPhase = 2;
      stepCounter = 0;
      return;
    }

    if (jumpPhase == 2) {
      if (stepCounter < 4) {
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

class Obstacle {
public:
  int width;
  int height;
  int *pX;
  int *pY;
  char obstacleChar;

  Obstacle(int width, int height, int startX, int startY, char obstacleChar) {
    this->width = width;
    this->height = height;
    this->obstacleChar = obstacleChar;
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

  void move() {
    int size = width * height;
    for (int i = 0; i < size; i++) {
      pX[i]--;
    }
  }

  bool isVisible() const {
    int size = width * height;
    for (int i = 0; i < size; i++) {
      if (pX[i] > 0)
        return true;
    }
    return false;
  }

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
int score = 0;
const int WIDTH = 60;
const int HEIGHT = 15;
const int GROUND_Y = 12;

std::vector<Obstacle *> obstacles;
int frameCounter = 0;
int lastObstacleX = WIDTH + 10;

Player *pPlayer = nullptr;

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

bool isBottom(int x, int y) { return y >= GROUND_Y; }

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

void spawnObstacle() {
  int width = 1 + rand() % 3;
  int height = 1 + rand() % 2;

  int startX = WIDTH + 1;
  int startY = GROUND_Y - height;

  char chars[] = {'#', '@', '%', '&', 'X'};
  char obstacleChar = chars[rand() % 5];

  obstacles.push_back(
      new Obstacle(width, height, startX, startY, obstacleChar));
  lastObstacleX = startX + width;
}

void updateObstacles() {
  for (auto *obs : obstacles) {
    obs->move();
  }

  for (auto it = obstacles.begin(); it != obstacles.end();) {
    if (!(*it)->isVisible()) {
      delete *it;
      it = obstacles.erase(it);
      score++;
    } else {
      ++it;
    }
  }

  int rightMostX = 0;
  for (auto *obs : obstacles) {
    int right = obs->getRightEdge();
    if (right > rightMostX)
      rightMostX = right;
  }

  if (rightMostX < WIDTH - 15 || obstacles.empty()) {
    if (rand() % 18 == 0) {
      spawnObstacle();
    }
  }
}

void drawCanvas() {
  system("clear");
  std::cout << "\x1B[?25l";
  std::cout << "PRESS'SPACE' TO JUMP\n";
  std::cout << "SCORE: " << score << "\n";
  for (int y = 1; y <= HEIGHT; y++) {
    for (int x = 1; x <= WIDTH; x++) {
      if (isPlayer(x, y)) {
        std::cout << pPlayer->playerChar;
      } else if (isObstacle(x, y)) {
        for (auto *obs : obstacles) {
          int size = obs->width * obs->height;
          for (int i = 0; i < size; i++) {
            if (x == obs->pX[i] && y == obs->pY[i]) {
              std::cout << obs->obstacleChar;
            }
          }
        }
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
  srand(time(NULL));
  int xCoords[4] = {5, 5, 6, 6};
  int yCoords[4] = {GROUND_Y - 1, GROUND_Y - 2, GROUND_Y - 1, GROUND_Y - 2};

  Player player(xCoords, yCoords, '0');

  pPlayer = &player;

  inputOn();
  do {
    handleInput();
    pPlayer->updateJump();
    updateObstacles();
    if (checkCollision()) {
      isRunning = false;
    }

    drawCanvas();
    usleep(50000 - (score * 500));
  } while (isRunning);

  for (auto *obs : obstacles)
    delete obs;
  obstacles.clear();
  inputOff();

  system("clear");
  std::cout << "************* GAME OVER! *************\n";
  std::cout << "\nThanks for playing!\n\n";
  std::cout << "Final score: " << score;
  if (score > 59) {
    usleep(200000);
    std::cout << "\nYou just broke the developer-highscore!";
  }
  std::cout << "\nDeveloper-Highscore: 59";
  std::cout << "\x1B[?25h";
  usleep(900000);
  return 0;
}
