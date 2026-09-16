#include<stdio.h>
#include<stdlib.h>
#include<raylib.h>
#include<rcamera.h>

const int window_width = 640;
const int window_height = 470;

int main(){
    InitWindow(window_width, window_height, "First Project");

    Camera3D camera = {0};
    camera.position = (Vector3){10.0f, 5.0f, 10.0f}; // Camera's position
    camera.target = (Vector3){0.0f, 0.0f, 0.0f}; 
    camera.up = (Vector3) {0.0f, 1.0f, 0.0f}; 
    camera.fovy = 45.0f; // Camera's FOV
    camera.projection = CAMERA_PERSPECTIVE;

    Vector3 spherePos = {0.0f, 0.0f, 0.0f}; // position of the sphere.
    SetTargetFPS(60);

    while(!WindowShouldClose())
    {
        UpdateCamera(&camera, CAMERA_ORBITAL);

        BeginDrawing();

        ClearBackground(RAYWHITE);
        BeginMode3D(camera); // Render anything between here and EndMode3D
        DrawSphere(spherePos, 2.0f, MAROON);
        DrawSphereWires(spherePos, 2.0f, 16, 16, BLACK);
        DrawGrid(10, 1.0f);
        EndMode3D();

        EndDrawing();
    }

    CloseWindow();
    return 0;
}