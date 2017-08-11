rand_color(RGBA) :-
    random_between(0, 255, R),
    random_between(0, 255, G),
    random_between(0, 255, B),
    random_between(0, 40, A),
    RGBA = rgba(R, G, B, A).

handle_event(_, terminal, terminal).

handle_event(quit, _, terminal).

handle_event(Event, State, NextState) :-
    get_time(Now),
    Delta is Now - State.time,
    NextState = State.put(time, Now).

draw_state(Renderer, State) :-
    sdl_render_color(Renderer, rgba(0, 0, 0, 10)),
    sdl_render_clear(Renderer),
    draw_stars(State.time, Renderer, State.stars),
    sdl_render_present(Renderer).

pump_events(EndTime, State, NextState) :-
    get_time(Now),
    ((Now =< EndTime) -> (
        MaxWait is round(1000 * (EndTime - Now)),
        sdl_wait_event(Event, MaxWait),
        handle_event(Event, State, MidState),
        ((Event \= timeout)
            -> pump_events(EndTime, MidState, NextState)
            ; MidState = NextState
            )
    ); NextState = State).

event_loop(Renderer, State) :-
    draw_state(Renderer, State),
    !,
    get_time(Now),
    Target is Now + 0.01666666,
    pump_events(Target, State, NextState),
    !,
    ((NextState \= terminal) -> event_loop(Renderer, NextState); true).

initial_star(Star) :-
    random_between(100, 150, R),
    random_between(100, 150, G),
    random_between(100, 150, B),
    random_between(0, 640, X),
    random_between(0, 480, Y),
    random_between(0, 50, Intensity),
    random_between(30, 200, P),
    Period is 2 * pi * (P / 100),
    Star = star{ x: X, y: Y, color: rgb(R, G, B), intensity: Intensity, period: Period }.

initial_stars([], 0).

initial_stars([Star|Stars], N) :-
    M is N - 1,
    initial_star(Star),
    initial_stars(Stars, M).

draw_star(Time, Renderer, Star) :-
    random_between(0, 100, Ra),
    random_between(0, 100, Ga),
    random_between(0, 100, Ba),
    rgb(Rb, Gb, Bb) = Star.color,
    R is Ra + Rb,
    G is Ga + Gb,
    B is Ba + Bb,
    Alpha is 205 + round(Star.intensity * sin(Time * Star.period)),
    sdl_render_color(Renderer, rgba(R, G, B, Alpha)),
    sdl_draw(Renderer, pt(Star.x, Star.y)).

draw_stars(_, _, []).

draw_stars(Time, Renderer, [Star|Stars]) :-
    draw_star(Time, Renderer, Star),
    draw_stars(Time, Renderer, Stars).

initial_state(State, Width, Height) :-
    initial_stars(Stars, 800),
    get_time(When),
    State = state{
        stars: Stars,
        width: Width,
        height: Height,
        time: When
    }.

main(_) :-
    guitracer,
    use_foreign_library(sdl),
    sdl_init([video]),
    Width = 640,
    Height = 480,
    sdl_create_window("SDL Test", Width, Height, [], Window),
    sdl_create_renderer(Window, [software], Renderer),
    sdl_render_blendmode(Renderer, alpha),
    initial_state(State, Width, Height),
    event_loop(Renderer, State),
    sdl_destroy_renderer(Renderer),
    sdl_destroy_window(Window),
    sdl_terminate.
