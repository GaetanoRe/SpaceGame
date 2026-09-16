#include<stdio.h>
#include<stdlib.h>
#include<raylib.h>
#include<rcamera.h>

const int window_width = 640;
const int window_height = 470;

int main(){
    InitWindow(window_width, window_height, "First Project");
    SetTargetFPS(60);

    while(!WindowShouldClose())
    {
        BeginDrawing();

        ClearBackground(RAYWHITE);

        EndDrawing();
    }

    CloseWindow();
    return 0;
}