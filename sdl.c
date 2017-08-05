#ifndef DEBUG
#define DEBUG 1
#endif
#define debug_log(fmt, ...) do { if (DEBUG) fprintf(stderr, "%s:%d " fmt, __FILE__, __LINE__, ##__VA_ARGS__); } while (0)

#define SDL_MAIN_HANDLED
#include "SDL.h"

#include <SWI-Stream.h>
#include <SWI-Prolog.h>
#include <stdio.h>

PL_blob_t sdl_blob;


const int KIND_WINDOW = 0;
const int KIND_RENDERER = 1;

const char *KIND_NAMES[] = {
    "WINDOW",
    "RENDERER",
};

typedef int object_kind;

typedef struct {
    object_kind kind;
    ssize_t refs;
    void *object;
} sdl_object;



functor_t rgba_f;


void initialize_terms() {
    rgba_f = PL_new_functor(PL_new_atom("rgba"), 4);
}


sdl_object *object_create(term_t term, object_kind kind, void *value) {
    if (!PL_is_variable(term)) {
        debug_log("term not a variable");
        return NULL;
    }
    size_t size = sizeof(sdl_object);
    sdl_object *object = malloc(size);
    if (object == NULL) {
        return NULL;
    }
    object->kind = kind;
    object->refs = 1;
    object->object = value;
    PL_unify_blob(term, object, size, &sdl_blob);
    return object;
}

sdl_object *object_read(term_t term, object_kind kind) {
    size_t len;
    PL_blob_t *type;
    sdl_object *object;
    if (!PL_get_blob(term, (void **)&object, &len, &type)) {
        printf("Unable to read object of %s\n", KIND_NAMES[kind]);
        return NULL;
    }
    if (object->kind != kind) {
        printf("Expected blob %s, but got a %s\n", KIND_NAMES[kind], KIND_NAMES[object->kind]);
        return NULL;
    }
    return object;
}

int sdl_blob_release(term_t term) {
    size_t len;
    PL_blob_t *type;
    sdl_object *object = PL_blob_data(term, &len, &type);
    object->refs -= 1;
    if (object->refs == 0) {
        switch (object->kind) {
            case KIND_WINDOW:
                SDL_DestroyWindow((SDL_Window *)object->object);
                break;
            case KIND_RENDERER:
                SDL_DestroyRenderer((SDL_Renderer *)object->object);
                break;
            default:
                break;
        }
        free(object);
    }
    return TRUE;
}

int sdl_blob_write(IOSTREAM *s, term_t term, int flags) {
    size_t len;
    PL_blob_t *type;
    sdl_object *object = PL_blob_data(term, &len, &type);
    size_t bufflen = snprintf(NULL, 0, "sdl_object:%s:%p", KIND_NAMES[object->kind], (void *)object);
    char *string = malloc(bufflen);
    snprintf(string, bufflen, "sdl_object:%s:%p", KIND_NAMES[object->kind], (void *)object);
    Sfputs(string, s);
    free(string);
    return TRUE;
}

void sdl_blob_acquire(term_t term) {
    size_t len;
    PL_blob_t *type;
    sdl_object *object = PL_blob_data(term, &len, &type);
    object->refs += 1;
}

static foreign_t pl_sdl_init(term_t subsystems) {
    if (PL_skip_list(subsystems, 0, NULL) != PL_LIST) {
        return FALSE;
    }
    term_t head = PL_new_term_ref();
    term_t tail = PL_copy_term_ref(subsystems);
    Uint32 flags = 0;
    while (PL_get_list(tail, head, tail)) {
        char *atom;
        if (!PL_get_atom_chars(head, &atom)) { return FALSE; }
        else if (0 == strcmp("video",          atom)) { flags |= SDL_INIT_VIDEO; }
        else if (0 == strcmp("audio",          atom)) { flags |= SDL_INIT_AUDIO; }
        else if (0 == strcmp("timer",          atom)) { flags |= SDL_INIT_TIMER; }
        else if (0 == strcmp("joystick",       atom)) { flags |= SDL_INIT_JOYSTICK; }
        else if (0 == strcmp("haptic",         atom)) { flags |= SDL_INIT_HAPTIC; }
        else if (0 == strcmp("gamecontroller", atom)) { flags |= SDL_INIT_GAMECONTROLLER; }
        else if (0 == strcmp("haptic",         atom)) { flags |= SDL_INIT_HAPTIC; }
        else if (0 == strcmp("events",         atom)) { flags |= SDL_INIT_EVENTS; }
        else if (0 == strcmp("everything",     atom)) { flags |= SDL_INIT_EVERYTHING; }
    }
    printf("SDL_SetMainReady()\n");
    SDL_SetMainReady();
    printf("SDL_Init(%d)\n", flags);
    if (SDL_Init(flags) != 0) {
        return FALSE;
    }
    return TRUE;
}

static foreign_t pl_sdl_create_window(term_t title, term_t width, term_t height, term_t flags, term_t handle) {
    int w;
    int h;
    char *t;
    size_t len; 
    if (!(PL_get_integer(width, &w) && PL_get_integer(height, &h) && PL_get_string_chars(title, &t, &len))) {
        return FALSE;
    }
    if (PL_skip_list(flags, 0, NULL) != PL_LIST) {
        return FALSE;
    }
    term_t head = PL_new_term_ref();
    term_t tail = PL_copy_term_ref(flags);
    Uint32 uflags = 0;
    while (PL_get_list(tail, head, tail)) {
        char *name;
        if (!PL_get_atom_chars(head, &name)) { return FALSE; }
        else if (0 == strcmp(name, "fullscreen")) { uflags |= SDL_WINDOW_FULLSCREEN; }
        else if (0 == strcmp(name, "fullscreen_desktop")) { uflags |= SDL_WINDOW_FULLSCREEN_DESKTOP; }
        else if (0 == strcmp(name, "opengl")) { uflags |= SDL_WINDOW_OPENGL; }
        else if (0 == strcmp(name, "hidden")) { uflags |= SDL_WINDOW_HIDDEN; }
        else if (0 == strcmp(name, "borderless")) { uflags |= SDL_WINDOW_BORDERLESS; }
        else if (0 == strcmp(name, "resizable")) { uflags |= SDL_WINDOW_RESIZABLE; }
        else if (0 == strcmp(name, "minimized")) { uflags |= SDL_WINDOW_MINIMIZED; }
        else if (0 == strcmp(name, "maximized")) { uflags |= SDL_WINDOW_MAXIMIZED; }
        else if (0 == strcmp(name, "input_grabbed")) { uflags |= SDL_WINDOW_INPUT_GRABBED; }
        else if (0 == strcmp(name, "allow_highdpi")) { uflags |= SDL_WINDOW_ALLOW_HIGHDPI; }
    }
    printf("SDL_CreateWindow(%s, %d, %d, %d, %d, %d)\n", t, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, w, h, uflags);
    SDL_Window *window = SDL_CreateWindow(t, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, w, h, uflags);
    if (!window) {
        return FALSE;
    }
    if (NULL == object_create(handle, KIND_WINDOW, window)) {
        return FALSE;
    }
    return TRUE;
}

static foreign_t pl_sdl_destroy_window(term_t window) {
    sdl_object *obj = object_read(window, KIND_WINDOW);
    if (obj == NULL) {
        return FALSE;
    }
    SDL_DestroyRenderer(obj->object);
    return TRUE;
}

static foreign_t pl_sdl_create_renderer(term_t window, term_t flags, term_t handle) {
    sdl_object *winobj = object_read(window, KIND_WINDOW);
    if (winobj == NULL) {
        printf("NOT A WINDOW\n");
        return FALSE;
    }
    if (PL_skip_list(flags, 0, NULL) != PL_LIST) {
        return FALSE;
    }
    term_t head = PL_new_term_ref();
    term_t tail = PL_copy_term_ref(flags);
    Uint32 uflags = 0;
    while (PL_get_list(tail, head, tail)) {
        char *name;
        if (!PL_get_atom_chars(head, &name)) { return FALSE; }
        else if (0 == strcmp(name, "software")) { uflags |= SDL_RENDERER_SOFTWARE; }
        else if (0 == strcmp(name, "accelerated")) { uflags |= SDL_RENDERER_ACCELERATED; }
        else if (0 == strcmp(name, "presentvsync")) { uflags |= SDL_RENDERER_PRESENTVSYNC; }
        else if (0 == strcmp(name, "targettexture")) { uflags |= SDL_RENDERER_TARGETTEXTURE; }
    }
    SDL_Window *win = (SDL_Window *)(winobj->object);
    printf("SDL_CreateRenderer(%p, %d, %d)\n", win, -1, uflags);
    SDL_Renderer *renderer = SDL_CreateRenderer(win, -1, uflags);
    if (!renderer) {
        return FALSE;
    }
    if (NULL == object_create(handle, KIND_RENDERER, renderer)) {
        return FALSE;
    }
    return TRUE;
}

static foreign_t pl_sdl_destroy_renderer(term_t renderer) {
    sdl_object *obj = object_read(renderer, KIND_RENDERER);
    if (obj == NULL) {
        return FALSE;
    }
    SDL_DestroyRenderer(obj->object);
    return TRUE;
}

static foreign_t pl_sdl_render_color(term_t renderer, term_t color) {
    sdl_object *renderobj = object_read(renderer, KIND_RENDERER);
    if (renderobj == NULL) {
        return FALSE;
    }
    Uint8 cval[4];
    if (0 != SDL_GetRenderDrawColor(renderobj->object, &cval[0], &cval[1], &cval[2], &cval[3])) {
        debug_log("GetRenderDrawColor failed: %s\n", SDL_GetError());
        /* TODO: raise exception? */
        return FALSE;
    }
    term_t rgba = PL_new_term_ref();
    if (!PL_put_functor(rgba, rgba_f)) {
        return FALSE;
    }
    fid_t fid = PL_open_foreign_frame();
    int result = PL_unify(color, rgba);
    if (!result) {
        debug_log("PL_unify rgba, color failed");
        PL_rewind_foreign_frame(fid);
        return FALSE;
    }
    int any_read = 0;
    for (int i = 0; i < 4; ++i) {
        long tmp;
        term_t colorterm = PL_new_term_ref();
        if (!PL_get_arg(1 + i, color, colorterm)) {
            debug_log("Get rgba component %d failed", i);
            PL_rewind_foreign_frame(fid);
            return FALSE;
        }
        if (PL_is_variable(colorterm)) {
            any_read = 1;
            if (!PL_put_integer(colorterm, (long)cval[i])) {
                debug_log("Put rgba component %d failed", i);
                PL_rewind_foreign_frame(fid);
                return FALSE;
            }
        } else if (PL_is_integer(colorterm) && PL_get_long(colorterm, &tmp)) {
            cval[i] = tmp;
        } else {
            debug_log("Unexpected rgba component term type: %d", PL_term_type(colorterm));
            PL_rewind_foreign_frame(fid);
            return FALSE;
        }
    }
    SDL_SetRenderDrawColor(renderobj->object, cval[0], cval[1], cval[2], cval[3]);
    if (any_read) {
        if (!PL_unify_term(color, PL_FUNCTOR, rgba_f, PL_INT, (int)cval[0], PL_INT, (int)cval[1], PL_INT, (int)cval[2], PL_INT, (int)cval[3])) {
            debug_log("Could not re-unify rgba component?");
            PL_rewind_foreign_frame(fid);
            return FALSE;
        }
    }
    PL_close_foreign_frame(fid);
    return TRUE;
}

static foreign_t pl_sdl_render_clear(term_t renderer) {
    sdl_object *obj = object_read(renderer, KIND_RENDERER);
    if (obj == NULL) {
        return FALSE;
    }
    if (0 != SDL_RenderClear(obj->object)) {
        /* TODO exception */
        return FALSE;
    }
    return TRUE;
}

static foreign_t pl_sdl_render_present(term_t renderer) {
    sdl_object *obj = object_read(renderer, KIND_RENDERER);
    if (obj == NULL) {
        return FALSE;
    }
    SDL_RenderPresent(obj->object);
    return TRUE;
}

/*
static foreign_t pl_sdl_draw(term_t renderer, term_t color) {
    draw(render, line(pt(X1, Y1), pt(X2, Y2))),
    draw(render, rect(pt(X, Y), dim(W, H))),
}
*/

static foreign_t pl_sdl_terminate() {
    SDL_VideoQuit(); /* TODO: connect to initialization somehow? */
    SDL_Quit();
    return TRUE;
}

install_t install_sdl() {
    sdl_blob.magic = PL_BLOB_MAGIC;
    sdl_blob.flags = PL_BLOB_NOCOPY;
    sdl_blob.name = "sdl_object";
    sdl_blob.release = sdl_blob_release;
    sdl_blob.compare = NULL;
    sdl_blob.write = sdl_blob_write;
    sdl_blob.acquire = sdl_blob_acquire;

    initialize_terms();

    PL_register_foreign("sdl_init", 1, pl_sdl_init, 0);
    PL_register_foreign("sdl_create_window", 5, pl_sdl_create_window, 0);
    PL_register_foreign("sdl_destroy_window", 1, pl_sdl_destroy_window, 0);
    PL_register_foreign("sdl_create_renderer", 3, pl_sdl_create_renderer, 0);
    PL_register_foreign("sdl_destroy_renderer", 1, pl_sdl_destroy_renderer, 0);
    PL_register_foreign("sdl_render_color", 2, pl_sdl_render_color, 0);
    PL_register_foreign("sdl_render_clear", 1, pl_sdl_render_clear, 0);
    PL_register_foreign("sdl_render_present", 1, pl_sdl_render_present, 0);
    PL_register_foreign("sdl_terminate", 0, pl_sdl_terminate, 0);
}
