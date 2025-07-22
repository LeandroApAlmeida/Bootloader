
// Este código em C implementa o estágio 3 do bootloader. O estágio 3 consiste no programa que carregaria
// ou implementario o kernel do sistema operacional. Como não há sistema operacional, o estágio 3 implementa
// o jogo da cobrinha em x86 modo real.


#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdbool.h>
#include <conio.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>
#include "PDCurses/curses.h"
#include <windows.h>
#include <mmsystem.h>




// Número de linhas e  colunas da matriz.
#define SIZE 26




// Define o tipo de dado gravado numa célula da matriz.
typedef struct {
    int direction;      // Direção do movimento da cobrinha na célula.
    int value;          // Valor da célula.
} Cell;


// Define uma coordenada da matriz (x, y).
typedef struct {
    int x;              // Coordenada X.
    int y;              // Coordenada Y.
} Coord;


// Define uma direção de movimento.
enum Direction {
    UNDEFINED,          // 0 - Indefinida.
    UP,                 // 1 - Para cima.
    DOWN,               // 2 - Para baixo.
    RIGHT,              // 3 - Para a direita.
    LEFT                // 4 - Para a esquerda.
};


// Define o valor de uma célula.
enum CellValue {
    EMPTY,              // 0 - Célula vazia.
    SNAKE,              // 1 - Parte do corpo da cobrinha.
    APPLE,              // 2 - Maçã.
    EATEN_APPLE         // 3 - Maçã comida.
};




// Matriz do jogo da cobrinha.
Cell matrix[SIZE][SIZE];

// Pontuação do jogo.
int score;

// Estatus de jogo terminado.
bool game_over;

// Ponteiro para a célula da cabeça da cobrinha.
Coord hptr;

// Ponteiro para a célula da cauda da cobrinha.
Coord tptr;

// Direção atual do movimento da cobrinha.
int direction;

// Tempo de vida da maçã. 
int atimer;

// Contador de tempo de vida da maçã.
int ctimer;

// Controla a execução do jogo.
bool running = true;




Coord get_random_cell();

void move_apple();

void move_snake();

void print_score();

Coord get_next_cell(Coord position, int direction);

void render_matrix();




// Inicia o jogo da cobrinha. Ao iniciar, reinicia a matriz com células vazias, os contadores do jogo
// e move a maçã para uma casa vazia aleatória.

void start_game() {

    initscr();

    clear();

    atimer = 50;

    ctimer = 0;

    score = 0;

    game_over = false;
     
    int x, y;

    for (x = 0; x < SIZE; x++) {
        for (y = 0; y < SIZE; y++) {
            matrix[x][y].direction = UNDEFINED;
            matrix[x][y].value = EMPTY;
        }
    }

    direction = RIGHT;

    hptr.x = 0;
    hptr.y = 0;

    tptr.x = 0;
    tptr.y = 0;

    move_apple();

    move_snake();

}




// Move a cobrinha uma casa na direção atual. Ao mover, verifica se comeu a maçã. Se sim, incrementa
// a pontuação e aumenta o seu tamanho. Se a cobrinha colidiu consigo mesma, finaliza o jogo.

void move_snake() {

    if (!game_over) {

        matrix[hptr.x][hptr.y].direction = direction;
        
        Cell head = matrix[hptr.x][hptr.y];
        Coord coord = get_next_cell(hptr, head.direction);
        Cell next_cell = matrix[coord.x][coord.y];

        // Verifica o que tem na próxima célula a ser ocupada pela cabeça da cobrinha.

        switch (next_cell.value) {
            
            // Célula Vazia: Avança para a próxima célula.
            case EMPTY: {
  
                matrix[coord.x][coord.y].direction = matrix[hptr.x][hptr.y].direction;
                matrix[coord.x][coord.y].value = SNAKE;
  
                hptr.x = coord.x;
                hptr.y = coord.y;
  
            } break;
            
            // Maçã: Devora a maçã.
            case APPLE: {

                PlaySound("eat.wav", NULL, SND_FILENAME | SND_ASYNC);
  
                matrix[coord.x][coord.y].direction = matrix[hptr.x][hptr.y].direction;
                matrix[coord.x][coord.y].value = EATEN_APPLE;
  
                hptr.x = coord.x;
                hptr.y = coord.y;
  
                score++;
  
                ctimer = 0;
                move_apple();
  
            } break;

            // Parte da cobrinha/maçã devorada: Finaliza o jogo por conta da colisão.
            case SNAKE:
            case EATEN_APPLE: {
  
                game_over = true;
                return;
  
            } break;

        }

        Cell tail = matrix[tptr.x][tptr.y];
        coord = get_next_cell(tptr, tail.direction);

        // Verifica o que têm na cauda atual da cobrinha.

        switch (tail.value) {

            // Parte da cobrinha: Apaga a cauda atual e atualiza o ponteiro de cauda para a próxima
            // célula.

            case SNAKE: {
                
                matrix[tptr.x][tptr.y].direction = UNDEFINED;
                matrix[tptr.x][tptr.y].value = EMPTY;
                
                tptr.x = coord.x;
                tptr.y = coord.y;

            } break;
            
            // Vazio ou maçã devorada: Apenas transforma na cauda atual (SNAKE), aumentando o corpo da
            // cobrinha de tamanho.

            default: {
             
                matrix[tptr.x][tptr.y].value = SNAKE;
            
            } break;

        }

        // Se zerou o contador, move a mação para outra célula livre.

        if (ctimer == atimer) {
        
            ctimer = 0;
            
            move_apple();
        
        }

        ctimer++;

        // Renderiza a matriz na tela.

        render_matrix();

    }
    
}




// Obtém a próxima célula, de acordo com a direção do movimento e a posição atual na matriz..

Coord get_next_cell(Coord position, int direction) {

    Coord coord;

    switch (direction) {
            
        case UP: {
            coord.y = position.y;
            coord.x = position.x == 0 ? (SIZE-1) : position.x - 1;
        } break;

        case DOWN: {
            coord.y = position.y;
            coord.x = position.x == (SIZE-1) ? 0 : position.x + 1;
        } break;

        case LEFT: {
            coord.y = position.y == 0 ? (SIZE-1) : position.y - 1;
            coord.x = position.x;
        } break;

        case RIGHT: {
            coord.y = position.y == (SIZE-1) ? 0 : position.y + 1;
            coord.x = position.x;
        } break;

    }

    return coord;

}




// Move a maçã para uma posição vazia aleatória da matriz do jogo.

void move_apple() {

    int x, y;

    for (x = 0; x < SIZE; x++) {

        for (y = 0; y < SIZE; y++) {
        
            if (matrix[x][y].value == APPLE) {

                matrix[x][y].direction = UNDEFINED;
                matrix[x][y].value = EMPTY;
            
            }
        
        }
    
    }
    
    Coord coord = get_random_cell();

    matrix[coord.x][coord.y].direction = UNDEFINED;
    matrix[coord.x][coord.y].value = APPLE;

}




// Obtém uma célula vazia aleatória da matriz.

Coord get_random_cell() {

    int x = 0, y = 0;
    
    do {
        x = rand() % SIZE;
        y = rand() % SIZE;
    } while (matrix[x][y].value != EMPTY);

    Coord c;
    
    c.x = x;
    c.y = y;

    return c;

}




// Renderiza a matriz do jogo no prompt usando a biblioteca PDCursor. No caso de implementação em 
// Modo Real, será renderizado gravando diretamente na memória de vídeo cada um dos caracteres da
// tabela ASCII extendida.

void render_matrix() {

    initscr();

    clear();

    // Obtém a largura da tela
    
    int screen_width = COLS;
    int matrix_width = SIZE * 2 + 1;
    int start_x = 20 + (screen_width - matrix_width) / 2;

    // Imprime o placar do jogo centralizado
    
    mvprintw(0, start_x + (matrix_width / 2) - 6, " Pontuacao: %d", score);

    int x, y;

    // Imprime a linha superior
   
    mvprintw(1, start_x, "%c", 218);
   
    for (x = 1; x < SIZE * 2; x++) {
        mvprintw(1, start_x + x, "%c", 196);
    }
   
    mvprintw(1, start_x + SIZE * 2, "%c", 191);

    // Imprime a matriz do jogo

    for (x = 0; x < SIZE; x++) {
   
        mvprintw(x + 2, start_x, "%c", 179);
   
        for (y = 0; y < SIZE; y++) {
   
            char symbol;
   
            switch (matrix[x][y].value) {
   
                case EMPTY: symbol = ' '; break;
   
                case SNAKE: symbol = 254; break;
   
                case APPLE: symbol = 184; break;
   
                case EATEN_APPLE: symbol = 207; break;
   
            }
   
            mvprintw(x + 2, start_x + y * 2 + 1, "%c ", symbol);
   
        }
   
        mvprintw(x + 2, start_x + SIZE * 2, "%c", 179);
   
    }

    // Imprime a linha inferior
   
    mvprintw(SIZE + 2, start_x, "%c", 192);
   
    for (x = 1; x < SIZE * 2; x++) {
        mvprintw(SIZE + 2, start_x + x, "%c", 196);
    }
   
    mvprintw(SIZE + 2, start_x + SIZE * 2, "%c", 217);

    refresh();
    
}




// Captura a entrada do teclado. Esta função é uma improvisação para testar o jogo rodando no sistema
// operacional Windows.

void* keyboard_listener(void* arg) {
    
    while (running) {
        
        char key = _getch();
        
        switch (key) {

            case 32: {
                start_game();
            } break;
        
            case 72: {
                if (direction != UP && direction != DOWN) {
                    direction = UP;
                }
            } break;
        
            case 80: {
                if (direction != DOWN && direction != UP) {
                    direction = DOWN;
                }
            } break;
        
            case 75: {
                if (direction != LEFT && direction != RIGHT) {
                    direction = LEFT;
                }
            } break;
        
            case 77: {
                if (direction != RIGHT && direction != LEFT) {
                    direction = RIGHT;
                }
            } break;

            case 27: {
                running = false;
            } break;

        }

    }

    return NULL;

}




// Ponto de entrada do programa. Inicia o jogo e entra no loop. No modo protegido, nesta função que
// configura a pilha e memória.

int main() {

    keybd_event(VK_MENU, 0, 0, 0);

    keybd_event(VK_RETURN, 0, 0, 0);

    keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, 0);

    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);

    srand(time(NULL));

    start_game();

    pthread_t keyboard_thread;

    pthread_create(&keyboard_thread, NULL, keyboard_listener, NULL);

    curs_set(0);

    while (running) {

        move_snake();

        usleep(200000);

    }

    endwin();

    return 0;

}