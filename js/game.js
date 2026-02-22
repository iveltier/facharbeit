const readline = require("readline");
let isRunning = true;
const HEIGHT = 15;
const WIDTH = 60;
const GROUND_Y = 12;
const MIN_DISTANCE = 10
let pPlayer = null;
let obstacles = [];
let score = 0;

class Player {
    constructor(x, y, playerChar) {
        this.x = [...x];
        this.y = [...y];
        this.playerChar = playerChar;
        this.isJumping = true;
        this.jumpStartY = [...y];
        this.jumpPhase = 0;
        this.stepCounter = 0;
    }
    jump() {
        if (this.isJumping) {
            return;
        }
        this.isJumping = true;
    }
    updateJump() {
        if (!this.isJumping) {
            return;
        }

        if (this.jumpPhase === 0) {
            if (this.stepCounter < 4) {
                for (let index = 0; index < 4; index++) {
                    this.y[index]--;
                }
                this.stepCounter++;
                return;
            }
            this.jumpPhase = 1;
            this.stepCounter = 0;
            return;
        }
        if (this.jumpPhase === 1) {
            if (this.stepCounter < 2) {
                this.stepCounter++;
                return;
            }
            this.jumpPhase = 2;
            this.stepCounter = 0;
            return;
        }
        if (this.jumpPhase === 2) {
            if (this.stepCounter < 4) {
                for (let index = 0; index < 4; index++) {
                    this.y[index]++;
                }
                this.stepCounter++;

                for (let i = 0; i < 4; i++) {
                    if (this.y[i] >= this.jumpStartY[i]) {
                        this.y[i] = this.jumpStartY[i];
                    }
                }
                return;
            }
            this.jumpPhase = 0;
            this.stepCounter = 0;
            this.isJumping = false;
            return;
        }
    }
}

class Obstacle {
    constructor(width, height, startX, startY, obstacleChar) {
        this.width = width;
        this.height = height;
        this.obstacleChar = obstacleChar
        const size = width * height
        this.pX = new Array(size)
        this.pY = new Array(size)

        let index = 0;
        for (let i = 0; i < height; i++) {
            for (let j = 0; j < width; j++) {
                this.pX[index] = startX + j;
                this.pY[index] = startY + i
                index++;
            }
        }
    }
    move() {
        const size = this.width * this.height;
        for (let i = 0; i < size; i++) {
            this.pX[i]--;
        }
    }
    isVisible() {
        const size = this.width * this.height;
        for (let i = 0; i < size; i++) {
            if (this.pX[i] > 0) { return true }

        }
        return false
    }

    getRightEdge() {
        let maxX = 0;
        const size = this.width * this.height;
        for (let i = 0; i < size; i++) {
            if (this.pX[i] > maxX) { maxX = this.pX[i] }
        }
        return maxX
    }
}

function spawnObstacle() {
    const width = Math.floor((Math.random() * 3) + 1);
    const height = Math.floor((Math.random() * 2) + 1);

    const startX = WIDTH + 1;
    const startY = GROUND_Y - height;

    const chars = ['#', '+', 'X', 'q', '@', '*'];
    const obstacleChar = chars[Math.floor(Math.random() * chars.length)];

    obstacles.push(new Obstacle(width, height, startX, startY, obstacleChar))
}

function updateObstacles() {
    for (let obstacle of obstacles) {
        obstacle.move()
    }
    obstacles = obstacles.filter(obstacle => {
        if (!obstacle.isVisible()) {
            score++;
            return false;
        }
        return true
    })

    let rightMostX = 0;
    for (let obstacle of obstacles) {
        const rightEdge = obstacle.getRightEdge();
        if (rightEdge > rightMostX) rightMostX = rightEdge;
    }

    if (rightMostX < WIDTH - MIN_DISTANCE || obstacles.length === 0) {
        if (Math.floor(Math.random() * 18) === 0) {
            spawnObstacle()
        }

    }
};
function isPlayer(x, y) {
    for (let i = 0; i < 4; i++) {
        if (x === pPlayer.x[i] && y === pPlayer.y[i]) {
            return true;
        }
    }
    return false;
}

function isObstacle(x, y) {
    for (let obstacle of obstacles) {
        const size = obstacle.width * obstacle.height;
        for (let indx = 0; indx < size; indx++) {
            if (x === obstacle.pX[indx] && y === obstacle.pY[indx]) return true
        }
    }
    return false;
}

function isGround(y) {
    return y >= GROUND_Y ? true : false;
}

function getObstacleChar(x, y) {
    for (let obstacle of obstacles) {
        const size = obstacle.width * obstacle.height;
        for (let indx = 0; indx < size; indx++) {
            if (x === obstacle.pX[indx] && y === obstacle.pY[indx]) { return obstacle.obstacleChar };
        }
    }
    return " ";
}

function setupInput() {
    readline.emitKeypressEvents(process.stdin);
    if (process.stdin.isTTY) {
        process.stdin.setRawMode(true);
    }

    process.stdin.on("keypress", (str, key) => {
        if (key.name === "q") {
            isRunning = false;
        }
        if (str === " ") {
            pPlayer.jump();
        }
    });
}
function drawCanvas() {
    process.stdout.write("\x1Bc")
    process.stdout.write("\x1B[?25l")

    console.log("PRESS 'SPACE' TO JUMP")
    console.log("SCORE: ", score)
    for (let y = 1; y <= HEIGHT; y++) {
        for (let x = 1; x <= WIDTH; x++) {
            if (isPlayer(x, y)) {
                process.stdout.write(pPlayer.playerChar);
            }
            else if (isObstacle(x, y)) {
                process.stdout.write(getObstacleChar(x, y))
            }
            else if (isGround(y)) {
                process.stdout.write("*");
            } else {
                process.stdout.write(" ");
            }
        }
        process.stdout.write("\n");
    }
}

function checkCollision() {
    for (let i = 0; i < 4; i++) {
        return isObstacle(pPlayer.x[i], pPlayer.y[i])
    }
}


async function main() {
    const playerX = [5, 5, 6, 6];
    const playerY = [GROUND_Y - 1, GROUND_Y - 2, GROUND_Y - 1, GROUND_Y - 2];

    const player = new Player(playerX, playerY, "O");
    pPlayer = player;

    setupInput();
    while (isRunning) {
        pPlayer.updateJump();
        updateObstacles();

        if (checkCollision()) {
            isRunning = false;
        }

        drawCanvas();

        const delay = (50000 - score * 500) / 1000
        await new Promise((resolve) => setTimeout(resolve, delay));
    }

    process.stdout.write("\x1Bc")
    process.stdout.write("\x1B[?25h");
    console.log("****** GAME OVER *******\n")
    await new Promise((resolve) => setTimeout(resolve, 900));
    console.log("SCORE: ", score)
    console.log("DEVELOPER-HIGHSCORE: 67")
    console.log("\n*** Thanks for playing :D")
    process.exit(0)
}
main();
