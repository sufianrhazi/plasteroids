#ifndef DEBUG
#define DEBUG 1
#endif
#define debug_log(fmt, ...) do { if (DEBUG) fprintf(stderr, "%s:%d " fmt, __FILE__, __LINE__, ##__VA_ARGS__); } while (0)

#define max(a,b) \
    ({ \
         __typeof__ (a) _a = (a); \
         __typeof__ (b) _b = (b); \
         _a > _b ? _a : _b; \
     })

#define min(a,b) \
    ({ \
         __typeof__ (a) _a = (a); \
         __typeof__ (b) _b = (b); \
         _a < _b ? _a : _b; \
     })

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


/* color/settings */
functor_t rgba_f;
/* draw functors */
functor_t pt_f;
functor_t line_f;
functor_t rect_f;
functor_t fill_f;
/* event functors */
functor_t window_f;
functor_t key_f;
functor_t mouse_position_f;


void initialize_terms() {
    rgba_f = PL_new_functor(PL_new_atom("rgba"), 4);
    pt_f = PL_new_functor(PL_new_atom("pt"), 2);
    line_f = PL_new_functor(PL_new_atom("line"), 2);
    rect_f = PL_new_functor(PL_new_atom("rect"), 2);
    fill_f = PL_new_functor(PL_new_atom("fill"), 1);
    key_f = PL_new_functor(PL_new_atom("key"), 3);
    window_f = PL_new_functor(PL_new_atom("window"), 1);
    mouse_position_f = PL_new_functor(PL_new_atom("mouse_position"), 2);
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
        debug_log("Unable to read object of %s\n", KIND_NAMES[kind]);
        return NULL;
    }
    if (object->kind != kind) {
        debug_log("Expected blob %s, but got a %s\n", KIND_NAMES[kind], KIND_NAMES[object->kind]);
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
    debug_log("SDL_SetMainReady()\n");
    SDL_SetMainReady();
    debug_log("SDL_Init(%d)\n", flags);
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
    debug_log("SDL_CreateWindow(%s, %d, %d, %d, %d, %d)\n", t, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, w, h, uflags);
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
        debug_log("NOT A WINDOW\n");
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
    debug_log("SDL_CreateRenderer(%p, %d, %d)\n", win, -1, uflags);
    SDL_Renderer *renderer = SDL_CreateRenderer(win, -1, uflags);
    if (!renderer) {
        return FALSE;
    }
    if (NULL == object_create(handle, KIND_RENDERER, renderer)) {
        return FALSE;
    }
    return TRUE;
}

static foreign_t pl_sdl_render_blendmode(term_t renderer, term_t blendmode) {
    sdl_object *rendobj = object_read(renderer, KIND_RENDERER);
    if (rendobj == NULL) {
        debug_log("NOT A RENDERER\n");
        return FALSE;
    }
    SDL_BlendMode mode;
    if (PL_is_variable(blendmode)) {
        if (SDL_GetRenderDrawBlendMode(rendobj->object, &mode)) { return FALSE; }
        else if (mode == SDL_BLENDMODE_NONE) { return PL_unify_atom_chars(blendmode, "none"); }
        else if (mode == SDL_BLENDMODE_BLEND) { return PL_unify_atom_chars(blendmode, "alpha"); }
        else if (mode == SDL_BLENDMODE_ADD) { return PL_unify_atom_chars(blendmode, "additive"); }
        else if (mode == SDL_BLENDMODE_MOD) { return PL_unify_atom_chars(blendmode, "modulate"); }
        else { return FALSE; }
    } else if (PL_is_atom(blendmode)) {
        char *name;
        if (!PL_get_atom_chars(blendmode, &name)) { return FALSE; }
        else if (0 == strcmp(name, "none")) { mode = SDL_BLENDMODE_NONE; }
        else if (0 == strcmp(name, "alpha")) { mode = SDL_BLENDMODE_BLEND; }
        else if (0 == strcmp(name, "additive")) { mode = SDL_BLENDMODE_ADD; }
        else if (0 == strcmp(name, "modulate")) { mode = SDL_BLENDMODE_MOD; }
        else { return FALSE; }
        if (SDL_SetRenderDrawBlendMode(rendobj->object, mode)) {
            return FALSE;
        }
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
        goto error;
    }
    int any_read = 0;
    for (int i = 0; i < 4; ++i) {
        long tmp;
        term_t colorterm = PL_new_term_ref();
        if (!PL_get_arg(1 + i, color, colorterm)) {
            debug_log("Get rgba component %d failed", i);
            goto error;
        }
        if (PL_is_variable(colorterm)) {
            any_read = 1;
            if (!PL_put_integer(colorterm, (long)cval[i])) {
                debug_log("Put rgba component %d failed", i);
                goto error;
            }
        } else if (PL_is_integer(colorterm) && PL_get_long(colorterm, &tmp)) {
            cval[i] = tmp;
        } else {
            debug_log("Unexpected rgba component term type: %d", PL_term_type(colorterm));
            goto error;
        }
    }
    if (SDL_SetRenderDrawColor(renderobj->object, cval[0], cval[1], cval[2], cval[3])) {
        debug_log("Failed to set draw color: %s\n", SDL_GetError());
    }
    if (any_read) {
        if (!PL_unify_term(color, PL_FUNCTOR, rgba_f, PL_INT, (int)cval[0], PL_INT, (int)cval[1], PL_INT, (int)cval[2], PL_INT, (int)cval[3])) {
            debug_log("Could not re-unify rgba component?");
            goto error;
        }
    }
    PL_close_foreign_frame(fid);
    return TRUE;
error:
    PL_rewind_foreign_frame(fid);
    return FALSE;
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
        debug_log("Renderer is null?\n");
        return FALSE;
    }
    SDL_RenderPresent(obj->object);
    return TRUE;
}

int get_point(term_t term, SDL_Point *point) {
    term_t pt = PL_new_term_ref();
    if (!PL_put_functor(pt, pt_f)) return FALSE;
    fid_t fid = PL_open_foreign_frame();
    if (!PL_unify(term, pt)) goto fail;
    term_t xterm = PL_new_term_ref();
    long x;
    if (!PL_get_arg(1, pt, xterm)) goto fail;
    if (!PL_get_long(xterm, &x)) goto fail;
    term_t yterm = PL_new_term_ref();
    long y;
    if (!PL_get_arg(2, pt, yterm)) goto fail;
    if (!PL_get_long(yterm, &y)) goto fail;
    point->x = x;
    point->y = y;
    PL_close_foreign_frame(fid);
    return TRUE;
fail:
    PL_rewind_foreign_frame(fid);
    return FALSE;
}

int get_line(term_t term, SDL_Point *a, SDL_Point *b) {
    term_t line = PL_new_term_ref();
    if (!PL_put_functor(line, line_f)) return FALSE;
    fid_t fid = PL_open_foreign_frame();
    if (!PL_unify(term, line)) goto fail;
    term_t aterm = PL_new_term_ref();
    if (!PL_get_arg(1, line, aterm)) goto fail;
    if (!get_point(aterm, a)) goto fail;
    term_t bterm = PL_new_term_ref();
    if (!PL_get_arg(2, line, bterm)) goto fail;
    if (!get_point(bterm, b)) goto fail;
    PL_close_foreign_frame(fid);
    return TRUE;
fail:
    PL_rewind_foreign_frame(fid);
    return FALSE;
}

int get_rect(term_t term, SDL_Rect *r) {
    SDL_Point a;
    SDL_Point b;
    term_t rect = PL_new_term_ref();
    if (!PL_put_functor(rect, rect_f)) return FALSE;
    fid_t fid = PL_open_foreign_frame();
    if (!PL_unify(term, rect)) goto fail;
    term_t aterm = PL_new_term_ref();
    if (!PL_get_arg(1, rect, aterm)) goto fail;
    if (!get_point(aterm, &a)) goto fail;
    term_t bterm = PL_new_term_ref();
    if (!PL_get_arg(2, rect, bterm)) goto fail;
    if (!get_point(bterm, &b)) goto fail;
    r->x = min(a.x, b.x);
    r->y = min(a.y, a.y);
    r->w = abs(b.x - a.x);
    r->h = abs(b.y - a.y);
    PL_close_foreign_frame(fid);
    return TRUE;
fail:
    PL_rewind_foreign_frame(fid);
    return FALSE;
}

int get_fill_rect(term_t term, SDL_Rect *rect) {
    term_t fill = PL_new_term_ref();
    if (!PL_put_functor(fill, fill_f)) return FALSE;
    fid_t fid = PL_open_foreign_frame();
    if (!PL_unify(term, fill)) goto fail;
    term_t val = PL_new_term_ref();
    if (!PL_get_arg(1, fill, val)) goto fail;
    if (!get_rect(val, rect)) goto fail;
    PL_close_foreign_frame(fid);
    return TRUE;
fail:
    PL_rewind_foreign_frame(fid);
    return FALSE;
}

static foreign_t pl_sdl_draw(term_t renderer, term_t shape) {
    sdl_object *robj = object_read(renderer, KIND_RENDERER);
    if (robj == NULL) {
        debug_log("renderer not a renderer\n");
        return FALSE;
    }
    SDL_Point a;
    SDL_Point b;
    SDL_Rect r;
    if (get_point(shape, &a)) {
        if (SDL_RenderDrawPoint(robj->object, a.x, a.y)) {
            debug_log("Could not draw point: %s\n", SDL_GetError());
        }
    } else if (get_line(shape, &a, &b)) {
        if (SDL_RenderDrawLine(robj->object, a.x, a.y, b.x, b.y)) {
            debug_log("Could not draw line: %s\n", SDL_GetError());
        }
    } else if (get_rect(shape, &r)) {
        if (SDL_RenderDrawRect(robj->object, &r)) {
            debug_log("Draw rect failed: %s\n", SDL_GetError());
        }
    } else if (get_fill_rect(shape, &r)) {
        if (SDL_RenderFillRect(robj->object, &r)) {
            debug_log("Draw fill rect failed: %s\n", SDL_GetError());
        }
    } else {
        debug_log("No match\n");
        return FALSE;
    }
    return TRUE;
}

static foreign_t pl_sdl_wait_event(term_t term, term_t timeout_term) {
    int ms;
    if (!PL_get_integer(timeout_term, &ms)) {
        return FALSE;
    }
    SDL_Event event;
    if (!SDL_WaitEventTimeout(&event, ms)) {
        return PL_unify_atom_chars(term, "timeout");
    }
    switch (event.type) {
        /* Application events */
        case SDL_QUIT:
            /**< User-requested quit */
            return PL_unify_atom_chars(term, "quit");

        /* iOS events */
        case SDL_APP_TERMINATING:
            /**< The application is being terminated by the OS
              Called on iOS in applicationWillTerminate()
              Called on Android in onDestroy()
              */
            break;
        case SDL_APP_LOWMEMORY:
            /**< The application is low on memory, free memory if possible.
              Called on iOS in applicationDidReceiveMemoryWarning()
              Called on Android in onLowMemory()
              */
            break;
        case SDL_APP_WILLENTERBACKGROUND:
            /**< The application is about to enter the background
              Called on iOS in applicationWillResignActive()
              Called on Android in onPause()
              */
            break;
        case SDL_APP_DIDENTERBACKGROUND:
            /**< The application did enter the background and may not get CPU for some time
              Called on iOS in applicationDidEnterBackground()
              Called on Android in onPause()
              */
            break;
        case SDL_APP_WILLENTERFOREGROUND:
            /**< The application is about to enter the foreground
              Called on iOS in applicationWillEnterForeground()
              Called on Android in onResume()
              */
            break;
        case SDL_APP_DIDENTERFOREGROUND:
            /**< The application is now interactive
              Called on iOS in applicationDidBecomeActive()
              Called on Android in onResume()
              */
            break;

        /* Window events */
        case SDL_WINDOWEVENT:
            /* SDL_Window *win = SDL_GetWindowFromID(event.window.windowID); */
            /* TODO: add which window, additional data */
            switch (event.window.event) {
                case SDL_WINDOWEVENT_SHOWN:          /**< Window has been shown */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "shown"
                    );
                case SDL_WINDOWEVENT_HIDDEN:         /**< Window has been hidden */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "hidden"
                    );
                case SDL_WINDOWEVENT_EXPOSED:        /**< Window has been exposed and should be redrawn */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "exposed"
                    );
                case SDL_WINDOWEVENT_MOVED:          /**< Window has been moved to data1, data2 */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "moved"
                    );
                case SDL_WINDOWEVENT_RESIZED:        /**< Window has been resized to data1xdata2 */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "resized"
                    );
                case SDL_WINDOWEVENT_SIZE_CHANGED:   /**< The window size has changed, either as a result of an API call or through the system or user changing the window size. */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "size_changed"
                    );
                case SDL_WINDOWEVENT_MINIMIZED:      /**< Window has been minimized */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "minimized"
                    );
                case SDL_WINDOWEVENT_MAXIMIZED:      /**< Window has been maximized */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "maximized"
                    );
                case SDL_WINDOWEVENT_RESTORED:       /**< Window has been restored to normal size and position */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "restored"
                    );
                case SDL_WINDOWEVENT_ENTER:          /**< Window has gained mouse focus */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "enter"
                    );
                case SDL_WINDOWEVENT_LEAVE:          /**< Window has lost mouse focus */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "leave"
                    );
                case SDL_WINDOWEVENT_FOCUS_GAINED:   /**< Window has gained keyboard focus */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "focus_gained"
                    );
                case SDL_WINDOWEVENT_FOCUS_LOST:     /**< Window has lost keyboard focus */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "focus_lost"
                    );
                case SDL_WINDOWEVENT_CLOSE:          /**< The window manager requests that the window be closed */
                    return PL_unify_term(term,
                        PL_FUNCTOR, window_f,
                            PL_CHARS, "close"
                    );
            }
            break;

        case SDL_SYSWMEVENT: /**< System specific event */
            break;       

        /* Keyboard events */
        case SDL_KEYDOWN: /**< Key pressed */
        case SDL_KEYUP: /**< Key released */
        {
            const char *keyname = SDL_GetKeyName(event.key.keysym.sym);
            return PL_unify_term(term,
                PL_FUNCTOR, key_f,
                    PL_UTF8_STRING, keyname,
                    PL_CHARS, event.key.state == SDL_PRESSED ? "down" : "up",
                    PL_CHARS, event.key.repeat == 0 ? "initial" : "repeat"
            );
            break;
        }
        case SDL_TEXTEDITING: /**< Keyboard text editing (composition) */
            break;
        case SDL_TEXTINPUT: /**< Keyboard text input */
            break;
        case SDL_KEYMAPCHANGED: /**< Keymap changed due to a system event such as an input language or keyboard layout change. */
            break;

        /* Mouse events */
        case SDL_MOUSEMOTION:
            return PL_unify_term(term,
                PL_FUNCTOR, mouse_position_f,
                    PL_INT, event.motion.x,
                    PL_INT, event.motion.y);
            break;
        case SDL_MOUSEBUTTONDOWN:       
            /**< Mouse button pressed */
            break;
        case SDL_MOUSEBUTTONUP:         
            /**< Mouse button released */
            break;
        case SDL_MOUSEWHEEL:            
            /**< Mouse wheel motion */
            break;

        /* Joystick events */
        case SDL_JOYAXISMOTION:
            /**< Joystick axis motion */
        case SDL_JOYBALLMOTION:         
            /**< Joystick trackball motion */
        case SDL_JOYHATMOTION:          
            /**< Joystick hat position change */
        case SDL_JOYBUTTONDOWN:         
            /**< Joystick button pressed */
        case SDL_JOYBUTTONUP:           
            /**< Joystick button released */
        case SDL_JOYDEVICEADDED:        
            /**< A new joystick has been inserted into the system */
        case SDL_JOYDEVICEREMOVED:      
            /**< An opened joystick has been removed */

        /* Game controller events */
        case SDL_CONTROLLERAXISMOTION:
            /**< Game controller axis motion */
        case SDL_CONTROLLERBUTTONDOWN:         
            /**< Game controller button pressed */
        case SDL_CONTROLLERBUTTONUP:           
            /**< Game controller button released */
        case SDL_CONTROLLERDEVICEADDED:        
            /**< A new Game controller has been inserted into the system */
        case SDL_CONTROLLERDEVICEREMOVED:      
            /**< An opened Game controller has been removed */
        case SDL_CONTROLLERDEVICEREMAPPED:     
            /**< The controller mapping was updated */

        /* Touch events */
        case SDL_FINGERDOWN:
        case SDL_FINGERUP:
        case SDL_FINGERMOTION:

        /* Gesture events */
        case SDL_DOLLARGESTURE:
        case SDL_DOLLARRECORD:
        case SDL_MULTIGESTURE:

        /* Clipboard events */
        case SDL_CLIPBOARDUPDATE:
            /**< The clipboard changed */

        /* Drag and drop events */
        case SDL_DROPFILE:
            /**< The system requests a file open */

            /* Audio hotplug events */
        case SDL_AUDIODEVICEADDED:
            /**< A new audio device is available */
        case SDL_AUDIODEVICEREMOVED:       
            /**< An audio device has been removed. */

        /* Render events */
        case SDL_RENDER_TARGETS_RESET:
            /**< The render targets have been reset and their contents need to be updated */
        case SDL_RENDER_DEVICE_RESET:
            /**< The device has been reset and all textures need to be recreated */

        case SDL_USEREVENT:
        default:
            break;
    }
    return PL_unify_atom_chars(term, "unknown");
}

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
    PL_register_foreign("sdl_render_blendmode", 2, pl_sdl_render_blendmode, 0);
    PL_register_foreign("sdl_render_color", 2, pl_sdl_render_color, 0);
    PL_register_foreign("sdl_render_clear", 1, pl_sdl_render_clear, 0);
    PL_register_foreign("sdl_render_present", 1, pl_sdl_render_present, 0);
    PL_register_foreign("sdl_draw", 2, pl_sdl_draw, 0);
    PL_register_foreign("sdl_wait_event", 2, pl_sdl_wait_event, 0);
    PL_register_foreign("sdl_terminate", 0, pl_sdl_terminate, 0);
}
