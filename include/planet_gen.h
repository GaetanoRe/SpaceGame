#ifndef __PLANET_GEN_H__

#define __PLANET_GEN_H__
#define MAX_PLANET_RADIUS 5000.0f

#include <stdint.h>

typedef enum _sun_type{
    TYPE_O,
    TYPE_B,
    TYPE_A,
    TYPE_F,
    TYPE_G,
    TYPE_K,
    TYPE_M,
    WHITE_DWARF,
    SUPERGIANT,
    NEUTRON_STAR
} SunType;

typedef enum _galaxy_id{
    GALAXY_ALPHA,
    GALAXY_BETA,
    GALAXY_GAMMA,
    GALAXY_DELTA,
    GALAXY_EPSILON,
    GALAXY_ZETA,
    GALAXY_ETA,
    GALAXY_THETA,
    GALAXY_IOTA,
    GALAXY_KAPPA,
    GALAXY_LAMBDA,
    GALAXY_MU,
    GALAXY_NU,
    GALAXY_XI,
    GALAXY_OMICRON,
    GALAXY_PI,
    GALAXY_RHO,
    GALAXY_SIGMA,
    GALAXY_TAU,
    GALAXY_UPSILON,
    GALAXY_PHI,
    GALAXY_CHI,
    GALAXY_PSI,
    GALAXY_OMEGA,
    GALAXY_COUNT
} GalaxyId;

typedef struct _entity_rgba{
    unsigned char r, g, b, a;
} EntityRGBA;

typedef enum _planet_quality{
    MINING,
    FARMING,
    INDUSTRIAL,
    BARREN
} PlanetQuality;

typedef struct _moon{
    char * name;
    float planet_distance;
    EntityRGBA color;
    float moon_radius;
    float orbit_angle;
} Moon;

typedef struct _planet{
    char * name;
    PlanetQuality planet_quality;
    EntityRGBA color;
    float sun_distance;
    float planet_radius;
    float orbit_angle;
    int num_moons;
    Moon * moons;
} Planet;

typedef struct _solar_sys{
    char * name;
    int num_planets;
    SunType sun_type;
    Planet * planets;
} SolarSystem;

typedef struct _galaxy{
    GalaxyId id;
    int num_solar_sys;
    SolarSystem * solar_systems;
} Galaxy;


typedef struct _universe{
    int num_galaxies;
    uint64_t seed;
    Galaxy * galaxies;
} Universe;

/* ------------------------------
    Generation function
   ------------------------------
    This one function is what creates the entire universe from a seed.
    All the program needs to do is fetch that seed and generate all
    data based on randomly generated numbers. The universe is 
    generated once, then stored in an sqlite database. This database
    is part of the player's entire save file. So every time you make
    a new game, you make a new universe. It returns the error code int.
*/
int generate_universe(uint64_t seed);


/* -----------------------------
    Load functions 
   -----------------------------
   These functions will load any data contained within the current
   game's sql file and then store it in memory for the game to render.
*/

// RNG functions that get reused upon generation

/* ----------------------------
    Free functions
   ----------------------------
   These functions serve to free up the data that was loaded into memory.
   These functions serve to prevent memory leaks.
*/ 

// Misclaneous 

#endif