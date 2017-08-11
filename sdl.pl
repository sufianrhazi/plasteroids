rand_color(RGBA) :-
    random_between(0, 255, R),
    random_between(0, 255, G),
    random_between(0, 255, B),
    random_between(0, 40, A),
    RGBA = rgba(R, G, B, A).

update_state(Delta, State, NextState) :-
    ((State.ship.turn = clockwise)
        -> Dir is State.ship.dir + pi * Delta
        ; true),
    ((State.ship.turn = counterclockwise)
        -> Dir is State.ship.dir - pi * Delta
        ; true),
    ((State.ship.turn = no)
        -> Dir = State.ship.dir
        ; true),
    ((State.ship.accel = false)
        -> (
            DX = State.ship.dx,
            DY = State.ship.dy
        ); true),
    ((State.ship.accel = true)
        -> (
            DX is State.ship.dx + Delta * 50 * cos(State.ship.dir),
            DY is State.ship.dy + Delta * 50 * sin(State.ship.dir)
        ); true),
    X is State.ship.x + Delta * DX,
    Y is State.ship.y + Delta * DY,
    NextState = State
        .put(ship, 
            State.ship
                .put(dir, Dir)
                .put(dx, DX)
                .put(dy, DY)
                .put(x, X)
                .put(y, Y)
            ).

handle_event(Delta, _, terminal, terminal).

handle_event(Delta, quit, _, terminal).

handle_event(Delta, key("Right", down, initial), State, TerminalState) :-
    InputState = State.put(ship, State.ship.put(turn, clockwise)),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Right", up, initial), State, TerminalState) :-
    InputState = State.put(ship, State.ship.put(turn, no)),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Left", down, initial), State, TerminalState) :-
    InputState = State.put(ship, State.ship.put(turn, counterclockwise)),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Left", up, initial), State, TerminalState) :-
    InputState = State.put(ship, State.ship.put(turn, no)),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Up", down, initial), State, TerminalState) :-
    InputState = State.put(ship, State.ship.put(accel, true)),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Up", up, initial), State, TerminalState) :-
    InputState = State.put(ship, State.ship.put(accel, false)),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Space", down, initial), State, TerminalState) :-
    write("Fire!\n"),
    update_state(Delta, State, TerminalState).

handle_event(Delta, _, State, TerminalState) :-
    update_state(Delta, State, TerminalState).

draw_state(Renderer, State) :-
    sdl_render_color(Renderer, rgba(0, 0, 0, 255)),
    sdl_render_clear(Renderer),
    draw_stars(State.time, Renderer, State.stars),
    draw_ship(Renderer, State.ship),
    sdl_render_present(Renderer).

pump_events(EndTime, State, NextState) :-
    Start = State.time,
    ((Start =< EndTime) -> (
        MaxWait is round(1000 * (EndTime - Start)),
        sdl_wait_event(Event, MaxWait),
        get_time(Now)
    ); Event = timeout, Now = Start),
    Delta is Now - Start,
    handle_event(Delta, Event, State.put(time, Now), MidState),
    ((Event = timeout; MidState = terminal)
        -> MidState = NextState
        ; pump_events(EndTime, MidState, NextState)
        ).

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

draw_ship(Renderer, Ship) :-
    Size = 15,
    HalfSize is round(Size / 2),
    PeakX is round(Ship.x + cos(Ship.dir) * Size),
    PeakY is round(Ship.y + sin(Ship.dir) * Size),
    SeatX is round(Ship.x + cos(Ship.dir + pi) * Size * 1 / 4),
    SeatY is round(Ship.y + sin(Ship.dir + pi) * Size * 1 / 4),
    LX is round(Ship.x + cos(Ship.dir + pi * 3 / 4) * Size * 3 / 4),
    LY is round(Ship.y + sin(Ship.dir + pi * 3 / 4) * Size * 3 / 4),
    RX is round(Ship.x + cos(Ship.dir - pi * 3 / 4) * Size * 3 / 4),
    RY is round(Ship.y + sin(Ship.dir - pi * 3 / 4) * Size * 3 / 4),
    A = pt(PeakX, PeakY),
    B = pt(LX, LY),
    C = pt(SeatX, SeatY),
    D = pt(RX, RY),
    ((Ship.accel = true) -> 
        (
            random_between(-10, 10, Deg),
            Rad is Deg * 2 * pi / 360,
            FireX is round(Ship.x + 1.2 * Size * cos(Ship.dir + pi + Rad)),
            FireY is round(Ship.y + 1.2 * Size * sin(Ship.dir + pi + Rad)),
            FireLX is round(Ship.x + cos(Ship.dir + pi * 3 / 4) * HalfSize),
            FireLY is round(Ship.y + sin(Ship.dir + pi * 3 / 4) * HalfSize),
            FireRX is round(Ship.x + cos(Ship.dir - pi * 3 / 4) * HalfSize),
            FireRY is round(Ship.y + sin(Ship.dir - pi * 3 / 4) * HalfSize),
            FL = pt(FireLX, FireLY),
            FR = pt(FireRX, FireRY),
            FT = pt(FireX, FireY),
            sdl_render_color(Renderer, rgba(255, 255, 0, 255)),
            sdl_draw(Renderer, line(FL, FT)),
            sdl_draw(Renderer, line(FR, FT))
        ); true),
    sdl_render_color(Renderer, rgba(255, 255, 255, 255)),
    sdl_draw(Renderer, line(A, B)),
    sdl_draw(Renderer, line(B, C)),
    sdl_draw(Renderer, line(C, D)),
    sdl_draw(Renderer, line(D, A)).

initial_ship(Ship) :-
    X is 640 / 2,
    Y is 480 / 2,
    Dir is pi / 2,
    Ship = ship{
        x: X,
        y: Y,
        dir: Dir,
        turn: no,
        accel: false,
        dx: 0,
        dy: 0
    }.

initial_state(State, Width, Height) :-
    initial_stars(Stars, 800),
    initial_ship(Ship),
    get_time(When),
    State = state{
        stars: Stars,
        width: Width,
        height: Height,
        ship: Ship,
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
