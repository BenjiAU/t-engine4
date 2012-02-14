/*
 * Copyright (C) 2006, Greg McIntyre
 * All rights reserved. See the file named COPYING in the distribution
 * for more details.
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#define __USE_ISOC99 1
#include <math.h>
#include <float.h>
#include <assert.h>
#include "fov.h"

/* radians/degrees conversions */
#define DtoR 1.74532925199432957692e-02
#define RtoD 57.2957795130823208768

#define INV_SQRT_3 0.577350269189625764509
#define SQRT_3     1.73205080756887729353
#define SQRT_3_2   0.866025403784438646764
#define SQRT_3_4   0.433012701892219323382

/*
+---++---++---++---+
|   ||   ||   ||   |
|   ||   ||   ||   |
|   ||   ||   ||   |
+---++---++---++---+    2
+---++---++---+#####
|   ||   ||   |#####
|   ||   ||   |#####
|   ||   ||   |#####
+---++---++---+#####X 1 <-- y
+---++---++---++---+
|   ||   ||   ||   |
| @ ||   ||   ||   |       <-- srcy centre     -> dy = 0.5 = y - 0.5
|   ||   ||   ||   |
+---++---++---++---+    0
0       1       2       3       4
    ^                       ^
    |                       |
 srcx                   x            -> dx = 3.5 = x + 0.5
centre

Slope from @ to X.

+---++---++---++---+
|   ||   ||   ||   |
|   ||   ||   ||   |
|   ||   ||   ||   |
+---++---++---++---+ 2
+---++---++---++---+
|   ||   ||   ||   |
|   ||   ||   ||   |
|   ||   ||   ||   |
+---++---++---+X---+ 1   <-- y
+---++---++---+#####
|   ||   ||   |#####
| @ ||   ||   |#####      <-- srcy centre     -> dy = 0.5 = y - 0.5
|   ||   ||   |#####
+---++---++---+##### 0
0       1       2       3
    ^                       ^
    |                       |
 srcx                   x            -> dx = 2.5 = x - 0.5
centre

Slope from @ to X
*/


/* Types ---------------------------------------------------------- */

/** \cond INTERNAL */
typedef struct {
    /*@observer@*/ fov_settings_type *settings;
    /*@observer@*/ void *map;
    /*@observer@*/ void *source;
    int source_x;
    int source_y;
    unsigned radius;
} fov_private_data_type;
/** \endcond */

/* Options -------------------------------------------------------- */

void fov_settings_init(fov_settings_type *settings) {
    settings->shape = FOV_SHAPE_CIRCLE_ROUND;
    /* settings->corner_peek = FOV_CORNER_NOPEEK; */
    /* settings->opaque_apply = FOV_OPAQUE_APPLY; */
    settings->opaque = NULL;
    settings->apply = NULL;
    settings->heights = NULL;
    settings->numheights = 0;
    settings->permissiveness = 0.5f;
}

void fov_settings_set_shape(fov_settings_type *settings,
                            fov_shape_type value) {
    settings->shape = value;
}

/*
void fov_settings_set_corner_peek(fov_settings_type *settings,
                           fov_corner_peek_type value) {
    settings->corner_peek = value;
}
*/
/*
void fov_settings_set_opaque_apply(fov_settings_type *settings,
                                   fov_opaque_apply_type value) {
    settings->opaque_apply = value;
}
*/

void fov_settings_set_opacity_test_function(fov_settings_type *settings,
                                            bool (*f)(void *map,
                                                      int x, int y)) {
    settings->opaque = f;
}

void fov_settings_set_apply_lighting_function(fov_settings_type *settings,
                                              void (*f)(void *map,
                                                        int x, int y,
                                                        int dx, int dy, int radius,
                                                        void *src)) {
    settings->apply = f;
}

/* Circular FOV --------------------------------------------------- */

/*@null@*/ static unsigned *precalculate_heights(unsigned maxdist) {
    unsigned i;
    unsigned *result = (unsigned *)malloc((maxdist+2)*sizeof(unsigned));
    if (result) {
        for (i = 0; i <= maxdist; ++i) {
            result[i] = (unsigned)sqrtf((float)(maxdist*maxdist + maxdist - i*i));
        }
        result[maxdist+1] = 0;
    }
    return result;
}

static unsigned height(fov_settings_type *settings, int x,
                unsigned maxdist) {
    unsigned **newheights;

    if (maxdist > settings->numheights) {
        newheights = (unsigned **)calloc((size_t)maxdist, sizeof(unsigned*));
        if (newheights != NULL) {
            if (settings->heights != NULL && settings->numheights > 0) {
                /* Copy the pointers to the heights arrays we've already
                 * calculated. Once copied out, we can free the old
                 * array of pointers. */
                memcpy(newheights, settings->heights,
                       settings->numheights*sizeof(unsigned*));
                free(settings->heights);
            }
            settings->heights = newheights;
            settings->numheights = maxdist;
        }
    }
    if (settings->heights) {
        if (settings->heights[maxdist-1] == NULL) {
            settings->heights[maxdist-1] = precalculate_heights(maxdist);
        }
        if (settings->heights[maxdist-1] != NULL) {
            return settings->heights[maxdist-1][abs(x)];
        }
    }
    return 0;
}

void fov_settings_free(fov_settings_type *settings) {
    unsigned i;
    if (settings != NULL) {
        if (settings->heights != NULL && settings->numheights > 0) {
            /*@+forloopexec@*/
            for (i = 0; i < settings->numheights; ++i) {
                unsigned *h = settings->heights[i];
                if (h != NULL) {
                    free(h);
                }
                settings->heights[i] = NULL;
            }
            /*@=forloopexec@*/
            free(settings->heights);
            settings->heights = NULL;
            settings->numheights = 0;
        }
    }
}

/* Slope ---------------------------------------------------------- */

static float fov_slope(float dx, float dy) {
    if (dx <= -FLT_EPSILON || dx >= FLT_EPSILON) {
        return dy/dx;
    } else {
        return 0.0f;
    }
}

/* Octants -------------------------------------------------------- */

#define FOV_DEFINE_OCTANT(signx, signy, rx, ry, nx, ny, nf)                                     \
    static void fov_octant_##nx##ny##nf(                                                        \
                                        fov_private_data_type *data,                            \
                                        int dx,                                                 \
                                        float start_slope,                                      \
                                        float end_slope,                                        \
                                        bool blocked_below,                                     \
                                        bool blocked_above,                                     \
                                        bool apply_edge,                                        \
                                        bool apply_diag) {                                      \
        int x, y, dy, dy0, dy1;                                                                 \
        unsigned h;                                                                             \
        int prev_blocked = -1;                                                                  \
        float start_slope_next, end_slope_next;                                                 \
        fov_settings_type *settings = data->settings;                                           \
                                                                                                \
        if (start_slope - end_slope > GRID_EPSILON) {                                           \
            return;                                                                             \
        } else if (dx == 0) {                                                                   \
            fov_octant_##nx##ny##nf(data, dx+1, start_slope, end_slope, blocked_below, blocked_above, apply_edge, apply_diag); \
            return;                                                                             \
        } else if ((unsigned)dx > data->radius) {                                               \
            return;                                                                             \
        }                                                                                       \
        /* being "pinched" isn't blocked, but we need to handle it as a special case */         \
        if (blocked_below && blocked_above && end_slope - start_slope < GRID_EPSILON) {         \
            dy0 = (int)(0.5f + (float)dx*start_slope - GRID_EPSILON);                           \
            dy1 = (int)(0.5f + (float)dx*end_slope - GRID_EPSILON);                             \
        } else {                                                                                \
            if (blocked_below) {                                                                \
                dy0 = (int)(0.5f + (float)dx*start_slope + GRID_EPSILON);                       \
            } else {                                                                            \
                dy0 = (int)(0.5f + (float)dx*start_slope - GRID_EPSILON);                       \
            }                                                                                   \
            if (blocked_above) {                                                                \
                dy1 = (int)(0.5f + (float)dx*end_slope - GRID_EPSILON);                         \
            } else {                                                                            \
                dy1 = (int)(0.5f + (float)dx*end_slope + GRID_EPSILON);                         \
            }                                                                                   \
        }                                                                                       \
                                                                                                \
        rx = data->source_##rx signx dx;                                                        \
                                                                                                \
        /* we need to check if the previous spot is blocked */                                  \
        if (dy0 > 0) {                                                                          \
            ry = data->source_##ry signy (dy0-1);                                               \
            if (settings->opaque(data->map, x, y)) {                                            \
                prev_blocked = 1;                                                               \
            } else {                                                                            \
                prev_blocked = 0;                                                               \
            }                                                                                   \
        }                                                                                       \
                                                                                                \
        switch (settings->shape) {                                                              \
        case FOV_SHAPE_CIRCLE_ROUND :                                                           \
            h = height(settings, dx, data->radius);                                             \
            break;                                                                              \
        case FOV_SHAPE_CIRCLE_FLOOR :                                                           \
            h = (unsigned)(sqrt((data->radius)*(data->radius) + 2*data->radius - dx*dx));       \
            break;                                                                              \
        case FOV_SHAPE_CIRCLE_CEIL :                                                            \
            h = (unsigned)(sqrt((data->radius)*(data->radius) - dx*dx));                        \
            break;                                                                              \
        case FOV_SHAPE_CIRCLE_PLUS1 :                                                           \
            h = (unsigned)(sqrt((data->radius)*(data->radius) + 1 - dx*dx));                    \
            break;                                                                              \
        case FOV_SHAPE_OCTAGON:                                                                 \
            h = 2u*(data->radius - (unsigned)dx) + 1u;                                          \
            break;                                                                              \
        case FOV_SHAPE_DIAMOND :                                                                \
            h = data->radius - (unsigned)dx;                                                    \
            break;                                                                              \
        case FOV_SHAPE_SQUARE :                                                                 \
            h = data->radius;                                                                   \
            break;                                                                              \
        default :                                                                               \
            h = (unsigned)(sqrt((data->radius)*(data->radius) + data->radius - dx*dx));         \
            break;                                                                              \
        };                                                                                      \
        if ((unsigned)dy1 > h) {                                                                \
            dy1 = (int)h;                                                                       \
        }                                                                                       \
                                                                                                \
        /*fprintf(stderr, "(%2d) = [%2d .. %2d] (%f .. %f), h=%d,edge=%d\n",                    \
                dx, dy0, dy1, ((float)dx)*start_slope,                                          \
                0.5f + ((float)dx)*end_slope, h, apply_edge);*/                                 \
                                                                                                \
        for (dy = dy0; dy <= dy1; ++dy) {                                                       \
            ry = data->source_##ry signy dy;                                                    \
                                                                                                \
            if (settings->opaque(data->map, x, y)) {                                            \
                if ((apply_edge || dy > 0) && (apply_diag || dy != dx)) {                       \
                    settings->apply(data->map, x, y, x - data->source_x, y - data->source_y, data->radius, data->source); \
                }                                                                               \
                if (prev_blocked == 0 && dy != dy0) {                                           \
                    end_slope_next = ((float)dy - 0.5f) / ((float)dx + settings->permissiveness); \
                    fov_octant_##nx##ny##nf(data, dx+1, start_slope, end_slope_next, blocked_below, true, apply_edge, apply_diag); \
                }                                                                               \
                prev_blocked = 1;                                                               \
            } else {                                                                            \
                if (prev_blocked == 1) {                                                        \
                    start_slope_next = ((float)dy - 0.5f) / ((float)dx - settings->permissiveness); \
                    if (start_slope - start_slope_next < GRID_EPSILON) {                        \
                        start_slope = start_slope_next;                                         \
                        if (start_slope - end_slope > GRID_EPSILON) {                           \
                            return;                                                             \
                        }                                                                       \
                        blocked_below = true;                                                   \
                    }                                                                           \
                }                                                                               \
                if ((apply_edge || dy > 0) && (apply_diag || dy != dx)) {                       \
                    settings->apply(data->map, x, y, x - data->source_x, y - data->source_y, data->radius, data->source); \
                }                                                                               \
                prev_blocked = 0;                                                               \
            }                                                                                   \
        }                                                                                       \
                                                                                                \
        if (prev_blocked == 0) {                                                                \
            /* We need to check if the next spot is blocked and change end_slope accordingly */ \
            if (dx != dy1) {                                                                    \
                ry = data->source_##ry signy (dy1+1);                                           \
                if (settings->opaque(data->map, x, y)) {                                        \
                    end_slope_next = ((float)dy1 + 0.5f) / ((float)dx + settings->permissiveness); \
                    if (end_slope_next - end_slope < GRID_EPSILON) {                            \
                        end_slope = end_slope_next;                                             \
                        blocked_below = true;                                                   \
                    }                                                                           \
                }                                                                               \
            }                                                                                   \
            fov_octant_##nx##ny##nf(data, dx+1, start_slope, end_slope, blocked_below, blocked_above, apply_edge, apply_diag); \
        }                                                                                       \
    }

FOV_DEFINE_OCTANT(+,+,x,y,p,p,n)
FOV_DEFINE_OCTANT(+,+,y,x,p,p,y)
FOV_DEFINE_OCTANT(+,-,x,y,p,m,n)
FOV_DEFINE_OCTANT(+,-,y,x,p,m,y)
FOV_DEFINE_OCTANT(-,+,x,y,m,p,n)
FOV_DEFINE_OCTANT(-,+,y,x,m,p,y)
FOV_DEFINE_OCTANT(-,-,x,y,m,m,n)
FOV_DEFINE_OCTANT(-,-,y,x,m,m,y)


#define HEX_FOV_DEFINE_SEXTANT(signx, signy, nx, ny, one)                                                                       \
    static void hex_fov_sextant_##nx##ny(                                                                                       \
                                        fov_private_data_type *data,                                                            \
                                        int dy,                                                                                 \
                                        float start_slope,                                                                      \
                                        float end_slope,                                                                        \
                                        bool apply_edge1,                                                                       \
                                        bool apply_edge2) {                                                                     \
        int x, y, x0, x1, p;                                                                                                    \
        int prev_blocked = -1;                                                                                                  \
        float fdy, end_slope_next;                                                                                              \
        fov_settings_type *settings = data->settings;                                                                           \
                                                                                                                                \
        if (start_slope - end_slope > GRID_EPSILON) {                                                                           \
            return;                                                                                                             \
        } else if ((unsigned)dy > data->radius) {                                                                               \
            return;                                                                                                             \
        }                                                                                                                       \
                                                                                                                                \
        fdy = (float)dy;                                                                                                        \
        x0 = (int)(0.5f + fdy*start_slope / (SQRT_3_2 + 0.5f*start_slope) + GRID_EPSILON);                                      \
        x1 = (int)(0.5f + fdy*end_slope / (SQRT_3_2 + 0.5f*end_slope) - GRID_EPSILON);                                          \
        if (x1 < x0) return;                                                                                                    \
                                                                                                                                \
        x = data->source_x signx x0;                                                                                            \
        p = ((x & 1) + one) & 1;                                                                                                \
        fdy += 0.25f;                                                                                                           \
        y = data->source_y signy (dy - (x0 + 1 - p)/2);                                                                         \
                                                                                                                                \
        for (; x0 <= x1; ++x0) {                                                                                                \
            if (settings->opaque(data->map, x, y)) {                                                                            \
                if ((apply_edge1 || x0 > 0) && (apply_edge2 || x0 != dy)) {                                                     \
                    settings->apply(data->map, x, y, x - data->source_x, y - data->source_y, data->radius, data->source);       \
                }                                                                                                               \
                if (prev_blocked == 0) {                                                                                        \
                    end_slope_next = (-SQRT_3_4 + SQRT_3_2*(float)x0) / (fdy - 0.5f*(float)x0);                                 \
                    hex_fov_sextant_##nx##ny(data, dy+1, start_slope, end_slope_next, apply_edge1, apply_edge2);                \
                }                                                                                                               \
                prev_blocked = 1;                                                                                               \
            } else {                                                                                                            \
                if (prev_blocked == 1) {                                                                                        \
                    start_slope = (-SQRT_3_4 + SQRT_3_2*(float)x0) / (fdy - 0.5f*(float)x0);                                    \
                }                                                                                                               \
                if ((apply_edge1 || x0 > 0) && (apply_edge2 || x0 != dy)) {                                                     \
                    settings->apply(data->map, x, y, x - data->source_x, y - data->source_y, data->radius, data->source);       \
                }                                                                                                               \
                prev_blocked = 0;                                                                                               \
            }                                                                                                                   \
            y = y signy (-p);                                                                                                   \
            x = x signx 1;                                                                                                      \
            p = !p;                                                                                                             \
        }                                                                                                                       \
                                                                                                                                \
        if (prev_blocked == 0) {                                                                                                \
            hex_fov_sextant_##nx##ny(data, dy+1, start_slope, end_slope, apply_edge1, apply_edge2);                             \
        }                                                                                                                       \
    }


#define HEX_FOV_DEFINE_LR_SEXTANT(signx, nx)                                                                                    \
    static void hex_fov_sextant_##nx(                                                                                           \
                                        fov_private_data_type *data,                                                            \
                                        int dx,                                                                                 \
                                        float start_slope,                                                                      \
                                        float end_slope,                                                                        \
                                        bool apply_edge1,                                                                       \
                                        bool apply_edge2) {                                                                     \
        int x, y, y0, y1, p;                                                                                                    \
        int prev_blocked = -1;                                                                                                  \
        float fdx, fdy, end_slope_next;                                                                                         \
        fov_settings_type *settings = data->settings;                                                                           \
                                                                                                                                \
        if (start_slope - end_slope > GRID_EPSILON) {                                                                           \
            return;                                                                                                             \
        } else if ((unsigned)dx > data->radius) {                                                                               \
            return;                                                                                                             \
        }                                                                                                                       \
                                                                                                                                \
        x = data->source_x signx dx;                                                                                            \
        fdx = (float)dx * SQRT_3_2;                                                                                             \
        fdy = -0.5f*(float)dx - 0.5f;                                                                                           \
                                                                                                                                \
        p = -dx / 2 - (dx & 1)*(x & 1);                                                                                         \
        y0 = (int)(fdx*start_slope - fdy + GRID_EPSILON);                                                                       \
        y1 = (int)(fdx*end_slope - fdy - GRID_EPSILON);                                                                         \
        if (y1 < y0) return;                                                                                                    \
                                                                                                                                \
        y = data->source_y + y0 + p;                                                                                            \
                                                                                                                                \
        for (; y0 <= y1; ++y0) {                                                                                                \
            if (settings->opaque(data->map, x, y)) {                                                                            \
                if ((apply_edge1 || y0 > 0) && (apply_edge2 || y0 != dx)) {                                                     \
                    settings->apply(data->map, x, y, x - data->source_x, y - data->source_y, data->radius, data->source);       \
                }                                                                                                               \
                if (prev_blocked == 0) {                                                                                        \
                    end_slope_next = ((float)y0 + fdy) / fdx;                                                                   \
                    hex_fov_sextant_##nx(data, dx+1, start_slope, end_slope_next, apply_edge1, apply_edge2);                    \
                }                                                                                                               \
                prev_blocked = 1;                                                                                               \
            } else {                                                                                                            \
                if (prev_blocked == 1) {                                                                                        \
                    start_slope = ((float)y0 + fdy) / fdx;                                                                      \
                }                                                                                                               \
                if ((apply_edge1 || y0 > 0) && (apply_edge2 || y0 != dx)) {                                                     \
                    settings->apply(data->map, x, y, x - data->source_x, y - data->source_y, data->radius, data->source);       \
                }                                                                                                               \
                prev_blocked = 0;                                                                                               \
            }                                                                                                                   \
            ++y;                                                                                                                \
        }                                                                                                                       \
                                                                                                                                \
        if (prev_blocked == 0) {                                                                                                \
            hex_fov_sextant_##nx(data, dx+1, start_slope, end_slope, apply_edge1, apply_edge2);                                 \
        }                                                                                                                       \
    }

HEX_FOV_DEFINE_SEXTANT(+,+,n,e,1)
HEX_FOV_DEFINE_SEXTANT(-,+,n,w,1)
HEX_FOV_DEFINE_SEXTANT(+,-,s,e,0)
HEX_FOV_DEFINE_SEXTANT(-,-,s,w,0)
HEX_FOV_DEFINE_LR_SEXTANT(+,e)
HEX_FOV_DEFINE_LR_SEXTANT(-,w)


/* Circle --------------------------------------------------------- */

static void _fov_circle(fov_private_data_type *data) {
    /*
     * Octants are defined by (x,y,r) where:
     *  x = [p]ositive or [n]egative x increment
     *  y = [p]ositive or [n]egative y increment
     *  r = [y]es or [n]o for reflecting on axis x = y
     *
     *   \pmy|ppy/
     *    \  |  /
     *     \ | /
     *   mpn\|/ppn
     *   ----@----
     *   mmn/|\pmn
     *     / | \
     *    /  |  \
     *   /mmy|mpy\
     */
    fov_octant_ppn(data, 1, (float)0.0f, (float)1.0f, false, false, true, true);
    fov_octant_ppy(data, 1, (float)0.0f, (float)1.0f, false, false, true, false);
    fov_octant_pmy(data, 1, (float)0.0f, (float)1.0f, false, false, false, true);
    fov_octant_mpn(data, 1, (float)0.0f, (float)1.0f, false, false, true, false);
    fov_octant_mmn(data, 1, (float)0.0f, (float)1.0f, false, false, false, true);
    fov_octant_mmy(data, 1, (float)0.0f, (float)1.0f, false, false, true, false);
    fov_octant_mpy(data, 1, (float)0.0f, (float)1.0f, false, false, false, true);
    fov_octant_pmn(data, 1, (float)0.0f, (float)1.0f, false, false, false, false);
}

static void _hex_fov_circle(fov_private_data_type *data) {
/*
  _            |            _
   \___2   nw 1|1 ne   2___/
       \___    |    ___/
       2   \__ | __/   2
     w      __>&<__      e
       1___/   |   \___1
    ___/       |       \___
  _/   2   sw 1|1 se   2   \_
               |
*/
    hex_fov_sextant_ne(data, 1, 0.0f, SQRT_3, true, true);
    hex_fov_sextant_nw(data, 1, 0.0f, SQRT_3, false, true);
    hex_fov_sextant_w(data, 1, -INV_SQRT_3, INV_SQRT_3, true, false);
    hex_fov_sextant_sw(data, 1, 0.0f, SQRT_3, true, false);
    hex_fov_sextant_se(data, 1, 0.0f, SQRT_3, false, true);
    hex_fov_sextant_e(data, 1, -INV_SQRT_3, INV_SQRT_3, false, false);
}

void fov_circle(fov_settings_type *settings,
                void *map,
                void *source,
                int source_x,
                int source_y,
                unsigned radius) {
    fov_private_data_type data;

    data.settings = settings;
    data.map = map;
    data.source = source;
    data.source_x = source_x;
    data.source_y = source_y;
    data.radius = radius;

    if (settings->shape == FOV_SHAPE_HEX)
        _hex_fov_circle(&data);
    else
        _fov_circle(&data);
}

/**
 * Limit x to the range [a, b].
 */
static float betweenf(float x, float a, float b) {
    if (x - a < FLT_EPSILON) { /* x < a */
        return a;
    } else if (x - b > FLT_EPSILON) { /* x > b */
        return b;
    } else {
        return x;
    }
}

#define BEAM_DIRECTION(d, p1, p2, p3, p4, p5, p6, p7, p8)                             \
    if (direction == d) {                                                             \
        end_slope = betweenf(a, 0.0f, 1.0f);                                          \
        fov_octant_##p1(&data, 1, 0.0f, end_slope, false, false, true, true);         \
        fov_octant_##p2(&data, 1, 0.0f, end_slope, false, false, false, true);        \
        if (a - 1.0f > FLT_EPSILON) { /* a > 1.0f */                                  \
            start_slope = betweenf(2.0f - a, 0.0f, 1.0f);                             \
            fov_octant_##p3(&data, 1, start_slope, 1.0f, false, false, true, false);  \
            fov_octant_##p4(&data, 1, start_slope, 1.0f, false, false, true, false);  \
                                                                                      \
        if (a - 2.0f > 2.0f * FLT_EPSILON) { /* a > 2.0f */                           \
            end_slope = betweenf(a - 2.0f, 0.0f, 1.0f);                               \
            fov_octant_##p5(&data, 1, 0.0f, end_slope, false, false, false, true);    \
            fov_octant_##p6(&data, 1, 0.0f, end_slope, false, false, false, true);    \
                                                                                      \
        if (a - 3.0f > 3.0 * FLT_EPSILON) { /* a > 3.0f */                            \
            start_slope = betweenf(4.0f - a, 0.0f, 1.0f);                             \
            fov_octant_##p7(&data, 1, start_slope, 1.0f, false, false, true, false);  \
            fov_octant_##p8(&data, 1, start_slope, 1.0f, false, false, false, false); \
        }}}}

#define BEAM_DIRECTION_DIAG(d, p1, p2, p3, p4, p5, p6, p7, p8)                        \
    if (direction == d) {                                                             \
        start_slope = betweenf(1.0f - a, 0.0f, 1.0f);                                 \
        fov_octant_##p1(&data, 1, start_slope, 1.0f, false, false, true, true);       \
        fov_octant_##p2(&data, 1, start_slope, 1.0f, false, false, true, false);      \
        if (a - 1.0f > FLT_EPSILON) { /* a > 1.0f */                                  \
            end_slope = betweenf(a - 1.0f, 0.0f, 1.0f);                               \
            fov_octant_##p3(&data, 1, 0.0f, end_slope, false, false, false, true);    \
            fov_octant_##p4(&data, 1, 0.0f, end_slope, false, false, false, true);    \
                                                                                      \
        if (a - 2.0f > 2.0f * FLT_EPSILON) { /* a > 2.0f */                           \
            start_slope = betweenf(3.0f - a, 0.0f, 1.0f);                             \
            fov_octant_##p5(&data, 1, start_slope, 1.0f, false, false, true, false);  \
            fov_octant_##p6(&data, 1, start_slope, 1.0f, false, false, true, false);  \
                                                                                      \
        if (a - 3.0f > 3.0f * FLT_EPSILON) { /* a > 3.0f */                           \
            end_slope = betweenf(a - 3.0f, 0.0f, 1.0f);                               \
            fov_octant_##p7(&data, 1, 0.0f, end_slope, false, false, false, true);    \
            fov_octant_##p8(&data, 1, 0.0f, end_slope, false, false, false, false);   \
        }}}}

void fov_beam(fov_settings_type *settings, void *map, void *source,
              int source_x, int source_y, unsigned radius,
              fov_direction_type direction, float angle) {

    fov_private_data_type data;
    float start_slope, end_slope, a;

    data.settings = settings;
    data.map = map;
    data.source = source;
    data.source_x = source_x;
    data.source_y = source_y;
    data.radius = radius;

    if (angle <= 0.0f) {
        return;
    } else if (angle >= 360.0f) {
        _fov_circle(&data);
        return;
    }

    /* Calculate the angle as a percentage of 45 degrees, halved (for
     * each side of the centre of the beam). e.g. angle = 180.0f means
     * half the beam is 90.0 which is 2x45, so the result is 2.0.
     */
    a = angle/90.0f;

    BEAM_DIRECTION(FOV_EAST, ppn, pmn, ppy, mpy, pmy, mmy, mpn, mmn);
    BEAM_DIRECTION(FOV_WEST, mpn, mmn, pmy, mmy, ppy, mpy, ppn, pmn);
    BEAM_DIRECTION(FOV_NORTH, mpy, mmy, pmn, mmn, ppn, mpn, ppy, pmy);
    BEAM_DIRECTION(FOV_SOUTH, pmy, ppy, mpn, ppn, mmn, pmn, mmy, mpy);
    BEAM_DIRECTION_DIAG(FOV_NORTHEAST, pmn, mpy, ppn, mmy, ppy, mmn, pmy, mpn);
    BEAM_DIRECTION_DIAG(FOV_NORTHWEST, mmn, mmy, mpn, mpy, pmy, pmn, ppy, ppn);
    BEAM_DIRECTION_DIAG(FOV_SOUTHEAST, ppy, ppn, pmy, pmn, mpn, mpy, mmn, mmy);
    BEAM_DIRECTION_DIAG(FOV_SOUTHWEST, pmy, mpn, ppy, mmn, ppn, mmy, pmn, mpy);
}

#define BEAM_ANY_DIRECTION(offset, p1, p2, p3, p4, p5, p6, p7, p8)                    \
    angle_begin -= offset;                                                            \
    angle_end -= offset;                                                              \
    start_slope = angle_begin;                                                        \
    end_slope = betweenf(angle_end, 0.0f, 1.0f);                                      \
    fov_octant_##p1(&data, 1, start_slope, end_slope, false, false, true, true);      \
                                                                                      \
    if (angle_end - 1.0f > FLT_EPSILON) {                                             \
        start_slope = betweenf(2.0f - angle_end, 0.0f, 1.0f);                         \
        fov_octant_##p2(&data, 1, start_slope, 1.0f, false, false, true, false);      \
                                                                                      \
    if (angle_end - 2.0f > 2.0f * FLT_EPSILON) {                                      \
        end_slope = betweenf(angle_end - 2.0f, 0.0f, 1.0f);                           \
        fov_octant_##p3(&data, 1, 0.0f, end_slope, false, false, false, true);        \
                                                                                      \
    if (angle_end - 3.0f > 3.0f * FLT_EPSILON) {                                      \
        start_slope = betweenf(4.0f - angle_end, 0.0f, 1.0f);                         \
        fov_octant_##p4(&data, 1, start_slope, 1.0f, false, false, true, false);      \
                                                                                      \
    if (angle_end - 4.0f > 4.0f * FLT_EPSILON) {                                      \
        end_slope = betweenf(angle_end - 4.0f, 0.0f, 1.0f);                           \
        fov_octant_##p5(&data, 1, 0.0f, end_slope, false, false, false, true);        \
                                                                                      \
    if (angle_end - 5.0f > 5.0f * FLT_EPSILON) {                                      \
        start_slope = betweenf(6.0f - angle_end, 0.0f, 1.0f);                         \
        fov_octant_##p6(&data, 1, start_slope, 1.0f, false, false, true, false);      \
                                                                                      \
    if (angle_end - 6.0f > 6.0f * FLT_EPSILON) {                                      \
        end_slope = betweenf(angle_end - 6.0f, 0.0f, 1.0f);                           \
        fov_octant_##p7(&data, 1, 0.0f, end_slope, false, false, false, true);        \
                                                                                      \
    if (angle_end - 7.0f > 7.0f * FLT_EPSILON) {                                      \
        start_slope = betweenf(8.0f - angle_end, 0.0f, 1.0f);                         \
        fov_octant_##p8(&data, 1, start_slope, 1.0f, false, false, true, false);      \
                                                                                      \
    if (angle_end - 8.0f > 8.0f * FLT_EPSILON) {                                      \
        end_slope = betweenf(angle_end - 8.0f, 0.0f, 1.0f);                           \
        start_slope = betweenf(angle_end - 8.0f, 0.0f, 1.0f);                         \
        fov_octant_##p1(&data, 1, 0.0f, end_slope, false, false, false, false);       \
    }}}}}}}}

#define BEAM_ANY_DIRECTION_DIAG(offset, p1, p2, p3, p4, p5, p6, p7, p8)               \
    angle_begin -= offset;                                                            \
    angle_end -= offset;                                                              \
    start_slope = betweenf(1.0f - angle_end, 0.0f, 1.0f);                             \
    end_slope = 1.0f - angle_begin;                                                   \
    fov_octant_##p1(&data, 1, start_slope, end_slope, false, false, true, true);      \
                                                                                      \
    if (angle_end - 1.0f > FLT_EPSILON) {                                             \
        end_slope = betweenf(angle_end - 1.0f, 0.0f, 1.0f);                           \
        fov_octant_##p2(&data, 1, 0.0f, end_slope, false, false, false, true);        \
                                                                                      \
    if (angle_end - 2.0f > 2.0f * FLT_EPSILON) {                                      \
        start_slope = betweenf(3.0f - angle_end, 0.0f, 1.0f);                         \
        fov_octant_##p3(&data, 1, start_slope, 1.0f, false, false, true, false);      \
                                                                                      \
    if (angle_end - 3.0f > 3.0f * FLT_EPSILON) {                                      \
        end_slope = betweenf(angle_end - 3.0f, 0.0f, 1.0f);                           \
        fov_octant_##p4(&data, 1, 0.0f, end_slope, false, false, false, true);        \
                                                                                      \
    if (angle_end - 4.0f > 4.0f * FLT_EPSILON) {                                      \
        start_slope = betweenf(5.0f - angle_end, 0.0f, 1.0f);                         \
        fov_octant_##p5(&data, 1, start_slope, 1.0f, false, false, true, false);      \
                                                                                      \
    if (angle_end - 5.0f > 5.0f * FLT_EPSILON) {                                      \
        end_slope = betweenf(angle_end - 5.0f, 0.0f, 1.0f);                           \
        fov_octant_##p6(&data, 1, 0.0f, end_slope, false, false, false, true);        \
                                                                                      \
    if (angle_end - 6.0f > 6.0f * FLT_EPSILON) {                                      \
        start_slope = betweenf(7.0f - angle_end, 0.0f, 1.0f);                         \
        fov_octant_##p7(&data, 1, start_slope, 1.0f, false, false, true, false);      \
                                                                                      \
    if (angle_end - 7.0f > 7.0f * FLT_EPSILON) {                                      \
        end_slope = betweenf(angle_end - 7.0f, 0.0f, 1.0f);                           \
        fov_octant_##p8(&data, 1, 0.0f, end_slope, false, false, false, true);        \
                                                                                      \
    if (angle_end - 8.0f > 8.0f * FLT_EPSILON) {                                      \
        start_slope = betweenf(9.0f - angle_end, 0.0f, 1.0f);                         \
        fov_octant_##p1(&data, 1, start_slope, 1.0f, false, false, false, false);     \
}}}}}}}}

void fov_beam_any_angle(fov_settings_type *settings, void *map, void *source,
                        int source_x, int source_y, unsigned radius,
                        float dx, float dy, float beam_angle) {

    /* Note: angle_begin and angle_end are misnomers, since FoV calculation uses slopes, not angles.
     * We previously used a tan(x) ~ 4/pi*x approximation * for x in range (0, pi/4) radians, or 45 degrees.
     * We no longer use this approximation.  Angles and slopes are calculated precisely,
     * so this function can be used for numerically precise purposes if desired.
     */

    fov_private_data_type data;
    float start_slope, end_slope, angle_begin, angle_end, x_start, y_start, x_end, y_end;

    data.settings = settings;
    data.map = map;
    data.source = source;
    data.source_x = source_x;
    data.source_y = source_y;
    data.radius = radius;

    if (beam_angle <= 0.0f) {
        return;
    } else if (beam_angle >= 360.0f) {
        if (settings->shape == FOV_SHAPE_HEX)
            _hex_fov_circle(&data);
        else
            _fov_circle(&data);
        return;
    }

    if (settings->shape == FOV_SHAPE_HEX) {
        /* time for some slightly odd conventions.  We're assuming that dx and dy are still in coordinate space so
         * that "source_x + dx" gives the target tile coordinate.  dx, dy are floats, so we have sub-tile resolution.
         * We will then calculate the "real space" x's and y's to allow beam-casting at any angle. */
        dy += (float)(((int)(abs(dx) + 0.5f)) & 1) * (0.5f - (float)(source_x & 1));
        dx *= SQRT_3_2;
    }

    beam_angle = 0.5f * DtoR * beam_angle;
    x_start = cos(beam_angle)*dx + sin(beam_angle)*dy;
    y_start = cos(beam_angle)*dy - sin(beam_angle)*dx;
    x_end   = cos(beam_angle)*dx - sin(beam_angle)*dy;
    y_end   = cos(beam_angle)*dy + sin(beam_angle)*dx;

    if (y_start > 0.0f) {
        if (x_start > 0.0f) {                      /* octant 1 */               /* octant 2 */
            angle_begin = ( y_start <  x_start) ? (y_start / x_start)        : (2.0f - x_start / y_start);
        } else {                                   /* octant 3 */               /* octant 4 */
            angle_begin = (-x_start <  y_start) ? (2.0f - x_start / y_start) : (4.0f + y_start / x_start);
        }
    } else {
        if (x_start < 0.0f) {                      /* octant 5 */               /* octant 6 */
            angle_begin = (-y_start < -x_start) ? (4.0f + y_start / x_start) : (6.0f - x_start / y_start);
        } else {                                   /* octant 7 */               /* octant 8 */
            angle_begin = ( x_start < -y_start) ? (6.0f - x_start / y_start) : (8.0f + y_start / x_start);
        }
    }

    if (y_end > 0.0f) {
        if (x_end > 0.0f) {                  /* octant 1 */           /* octant 2 */
            angle_end = ( y_end <  x_end) ? (y_end / x_end)        : (2.0f - x_end / y_end);
        } else {                             /* octant 3 */           /* octant 4 */
            angle_end = (-x_end <  y_end) ? (2.0f - x_end / y_end) : (4.0f + y_end / x_end);
        }
    } else {
        if (x_end < 0.0f) {                  /* octant 5 */           /* octant 6 */
            angle_end = (-y_end < -x_end) ? (4.0f + y_end / x_end) : (6.0f - x_end / y_end);
        } else {                             /* octant 7 */           /* octant 8 */
            angle_end = ( x_end < -y_end) ? (6.0f - x_end / y_end) : (8.0f + y_end / x_end);
        }
    }

    if (angle_end < angle_begin) {
        angle_end += 8.0f;
    }

    if (settings->shape == FOV_SHAPE_HEX) {
        if (angle_begin > 8.0f - INV_SQRT_3) {
            angle_begin -= 8.0f;
            angle_end -= 8.0f;
        }

        if(angle_begin < INV_SQRT_3) {
            //east
            start_slope = angle_begin;
            end_slope = betweenf(angle_end, -INV_SQRT_3, INV_SQRT_3);
            hex_fov_sextant_e(&data, 1, start_slope, end_slope, true, true);

            if (angle_end - INV_SQRT_3 > FLT_EPSILON) {
                start_slope = betweenf(2.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                hex_fov_sextant_ne(&data, 1, start_slope, SQRT_3, true, false);

                if (angle_end - 2.0f > 2.0f*FLT_EPSILON) {
                    end_slope = betweenf(angle_end - 2.0f, 0.0f, 2.0f - INV_SQRT_3);
                    if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                    hex_fov_sextant_nw(&data, 1, 0.0f, end_slope, false, true);

                    if (angle_end - 4.0f + INV_SQRT_3 > 3.0f*FLT_EPSILON) {
                        start_slope = betweenf(4.0f - angle_end, -INV_SQRT_3, INV_SQRT_3);
                        hex_fov_sextant_w(&data, 1, start_slope, INV_SQRT_3, true, false);

                        if (angle_end - 4.0f - INV_SQRT_3 > 5.0f*FLT_EPSILON) {
                            start_slope = betweenf(6.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                            if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                            hex_fov_sextant_sw(&data, 1, start_slope, SQRT_3, true, false);

                            if (angle_end - 6.0f > 6.0f*FLT_EPSILON) {
                                end_slope = betweenf(angle_end - 6.0f, 0.0f, 2.0f - INV_SQRT_3);
                                if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                                hex_fov_sextant_se(&data, 1, 0.0f, end_slope, false, true);

                                if (angle_end - 8.0f + INV_SQRT_3 > 7.0f*FLT_EPSILON) {
                                    end_slope = betweenf(angle_end - 8.0f, -INV_SQRT_3, INV_SQRT_3);
                                    hex_fov_sextant_e(&data, 1, -INV_SQRT_3, end_slope, false, false);
            }   }   }   }   }   }
        } else if (angle_begin < 2.0f) {
            //north-east
            start_slope = betweenf(2.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
            if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
            end_slope = betweenf(2.0f - angle_begin, 0.0f, 2.0f - INV_SQRT_3);
            if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
            hex_fov_sextant_ne(&data, 1, start_slope, end_slope, true, true);

            if (angle_end - 2.0f > 2.0f*FLT_EPSILON) {
                end_slope = betweenf(angle_end - 2.0f, 0.0f, 2.0f - INV_SQRT_3);
                if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                hex_fov_sextant_nw(&data, 1, 0.0f, end_slope, false, true);

                if (angle_end - 4.0f + INV_SQRT_3 > 3.0f*FLT_EPSILON) {
                    start_slope = betweenf(4.0f - angle_end, -INV_SQRT_3, INV_SQRT_3);
                    hex_fov_sextant_w(&data, 1, start_slope, INV_SQRT_3, true, false);

                    if (angle_end - 4.0f - INV_SQRT_3 > 5.0f*FLT_EPSILON) {
                        start_slope = betweenf(6.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                        if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                        hex_fov_sextant_sw(&data, 1, start_slope, SQRT_3, true, false);

                        if (angle_end - 6.0f > 6.0f*FLT_EPSILON) {
                            end_slope = betweenf(angle_end - 6.0f, 0.0f, 2.0f - INV_SQRT_3);
                            if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                            hex_fov_sextant_se(&data, 1, 0.0f, end_slope, false, true);

                            if (angle_end - 8.0f + INV_SQRT_3 > 7.0f*FLT_EPSILON) {
                                end_slope = betweenf(angle_end - 8.0f, -INV_SQRT_3, INV_SQRT_3);
                                hex_fov_sextant_e(&data, 1, -INV_SQRT_3, end_slope, false, true);

                                if (angle_end - 8.0f - INV_SQRT_3 > 8.0f*FLT_EPSILON) {
                                    start_slope = betweenf(10.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                                    if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                                    hex_fov_sextant_ne(&data, 1, start_slope, SQRT_3, false, false);
            }   }   }   }   }   }
        } else if (angle_begin < 4.0f - INV_SQRT_3) {
            //north-west
            start_slope = betweenf(angle_begin - 2.0f, 0.0f, 2.0f - INV_SQRT_3);
            if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
            end_slope = betweenf(angle_end - 2.0f, 0.0f, 2.0f - INV_SQRT_3);
            if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
            hex_fov_sextant_nw(&data, 1, start_slope, end_slope, true, true);

            if (angle_end - 4.0f + INV_SQRT_3 > 3.0f*FLT_EPSILON) {
                start_slope = betweenf(4.0f - angle_end, -INV_SQRT_3, INV_SQRT_3);
                hex_fov_sextant_w(&data, 1, start_slope, INV_SQRT_3, true, false);

                if (angle_end - 4.0f - INV_SQRT_3 > 5.0f*FLT_EPSILON) {
                    start_slope = betweenf(6.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                    if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                    hex_fov_sextant_sw(&data, 1, start_slope, SQRT_3, true, false);

                    if (angle_end - 6.0f > 6.0f*FLT_EPSILON) {
                        end_slope = betweenf(angle_end - 6.0f, 0.0f, 2.0f - INV_SQRT_3);
                        if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                        hex_fov_sextant_se(&data, 1, 0.0f, end_slope, false, true);

                        if (angle_end - 8.0f + INV_SQRT_3 > 7.0f*FLT_EPSILON) {
                            end_slope = betweenf(angle_end - 8.0f, -INV_SQRT_3, INV_SQRT_3);
                            hex_fov_sextant_e(&data, 1, -INV_SQRT_3, end_slope, false, true);

                            if (angle_end - 8.0f - INV_SQRT_3 > 8.0f*FLT_EPSILON) {
                                start_slope = betweenf(10.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                                if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                                hex_fov_sextant_ne(&data, 1, start_slope, SQRT_3, true, false);

                                if (angle_end - 10.0f > 10.0f*FLT_EPSILON) {
                                    end_slope = betweenf(angle_end - 10.0f, 0.0f, 2.0f - INV_SQRT_3);
                                    if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                                    hex_fov_sextant_nw(&data, 1, 0.0f, end_slope, false, false);
            }   }   }   }   }   }
        } else if (angle_begin < 4.0f + INV_SQRT_3) {
            //west
            start_slope = betweenf(4.0f - angle_end, -INV_SQRT_3, INV_SQRT_3);
            end_slope = betweenf(4.0f - angle_begin, -INV_SQRT_3, INV_SQRT_3);
            hex_fov_sextant_w(&data, 1, start_slope, end_slope, true, true);

            if (angle_end - 4.0f - INV_SQRT_3 > 5.0f*FLT_EPSILON) {
                start_slope = betweenf(6.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                hex_fov_sextant_sw(&data, 1, start_slope, SQRT_3, true, false);

                if (angle_end - 6.0f > 6.0f*FLT_EPSILON) {
                    end_slope = betweenf(angle_end - 6.0f, 0.0f, 2.0f - INV_SQRT_3);
                    if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                    hex_fov_sextant_se(&data, 1, 0.0f, end_slope, false, true);

                    if (angle_end - 8.0f + INV_SQRT_3 > 7.0f*FLT_EPSILON) {
                        end_slope = betweenf(angle_end - 8.0f, -INV_SQRT_3, INV_SQRT_3);
                        hex_fov_sextant_e(&data, 1, -INV_SQRT_3, end_slope, false, true);

                        if (angle_end - 8.0f - INV_SQRT_3 > 8.0f*FLT_EPSILON) {
                            start_slope = betweenf(10.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                            if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                            hex_fov_sextant_ne(&data, 1, start_slope, SQRT_3, true, false);

                            if (angle_end - 10.0f > 10.0f*FLT_EPSILON) {
                                end_slope = betweenf(angle_end - 10.0f, 0.0f, 2.0f - INV_SQRT_3);
                                if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                                hex_fov_sextant_nw(&data, 1, 0.0f, end_slope, false, true);

                                if (angle_end - 12.0f + INV_SQRT_3 > 11.0f*FLT_EPSILON) {
                                    start_slope = betweenf(12.0f - angle_end, -INV_SQRT_3, INV_SQRT_3);
                                    hex_fov_sextant_w(&data, 1, start_slope, INV_SQRT_3, false, false);
            }   }   }   }   }   }
        } else if (angle_begin < 6.0f) {
            //south-west
            start_slope = betweenf(6.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
            if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
            end_slope = betweenf(6.0f - angle_begin, 0.0f, 2.0f - INV_SQRT_3);
            if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
            hex_fov_sextant_sw(&data, 1, start_slope, end_slope, true, true);

            if (angle_end - 6.0f > 6.0f*FLT_EPSILON) {
                end_slope = betweenf(angle_end - 6.0f, 0.0f, 2.0f - INV_SQRT_3);
                if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                hex_fov_sextant_se(&data, 1, 0.0f, end_slope, false, true);

                if (angle_end - 8.0f + INV_SQRT_3 > 7.0f*FLT_EPSILON) {
                    end_slope = betweenf(angle_end - 8.0f, -INV_SQRT_3, INV_SQRT_3);
                    hex_fov_sextant_e(&data, 1, -INV_SQRT_3, end_slope, false, true);

                    if (angle_end - 8.0f - INV_SQRT_3 > 8.0f*FLT_EPSILON) {
                        start_slope = betweenf(10.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                        if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                        hex_fov_sextant_ne(&data, 1, start_slope, SQRT_3, true, false);

                        if (angle_end - 10.0f > 10.0f*FLT_EPSILON) {
                            end_slope = betweenf(angle_end - 10.0f, 0.0f, 2.0f - INV_SQRT_3);
                            if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                            hex_fov_sextant_nw(&data, 1, 0.0f, end_slope, false, true);

                            if (angle_end - 12.0f + INV_SQRT_3 > 11.0f*FLT_EPSILON) {
                                start_slope = betweenf(12.0f - angle_end, -INV_SQRT_3, INV_SQRT_3);
                                hex_fov_sextant_w(&data, 1, start_slope, INV_SQRT_3, true, false);

                                if (angle_end - 12.0f - INV_SQRT_3 > 12.0f*FLT_EPSILON) {
                                    start_slope = betweenf(14.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                                    if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                                    hex_fov_sextant_sw(&data, 1, start_slope, SQRT_3, false, false);
            }   }   }   }   }   }
        } else if (angle_begin < 8.0f - INV_SQRT_3) {
            //south-east
            start_slope = betweenf(angle_begin - 6.0f, 0.0f, 2.0f - INV_SQRT_3);
            if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
            end_slope = betweenf(angle_end - 6.0f, 0.0f, 2.0f - INV_SQRT_3);
            if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
            hex_fov_sextant_se(&data, 1, start_slope, end_slope, true, true);

            if (angle_end - 8.0f + INV_SQRT_3 > 7.0f*FLT_EPSILON) {
                end_slope = betweenf(angle_end - 8.0f, -INV_SQRT_3, INV_SQRT_3);
                hex_fov_sextant_e(&data, 1, -INV_SQRT_3, end_slope, false, true);

                if (angle_end - 8.0f - INV_SQRT_3 > 8.0f*FLT_EPSILON) {
                    start_slope = betweenf(10.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                    if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                    hex_fov_sextant_ne(&data, 1, start_slope, SQRT_3, true, false);

                    if (angle_end - 10.0f > 10.0f*FLT_EPSILON) {
                        end_slope = betweenf(angle_end - 10.0f, 0.0f, 2.0f - INV_SQRT_3);
                        if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                        hex_fov_sextant_nw(&data, 1, 0.0f, end_slope, false, true);

                        if (angle_end - 12.0f + INV_SQRT_3 > 11.0f*FLT_EPSILON) {
                            start_slope = betweenf(12.0f - angle_end, -INV_SQRT_3, INV_SQRT_3);
                            hex_fov_sextant_w(&data, 1, start_slope, INV_SQRT_3, true, false);

                            if (angle_end - 12.0f - INV_SQRT_3 > 12.0f*FLT_EPSILON) {
                                start_slope = betweenf(14.0f - angle_end, 0.0f, 2.0f - INV_SQRT_3);
                                if (start_slope > 1.0f) start_slope = 1.0f / (2.0f - start_slope);
                                hex_fov_sextant_sw(&data, 1, start_slope, SQRT_3, true, false);

                                if (angle_end - 14.0f > 14.0f*FLT_EPSILON) {
                                    end_slope = betweenf(angle_end - 14.0f, 0.0f, 2.0f - INV_SQRT_3);
                                    if (end_slope > 1.0f) end_slope = 1.0f / (2.0f - end_slope);
                                    hex_fov_sextant_se(&data, 1, 0.0f, end_slope, false, false);
            }   }   }   }   }   }
        }
    } else  {
        if (1.0f - angle_begin > FLT_EPSILON) {
            BEAM_ANY_DIRECTION(0.0f, ppn, ppy, pmy, mpn, mmn, mmy, mpy, pmn);
        } else if (2.0f - angle_begin > 2.0f * FLT_EPSILON) {
            BEAM_ANY_DIRECTION_DIAG(1.0f, ppy, pmy, mpn, mmn, mmy, mpy, pmn, ppn);
        } else if (3.0f - angle_begin > 3.0f * FLT_EPSILON) {
            BEAM_ANY_DIRECTION(2.0f, pmy, mpn, mmn, mmy, mpy, pmn, ppn, ppy);
        } else if (4.0f - angle_begin > 4.0f * FLT_EPSILON) {
            BEAM_ANY_DIRECTION_DIAG(3.0f, mpn, mmn, mmy, mpy, pmn, ppn, ppy, pmy);
        } else if (5.0f - angle_begin > 5.0f * FLT_EPSILON) {
            BEAM_ANY_DIRECTION(4.0f, mmn, mmy, mpy, pmn, ppn, ppy, pmy, mpn);
        } else if (6.0f - angle_begin > 6.0f * FLT_EPSILON) {
            BEAM_ANY_DIRECTION_DIAG(5.0f, mmy, mpy, pmn, ppn, ppy, pmy, mpn, mmn);
        } else if (7.0f - angle_begin > 7.0f * FLT_EPSILON) {
            BEAM_ANY_DIRECTION(6.0f, mpy, pmn, ppn, ppy, pmy, mpn, mmn, mmy);
        } else if (8.0f - angle_begin > 8.0f * FLT_EPSILON) {
            BEAM_ANY_DIRECTION_DIAG(7.0f, pmn, ppn, ppy, pmy, mpn, mmn, mmy, mpy);
        }
    }
}

 // a work in progress
#define HEX_LOS_DEFINE_SEXTANT(signx, signy, nx, ny, one)                                                                       \
    static float hex_los_sextant_##nx##ny(                                                                                      \
                                        fov_private_data_type *data,                                                            \
                                        hex_fov_line_data *line,                                                                \
                                        float start_slope,                                                                      \
                                        float target_slope,                                                                     \
                                        float end_slope) {                                                                      \
        int x, y, x0, x1, p, prev_blocked;                                                                                      \
        int dy = 1;                                                                                                             \
        int delta = line->dest_t - 1;                                                                                           \
        float fx0, fx1, fdx0, fdx1;                                                                                             \
        float fdy = 1.0f;                                                                                                       \
        fov_settings_type *settings = data->settings;                                                                           \
                                                                                                                                \
        fdx0 = start_slope / (SQRT_3_2 + 0.5f*start_slope);                                                                     \
        fdx1 = end_slope / (SQRT_3_2 + 0.5f*end_slope);                                                                         \
                                                                                                                                \
        fx0 = 0.5f + fdx0 + GRID_EPSILON;                                                                                       \
        fx1 = 0.5f + fdx1 - GRID_EPSILON;                                                                                       \
        x0 = (int)fx0;                                                                                                          \
        x1 = (int)fx1;                                                                                                          \
        x = data->source_x signx x0;                                                                                            \
        p = ((x & 1) + one) & 1;                                                                                                \
        y = data->source_y signy (1 - (x0 + 1 - p)/2);                                                                          \
                                                                                                                                \
        for (;;) {                                                                                                              \
            if (--delta < 0) {                                                                                                  \
                line->step_x = signx target_slope / (INV_SQRT_3*target_slope + 1);                                              \
                line->step_y = signy 1 / (INV_SQRT_3*target_slope + 1);                                                         \
                return;                                                                                                         \
            }                                                                                                                   \
            prev_blocked = settings->opaque(data->map, x, y);                                                                   \
            ++x0;                                                                                                               \
            y = y signy (-p);                                                                                                   \
            x = x signx 1;                                                                                                      \
            if (x0 == x1) {                                                                                                     \
                if (settings->opaque(data->map, x, y)) {                                                                        \
                    if (prev_blocked == 0) {                                                                                    \
                        end_slope = (-SQRT_3_4 + SQRT_3_2*(float)x0) / (fdy + 0.25 - 0.5f*(float)x0);                           \
                        fdx1 = end_slope / (SQRT_3_2 + 0.5f*end_slope);                                                         \
                        target_slope = end_slope;                                                                               \
                        fx1 = 0.5f + fdy*fdx1 + GRID_EPSILON;                                                                   \
                        line->eps_x = signx (-GRID_EPSILON);                                                                    \
                        line->eps_y = signy GRID_EPSILON;                                                                       \
                    } else if (prev_blocked == 1) {                                                                             \
                        line->step_x = signx target_slope / (INV_SQRT_3*target_slope + 1);                                      \
                        line->step_y = signy 1 / (INV_SQRT_3*target_slope + 1);                                                 \
                        return;                                                                                                 \
                    }                                                                                                           \
                } else if (prev_blocked == 1) {                                                                                 \
                    start_slope = (-SQRT_3_4 + SQRT_3_2*(float)x0) / (fdy + 0.25 - 0.5f*(float)x0);                             \
                    fdx0 = start_slope / (SQRT_3_2 + 0.5f*start_slope);                                                         \
                    target_slope = start_slope;                                                                                 \
                    fx0 = 0.5f + fdy*fdx0 + GRID_EPSILON;                                                                       \
                    line->eps_x = signx GRID_EPSILON;                                                                           \
                    line->eps_y = signy (-GRID_EPSILON);                                                                        \
                }                                                                                                               \
            } else if (prev_blocked == 1) {                                                                                     \
                line->step_x = signx target_slope / (INV_SQRT_3*target_slope + 1);                                              \
                line->step_y = signy 1 / (INV_SQRT_3*target_slope + 1);                                                         \
                return;                                                                                                         \
            }                                                                                                                   \
            fx0 += fdx0;                                                                                                        \
            fx1 += fdx1;                                                                                                        \
            x0 = (int)fx0;                                                                                                      \
            x1 = (int)fx1;                                                                                                      \
            x = data->source_x signx x0;                                                                                        \
            ++dy;                                                                                                               \
            fdy += 1.0f;                                                                                                        \
            p = ((x & 1) + one) & 1;                                                                                            \
            prev_blocked = -1;                                                                                                  \
            y = data->source_y signy (dy - (x0 + 1 - p)/2);                                                                     \
        }                                                                                                                       \
    }

#define HEX_LOS_DEFINE_LR_SEXTANT(signx, nx)                                                                                    \
    static float hex_los_sextant_##nx(                                                                                          \
                                        fov_private_data_type *data,                                                            \
                                        hex_fov_line_data *line,                                                                \
                                        float start_slope,                                                                      \
                                        float target_slope,                                                                     \
                                        float end_slope) {                                                                      \
        int x, y, y0, y1, p, prev_blocked;                                                                                      \
        int dx = 1;                                                                                                             \
        int delta = line->dest_t - 1;                                                                                           \
        float fy0, fy1;                                                                                                         \
        float fdx = SQRT_3_2;                                                                                                   \
        float fdy = -1.0f;                                                                                                      \
        fov_settings_type *settings = data->settings;                                                                           \
                                                                                                                                \
        x = data->source_x signx 1;                                                                                             \
        p = -(x & 1);                                                                                                           \
        fy0 = SQRT_3_2 * start_slope + 1.0f + GRID_EPSILON;                                                                     \
        fy1 = SQRT_3_2 * end_slope + 1.0f - GRID_EPSILON;                                                                       \
        y0 = (int)fy0;                                                                                                          \
        y1 = (int)fy1;                                                                                                          \
        y = data->source_y + y0 + p;                                                                                            \
                                                                                                                                \
        for (;;) {                                                                                                              \
            if (--delta < 0) {                                                                                                  \
                line->step_y = SQRT_3_2 * target_slope;                                                                         \
                return;                                                                                                         \
            }                                                                                                                   \
            prev_blocked = settings->opaque(data->map, x, y);                                                                   \
            ++y0;                                                                                                               \
            ++y;                                                                                                                \
            if (y0 == y1) {                                                                                                     \
                if (settings->opaque(data->map, x, y)) {                                                                        \
                    if (prev_blocked == 0) {                                                                                    \
                        end_slope = ((float)y0 + fdy) / fdx;                                                                    \
                        fy1 = fdx*end_slope - fdy - GRID_EPSILON;                                                               \
                        target_slope = end_slope;                                                                               \
                        line->eps_y = -GRID_EPSILON;                                                                            \
                    } else if (prev_blocked == 1) {                                                                             \
                        line->step_y = SQRT_3_2 * target_slope;                                                                 \
                        return;                                                                                                 \
                    }                                                                                                           \
                } else if (prev_blocked == 1) {                                                                                 \
                    start_slope = ((float)y0 + fdy) / fdx;                                                                      \
                    fy0 = fdx*start_slope - fdy + GRID_EPSILON;                                                                 \
                    target_slope = start_slope;                                                                                 \
                    line->eps_y = GRID_EPSILON;                                                                                 \
                }                                                                                                               \
            } else if (prev_blocked == 1) {                                                                                     \
                line->step_y = SQRT_3_2 * target_slope;                                                                         \
                return;                                                                                                         \
            }                                                                                                                   \
            x = x signx 1;                                                                                                      \
            fdx += SQRT_3_2;                                                                                                    \
            fdy -= 0.5f;                                                                                                        \
            fy0 += SQRT_3_2*start_slope + 0.5f;                                                                                 \
            fy1 += SQRT_3_2*end_slope + 0.5f;                                                                                   \
            ++dx;                                                                                                               \
            p = -dx / 2 - (dx & 1)*(x & 1);                                                                                     \
            y0 = (int)fy0;                                                                                                      \
            y1 = (int)fy1;                                                                                                      \
            y = data->source_y + y0 + p;                                                                                        \
        }                                                                                                                       \
    }

HEX_LOS_DEFINE_SEXTANT(+,+,n,e,1)
HEX_LOS_DEFINE_SEXTANT(-,+,n,w,1)
HEX_LOS_DEFINE_SEXTANT(+,-,s,e,0)
HEX_LOS_DEFINE_SEXTANT(-,-,s,w,0)
HEX_LOS_DEFINE_LR_SEXTANT(+,e)
HEX_LOS_DEFINE_LR_SEXTANT(-,w)

void hex_fov_create_los_line(fov_settings_type *settings, void *map, void *source, hex_fov_line_data *line,
                         int source_x, int source_y,
                         int dest_x, int dest_y,
                         bool start_at_end) {

    fov_private_data_type data;
    data.settings = settings;
    data.map = map;
    data.source_x = source_x;
    data.source_y = source_y;

    line->t = 0;
    line->is_blocked = false;
    line->start_at_end = start_at_end;
    line->source_x = SQRT_3_2 * (float)source_x + SQRT_3_4;
    line->source_y = 0.5f + (float)source_y + 0.5f*(float)(source_x & 1);

    float dx = SQRT_3_2 * (float)(dest_x - source_x);
    float dy = (float)(dest_y - source_y) + (float)((dest_x - source_x) & 1) * (0.5f - (float)(source_x & 1));
    float adx = fabs(dx);
    float ady = fabs(dy);
    float start_slope, target_slope, end_slope;

    if (SQRT_3*ady - adx < GRID_EPSILON) {
        line->eps_x = 0.0f;
        start_slope = (dy - 0.5f) / adx;
        target_slope = dy / adx;
        end_slope = (dy + 0.5f) / adx;

        if (dx > GRID_EPSILON) {
            line->eps_y = GRID_EPSILON;
            line->step_x = SQRT_3_2;
            line->dest_t = dest_x - source_x;
            hex_los_sextant_e(&data, line, start_slope, target_slope, end_slope);
        } else {
            line->eps_y = -GRID_EPSILON;
            line->step_x = -SQRT_3_2;
            line->dest_t = source_x - dest_x;
            hex_los_sextant_w(&data, line, start_slope, target_slope, end_slope);
        }
    } else {
        line->dest_t = (int)(ady + INV_SQRT_3 * adx + 0.25f);
        start_slope = (adx - SQRT_3_4) / (ady + 0.25f);
        target_slope = adx / ady;
        end_slope = (adx + SQRT_3_4) / (ady - 0.25f);

        if (dx > GRID_EPSILON) {
            line->eps_y = GRID_EPSILON;
            if (dy > 0.0f) {
                line->eps_x = -GRID_EPSILON;
                hex_los_sextant_ne(&data, line, start_slope, target_slope, end_slope);
            } else {
                line->eps_x = GRID_EPSILON;
                hex_los_sextant_se(&data, line, start_slope, target_slope, end_slope);
            }
        } else {
            line->eps_y = -GRID_EPSILON;
            if (dy > 0.0f) {
                line->eps_x = -GRID_EPSILON;
                hex_los_sextant_nw(&data, line, start_slope, target_slope, end_slope);
            } else {
                line->eps_x = GRID_EPSILON;
                hex_los_sextant_sw(&data, line, start_slope, target_slope, end_slope);
            }

        }
    }

/* // simple linex
    if (SQRT_3*ady < adx) {
        if (dest_x > source_x) {
            line->step_x = SQRT_3_2;
            line->dest_t = dest_x - source_x;
            line->eps_y = GRID_EPSILON;
        } else {
            line->step_x = -SQRT_3_2;
            line->dest_t = source_x - dest_x;
            line->eps_y = -GRID_EPSILON;
        }
        line->eps_x = 0.0f;
        line->step_y = dy * line->step_x / dx;
    } else {
        line->dest_t = (int)(ady + INV_SQRT_3 * adx + 0.25f);
        line->step_x = dx / (float)line->dest_t;
        line->step_y = dy / (float)line->dest_t;
        line->eps_x = (dy < 0.0f) ? GRID_EPSILON : -GRID_EPSILON;
        line->eps_y = (dx > 0.0f) ? GRID_EPSILON : -GRID_EPSILON;
    }
    if (start_at_end) {
        line->t = line->dest_t;
    }
*/
}

void fov_create_los_line(fov_settings_type *settings, void *map, void *source, fov_line_data *line,
                         int source_x, int source_y,
                         int dest_x, int dest_y,
                         bool start_at_end) {

    line->source_x = source_x;
    line->source_y = source_y;
    line->t = 0;
    line->is_blocked = false;
    line->start_at_end = start_at_end;

    if (source_x == dest_x)
    {
        line->dest_t = abs(dest_y - source_y);
        line->eps = 0.0f;

        if (source_y == dest_y) {
            return;
        }
        /* iterate through all y */
        int dy = (dest_y < source_y) ? -1 : 1;
        int y = source_y;
        do {
            y += dy;
            if (settings->opaque(map, source_x, y)) {
                line->is_blocked = true;
                line->block_t = dy*(y - source_y);
                break;
            }
        } while (y != dest_y);

        line->step_x = 0.0f;
        line->step_y = (float)dy;
        if (start_at_end) {
            line->t = line->dest_t;
        }
    }
    else if (source_y == dest_y)
    {
        line->dest_t = abs(dest_x - source_x);
        line->eps = 0.0f;

        /* iterate through all x */
        int dx = (dest_x < source_x) ? -1 : 1;
        int x = source_x;
        do {
            x += dx;
            if (settings->opaque(map, x, source_y)) {
                line->is_blocked = true;
                line->block_t = dx*(x - source_x);
                break;
            }
        } while (x != dest_x);

        line->step_x = (float)dx;
        line->step_y = 0.0f;
        if (start_at_end) {
            line->t = line->dest_t;
        }
    }
    else
    {
        /* hurray for a plethora of short but similar variable names!  (yeah, I'm sorry... I blame all the poorly written legacy physics code I've had to work with) */
        bool b0;                       /* true if [xy]0 is blocked */
        bool b1;                       /* true if [xy]1 is blocked */
        bool mb0;                      /* true if m[xy]0 is blocked */
        bool mb1;                      /* true if m[xy]1 is blocked */
        bool blocked_below = false;    /* true if lower_slope is bounded by an obstruction */
        bool blocked_above = false;    /* true if upper_slope is bounded by an obstruction */
        int sx = source_x;             /* source x */
        int sy = source_y;             /* source y */
        int tx = dest_x;               /* target x */
        int ty = dest_y;               /* target y */
        int dx = (tx < sx) ? -1 : 1;   /* sign of x.  Useful for taking abs(x_val) */
        int dy = (ty < sy) ? -1 : 1;   /* sign of y.  Useful for taking abs(y_val) */

        float gx = (float)dx;          /* sign of x, float.  Useful for taking fabs(x_val) */
        float gy = (float)dy;          /* sign of y, float   Useful for taking fabs(y_val) */
        float gabs = (float)(dx*dy);   /* used in place of fabs(slope_val) */
        float val, val2;

        /* Note that multiplying by dx, dy, gx, gy, or gabs are sometimes used in place of abs and fabs */
        /* I don't mind having a little (x2) code duplication--it's much better than debugging large macros :) */
        if (dx*(tx - sx) > dy*(ty - sy))
        {
            line->dest_t = dx*(tx - sx);

            int x = 0;
            int y0, y1;                /* lowest/highest possible y based on inner/outer edge of tiles and lower/upper slopes */
            int my0, my1;              /* low/high y based on the middle of tiles */
            float slope = ((float)(ty - sy)) / ((float)(tx - sx));
            float lower_slope = ((float)(ty - sy) - gy*0.5f) / ((float)(tx - sx));
            float upper_slope = ((float)(ty - sy) + gy*0.5f) / ((float)(tx - sx));
            float lower_slope_prev = lower_slope;
            float upper_slope_prev = upper_slope;

            /* include both source and dest x in loop, but don't include (source_x, source_y) or (target_x, target_y) */
            val = gx*0.5f*upper_slope + gx*GRID_EPSILON;
            y1 = (val < 0.0f) ? -(int)(0.5f - val) : (int)(0.5f + val); 
            if (y1 != 0 && gabs * upper_slope > 1.0f && settings->permissiveness > 0.199f && settings->opaque(map, sx, sy + y1)) {
                val = (gy*0.5f) / (gx*settings->permissiveness);
                if (gabs * val < gabs * upper_slope) {
                    upper_slope_prev = upper_slope;
                    upper_slope = val;
                    blocked_above = true;
                }
            }

            while (sx + x != tx) {
                x += dx;
                b0 = false;
                b1 = false;
                mb0 = false;
                mb1 = false;

                /* Just in case floating point precision errors do try to show up (i.e., really long line or very unlucky),
                 * let us calculate values in the same manner as done for FoV to make the errors consistent */
                if (blocked_below && blocked_above && gabs*(upper_slope - lower_slope) < GRID_EPSILON) {
                    val  = (float)x*lower_slope - gy*GRID_EPSILON;
                    val2 = (float)x*upper_slope - gy*GRID_EPSILON;
                } else {
                    val  = (blocked_below) ? (float)x*lower_slope + gy*GRID_EPSILON : (float)x*lower_slope - gy*GRID_EPSILON;
                    val2 = (blocked_above) ? (float)x*upper_slope - gy*GRID_EPSILON : (float)x*upper_slope + gy*GRID_EPSILON;
                }
                my0 = (val < 0.0f) ? -(int)(0.5f - val) : (int)(0.5f + val);
                val -= gx*0.5f*lower_slope;
                y0  = (val < 0.0f) ? -(int)(0.5f - val) : (int)(0.5f + val);

                my1 = (val2 < 0.0f) ? -(int)(0.5f - val2) : (int)(0.5f + val2);
                val2 += gx*0.5f*upper_slope;
                y1  = (val2 < 0.0f) ? -(int)(0.5f - val2) : (int)(0.5f + val2);

                /* check if lower_slope is blocked */
                if (settings->opaque(map, sx + x, sy + my0)) {
                    b0 = true;
                    mb0 = true;
                    lower_slope_prev = lower_slope;
                    lower_slope = ((float)my0 + gy*0.5f) / ((float)x - gx*settings->permissiveness);
                    blocked_below = true;
                }
                else if (y0 != my0 && settings->opaque(map, sx + x, sy + y0)) {
                    val = ((float)y0 + gy*0.5f) / ((float)x - gx*settings->permissiveness);
                    if (gabs * val > gabs * lower_slope) {
                        b0 = true;
                        lower_slope_prev = lower_slope;
                        lower_slope = val;
                        blocked_below = true;
                    }
                }

                /* check if upper_slope is blocked */
                if (sx + x != tx) {
                    if (settings->opaque(map, sx + x, sy + my1)) {
                        b1 = true;
                        mb1 = true;
                        upper_slope_prev = upper_slope;
                        upper_slope = ((float)my1 - gy*0.5f) / ((float)x + gx*settings->permissiveness);
                        blocked_above = true;
                    }
                    else if (y1 != my1 && settings->opaque(map, sx + x, sy + y1)) {
                        val = ((float)y1 - gy*0.5f) / ((float)x + gx*settings->permissiveness);
                        if (gabs * val < gabs * upper_slope) {
                            b1 = true;
                            upper_slope_prev = upper_slope;
                            upper_slope = val;
                            blocked_above = true;
                        }
                    }
                }

                /* being "pinched" isn't blocked, because one can still look diagonally */
                if (mb0 && b1 || b0 && mb1 ||
                        gabs * (lower_slope - upper_slope) > GRID_EPSILON ||
                        gy*((float)(sy - ty) + (float)(tx - sx)*lower_slope - gy*0.5f) > -GRID_EPSILON ||
                        gy*((float)(sy - ty) + (float)(tx - sx)*upper_slope + gy*0.5f) <  GRID_EPSILON)
                {
                    line->is_blocked = true;
                    line->block_t = dx*x;
                    break;
                }
            }

            /* if blocked, still try to make a "smartest line" that goes the farthest before becoming blocked */
            line->step_x = gx;
            line->eps = gy * GRID_EPSILON;
            if (line->is_blocked) {
                lower_slope = lower_slope_prev;
                upper_slope = upper_slope_prev;
            }
            if (fabs(upper_slope - lower_slope) < GRID_EPSILON) {
                line->step_y = 0.5f * gx * (lower_slope + upper_slope);
            } else if (gabs * (slope - lower_slope) < GRID_EPSILON && 0.5f - fabs((float)(sy - ty) + (float)x*lower_slope) > GRID_EPSILON) {
                line->step_y = gx * lower_slope;
                line->eps = -gy * GRID_EPSILON;
            } else if (gabs * (upper_slope - slope) < GRID_EPSILON && 0.5f - fabs((float)(sy - ty) + (float)x*upper_slope) > GRID_EPSILON) {
                line->step_y = gx * upper_slope;
            } else {
                line->step_y = gx * slope;
            }
            if (start_at_end) {
                line->t = dx*(tx - sx);
            }
        }
        else
        {
            line->dest_t = dy*(ty - sy);

            int y = 0;
            int x0, x1;                /* lowest/highest possible x based on inner/outer edge of tiles and lower/upper slopes */
            int mx0, mx1;              /* low/high x based on the middle of tiles */
            float slope = ((float)(tx - sx)) / ((float)(ty - sy));
            float lower_slope = ((float)(tx - sx) - gx*0.5f) / ((float)(ty - sy));
            float upper_slope = ((float)(tx - sx) + gx*0.5f) / ((float)(ty - sy));
            float lower_slope_prev = lower_slope;
            float upper_slope_prev = upper_slope;

            /* include both source and dest y in loop, but don't include (source_x, source_y) or (target_x, target_y) */
            val = gy*0.5f*upper_slope + gy*GRID_EPSILON;
            x1 = (val < 0.0f) ? -(int)(0.5f - val) : (int)(0.5f + val); 
            if (x1 != 0 && gabs * upper_slope > 1.0f && settings->permissiveness > 0.199f && settings->opaque(map, sx + x1, sy)) {
                val = (gx*0.5f) / (gy*settings->permissiveness);
                if (gabs * val < gabs * upper_slope) {
                    upper_slope_prev = upper_slope;
                    upper_slope = val;
                    blocked_above = true;
                }
            }

            while (sy + y != ty) {
                y += dy;
                b0 = false;
                b1 = false;
                mb0 = false;
                mb1 = false;

                /* Just in case floating point precision errors do try to show up (i.e., really long line or very unlucky),
                 * let us calculate values in the same manner as done for FoV to make the errors consistent */
                if (blocked_below && blocked_above && gabs*(upper_slope - lower_slope) < GRID_EPSILON) {
                    val  = (float)y*lower_slope - gx*GRID_EPSILON;
                    val2 = (float)y*upper_slope - gx*GRID_EPSILON;
                } else {
                    val  = (blocked_below) ? (float)y*lower_slope + gx*GRID_EPSILON : (float)y*lower_slope - gx*GRID_EPSILON;
                    val2 = (blocked_above) ? (float)y*upper_slope - gx*GRID_EPSILON : (float)y*upper_slope + gx*GRID_EPSILON;
                }
                mx0 = (val < 0.0f) ? -(int)(0.5f - val) : (int)(0.5f + val);
                val -= gy*0.5f*lower_slope;
                x0  = (val < 0.0f) ? -(int)(0.5f - val) : (int)(0.5f + val);

                mx1 = (val2 < 0.0f) ? -(int)(0.5f - val2) : (int)(0.5f + val2);
                val2 += gy*0.5f*upper_slope;
                x1  = (val2 < 0.0f) ? -(int)(0.5f - val2) : (int)(0.5f + val2);

                /* check if lower_slope is blocked */
                if (settings->opaque(map, sx + mx0, sy + y)) {
                    b0 = true;
                    mb0 = true;
                    lower_slope_prev = lower_slope;
                    lower_slope = ((float)mx0 + gx*0.5f) / ((float)y - gy*settings->permissiveness);
                    blocked_below = true;
                }
                else if (x0 != mx0 && settings->opaque(map, sx + x0, sy + y)) {
                    val = ((float)x0 + gx*0.5f) / ((float)y - gy*settings->permissiveness);
                    if (gabs * val > gabs * lower_slope) {
                        b0 = true;
                        lower_slope_prev = lower_slope;
                        lower_slope = val;
                        blocked_below = true;
                    }
                }

                /* check if upper_slope is blocked */
                if (sy + y != ty) {
                    if (settings->opaque(map, sx + mx1, sy + y)) {
                        b1 = true;
                        mb1 = true;
                        upper_slope_prev = upper_slope;
                        upper_slope = ((float)mx1 - gx*0.5f) / ((float)y + gy*settings->permissiveness);
                        blocked_above = true;
                    }
                    else if (x1 != mx1 && settings->opaque(map, sx + x1, sy + y)) {
                        val = ((float)x1 - gx*0.5f) / ((float)y + gy*settings->permissiveness);
                        if (gabs * val < gabs * upper_slope) {
                            b1 = true;
                            upper_slope_prev = upper_slope;
                            upper_slope = val;
                            blocked_above = true;
                        }
                    }
                }

                /* being "pinched" isn't blocked, because one can still look diagonally */
                if (mb0 && b1 || b0 && mb1 ||
                        gabs * (lower_slope - upper_slope) > GRID_EPSILON ||
                        gx*((float)(sx - tx) + (float)(ty - sy)*lower_slope - gx*0.5f) > -GRID_EPSILON ||
                        gx*((float)(sx - tx) + (float)(ty - sy)*upper_slope + gx*0.5f) <  GRID_EPSILON)
                {
                    line->is_blocked = true;
                    line->block_t = dy*y;
                    break;
                }
            }

            /* if blocked, still try to make a "smartest line" that goes the farthest before becoming blocked */
            line->step_y = gy;
            line->eps = gx * GRID_EPSILON;
            if (line->is_blocked) {
                lower_slope = lower_slope_prev;
                upper_slope = upper_slope_prev;
            }
            if (fabs(upper_slope - lower_slope) < GRID_EPSILON) {
                line->step_x = 0.5f * gy * (lower_slope + upper_slope);
            } else if (gabs * (slope - lower_slope) < GRID_EPSILON && 0.5f - fabs((float)(sx - tx) + (float)y*lower_slope) > GRID_EPSILON) {
                line->step_x = gy * lower_slope;
                line->eps = -gx * GRID_EPSILON;
            } else if (gabs * (upper_slope - slope) < GRID_EPSILON && 0.5f - fabs((float)(sx - tx) + (float)y*upper_slope) > GRID_EPSILON) {
                line->step_x = gy * upper_slope;
            } else {
                line->step_x = gy * slope;
            }
            if (start_at_end) {
                line->t = dy*(ty - sy);
            }
        }
    }

    if (start_at_end && line->is_blocked) {
        line->t = line->block_t;
    }
}

