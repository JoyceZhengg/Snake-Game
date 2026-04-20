#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

// grid and timining things
#define WIDTH 40
#define HEIGHT 20
#define MAX_TAIL 100
#define FRAME_DELAY_MS 100
#define SCORE 1
#define CELL_WIDTH 1
#define FRAME_BUFFER_SIZE (((HEIGHT + 4) * ((WIDTH + 2) * CELL_WIDTH + 2)) + 64)

//direction encodings
#define DIR_NONE 0
#define DIR_LEFT 1
#define DIR_RIGHT 2
#define DIR_UP 3
#define DIR_DOWN 4

// game state 
/*  this stuff is in module level globals to mirror the fixed memory layout
    each variable maps to data memory addr
    uint8_t matches 8 bit regs
*/
static uint8_t snakeHeadX;
static uint8_t snakeHeadY;
static uint8_t snakeTailX[MAX_TAIL];
static uint8_t snakeTailY[MAX_TAIL];
static uint8_t snakeTailLen;
static uint8_t bananaX;
static uint8_t bananaY;
static uint8_t snakeDirection;
static uint16_t snakeScore;
static uint8_t snakeGameOver;
static uint8_t randomState;
static uint8_t appExitRequested;

// returns 1 if any part of the snake's body is at (x, y) 
// for collision detection + rendering
static int gameTailAt(uint8_t x, uint8_t y) {
    for (uint8_t i = 0; i < snakeTailLen; i++) {
        if (snakeTailX[i] == x && snakeTailY[i] == y) {
            return 1;
        }
    }
    return 0;
}

// 8 bit linear congruential generator, TO BE REPLACED by lfsrs 
static uint8_t gameNextRandomByte(void) {
    randomState = (uint8_t)(randomState * 73u + 41u);
    return randomState;
}

// place banana @ random spot on the grid that's not occupied by da snake
static void gameSpawnBanana(void) {
    do {
        bananaX = (uint8_t)(gameNextRandomByte() % (WIDTH - 2)) + 1;
        bananaY = (uint8_t)(gameNextRandomByte() % (HEIGHT - 2)) + 1;
    } while ((bananaX == snakeHeadX && bananaY == snakeHeadY) || gameTailAt(bananaX, bananaY));
}

// resets game state for a new round
static void gameInit(uint8_t seed) {
    snakeHeadX = WIDTH / 2;
    snakeHeadY = HEIGHT / 2;
    snakeTailLen = 0;
    snakeDirection = DIR_NONE;
    snakeScore = 0;
    snakeGameOver = 0;
    randomState = seed == 0 ? 1 : seed;
    gameSpawnBanana();
}

// True if the next direction is the exact opposite of current dir, blocks backwards turns
static int gameIsReverse(uint8_t current, uint8_t next) {
    return (current == DIR_LEFT && next == DIR_RIGHT) ||
           (current == DIR_RIGHT && next == DIR_LEFT) ||
           (current == DIR_UP && next == DIR_DOWN) ||
           (current == DIR_DOWN && next == DIR_UP);
}

// sets the new direction iff its legal
static void gameSetDirection(uint8_t next) {
    if (next == DIR_NONE) {
        return;
    }

    if (snakeTailLen > 0 && gameIsReverse(snakeDirection, next)) {
        return;
    }

    snakeDirection = next;
}


static void appRequestExit(void) {
    appExitRequested = 1;
}

// shifts each tail segment forward one slot
static void gameShiftTail(void) {
    for (int i = snakeTailLen - 1; i > 0; i--) {
        snakeTailX[i] = snakeTailX[i - 1];
        snakeTailY[i] = snakeTailY[i - 1];
    }

    if (snakeTailLen > 0) {
        snakeTailX[0] = snakeHeadX;
        snakeTailY[0] = snakeHeadY;
    }
}

// move head
static void gameMoveHead(void) {
    switch (snakeDirection) {
        case DIR_LEFT:
            snakeHeadX--;
            break;
        case DIR_RIGHT:
            snakeHeadX++;
            break;
        case DIR_UP:
            snakeHeadY--;
            break;
        case DIR_DOWN:
            snakeHeadY++;
            break;
        case DIR_NONE:
            break;
    }
}

static int gameHitWall(void) {
    return snakeHeadX >= WIDTH || snakeHeadY >= HEIGHT;
}

static int gameHitSelf(void) {
    return gameTailAt(snakeHeadX, snakeHeadY);
}

static void gameCheckBanana(void) {
    if (snakeHeadX == bananaX && snakeHeadY == bananaY) {
        snakeScore += SCORE;
        if (snakeTailLen < MAX_TAIL) {
            snakeTailLen++;
        }
        gameSpawnBanana();
    }
}

/* one tick of game logic
    1. shift tail
    2. move head
    3. check for wall or self collisions at the new head position
    4. check if banana is at the new head position
skip until the player presses a direction key */
static void gameStep(void) {
    if (snakeGameOver || snakeDirection == DIR_NONE) {
        return;
    }

    gameShiftTail();
    gameMoveHead();

    if (gameHitWall() || gameHitSelf()) {
        snakeGameOver = 1;
        return;
    }

    gameCheckBanana();
}

//returns what char to draw at (x, y), snake is always displayed on top of banana
static char gameCellAt(uint8_t x, uint8_t y) {
    if (x == snakeHeadX && y == snakeHeadY) {
        return 'O';
    }
    if (x == bananaX && y == bananaY) {
        return '*';
    }
    if (gameTailAt(x, y)) {
        return 'o';
    }
    return ' ';
}

//************** terminal io, will be replaced by FPGA, just ignore this stuff **********************//

// border display for the terminal
static void appendChar(char *buffer, size_t bufferSize, size_t *length, char c) {
    if (bufferSize > 0 && *length < bufferSize - 1) {
        buffer[*length] = c;
        buffer[*length + 1] = '\0';
    }
    (*length)++;
}

static void appendString(char *buffer, size_t bufferSize, size_t *length, const char *text) {
    while (*text != '\0') {
        appendChar(buffer, bufferSize, length, *text);
        text++;
    }
}

static void appendRepeatedChar(char *buffer, size_t bufferSize, size_t *length, char c, int count) {
    for (int i = 0; i < count; i++) {
        appendChar(buffer, bufferSize, length, c);
    }
}

static size_t gameRenderFrame(char *buffer, size_t bufferSize) {
    size_t length = 0;
    char scoreLine[32];

    if (bufferSize > 0) {
        buffer[0] = '\0';
    }

    appendRepeatedChar(buffer, bufferSize, &length, '-', (WIDTH + 2) * CELL_WIDTH);
    appendChar(buffer, bufferSize, &length, '\n');

    for (uint8_t y = 0; y < HEIGHT; y++) {
        appendRepeatedChar(buffer, bufferSize, &length, '#', CELL_WIDTH);
        for (uint8_t x = 0; x < WIDTH; x++) {
            appendRepeatedChar(buffer, bufferSize, &length, gameCellAt(x, y), CELL_WIDTH);
        }
        appendRepeatedChar(buffer, bufferSize, &length, '#', CELL_WIDTH);
        appendChar(buffer, bufferSize, &length, '\n');
    }

    appendRepeatedChar(buffer, bufferSize, &length, '-', (WIDTH + 2) * CELL_WIDTH);
    appendChar(buffer, bufferSize, &length, '\n');

    snprintf(scoreLine, sizeof(scoreLine), "Score: %u     \n", (unsigned int)snakeScore);
    appendString(buffer, bufferSize, &length, scoreLine);
    appendString(buffer, bufferSize, &length, "Controls: W A S D | X to Quit\n");

    return length;
}


//more terminal io

static struct termios originalTermios;
static int originalStdinFlags;

static void termClearScreen(void) {
    printf("\033[2J\033[H");
    fflush(stdout);
}

static void termMoveCursorHome(void) {
    printf("\033[H");
}

static void termRestore(void) {
    tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios);
    fcntl(STDIN_FILENO, F_SETFL, originalStdinFlags);
    printf("\033[?25h");
    fflush(stdout);
}

static void termHandleSignal(int sig) {
    termRestore();
    termClearScreen();
    _exit(128 + sig);
}

static void termSetup(void) {
    struct termios raw;

    tcgetattr(STDIN_FILENO, &originalTermios);
    atexit(termRestore);

    raw = originalTermios;
    raw.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);

    originalStdinFlags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, originalStdinFlags | O_NONBLOCK);

    signal(SIGINT, termHandleSignal);
    signal(SIGTERM, termHandleSignal);

    printf("\033[?25l");
    fflush(stdout);
}

static int termReadKey(void) {
    unsigned char c;
    ssize_t bytesRead = read(STDIN_FILENO, &c, 1);

    if (bytesRead > 0) {
        return c;
    }
    return -1;
}

static void termDiscardInput(void) {
    while (termReadKey() != -1) {
    }
}

static void termSleepMs(int ms) {
    usleep(ms * 1000);
}

static void termDrawFrame(const char *frame) {
    termMoveCursorHome();
    fputs(frame, stdout);
    fflush(stdout);
}

static void appHandleKey(int key) {
    switch (key) {
        case 'a':
        case 'A':
            gameSetDirection(DIR_LEFT);
            break;
        case 'd':
        case 'D':
            gameSetDirection(DIR_RIGHT);
            break;
        case 'w':
        case 'W':
            gameSetDirection(DIR_UP);
            break;
        case 's':
        case 'S':
            gameSetDirection(DIR_DOWN);
            break;
        case 'x':
        case 'X':
            appRequestExit();
            break;
        default:
            break;
    }
}

static void appPollInput(void) {
    int key;

    while ((key = termReadKey()) != -1) {
        appHandleKey(key);
    }
}

static int appWaitForRestart(void) {
    int key;

    termDiscardInput();

    for (;;) {
        key = termReadKey();
        if (key == 'r' || key == 'R') {
            return 1;
        }
        if (key == 'x' || key == 'X' || key == 'q' || key == 'Q') {
            return 0;
        }
        termSleepMs(10);
    }
}

int main(void) {
    char frame[FRAME_BUFFER_SIZE];
    uint8_t seed = (uint8_t)time(NULL);

    termSetup();
    appExitRequested = 0;

    while (!appExitRequested) {
        termClearScreen();
        gameInit(seed++);

        while (!snakeGameOver && !appExitRequested) {
            gameRenderFrame(frame, sizeof(frame));
            termDrawFrame(frame);
            appPollInput();
            gameStep();
            termSleepMs(FRAME_DELAY_MS);
        }

        if (appExitRequested) {
            break;
        }

        termClearScreen();
        printf("Game Over! Final Score: %u\n", (unsigned int)snakeScore);
        printf("Press R to restart or X to quit.\n");
        fflush(stdout);

        if (!appWaitForRestart()) {
            appExitRequested = 1;
        }
    }

    termClearScreen();
    return 0;
}
