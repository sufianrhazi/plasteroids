rand_color(RGBA) :-
    random_between(0, 255, R),
    random_between(0, 255, G),
    random_between(0, 255, B),
    random_between(0, 40, A),
    RGBA = rgba(R, G, B, A).

bullet_bounds(Bullet, rect(pt(L, T), pt(R, B))) :-
    pt(X, Y) = Bullet.pos,
    L is round(X - 1),
    R is round(X + 1),
    T is round(Y - 1),
    B is round(Y + 1).

update_bullet(State, Delta, Bullet, NewBullet) :-
    pt(X, Y) = Bullet.pos,
    NewX is X + Delta * Bullet.dx,
    NewY is Y + Delta * Bullet.dy,
    Moved = Bullet.put(_{
        pos: pt(NewX, NewY)
    }),
    bullet_bounds(Moved, Bounds),
    wrap_bounds(rect(pt(0, 0), pt(State.width, State.height)), Bounds, Moved.pos, WrapPos),
    NewBullet = Moved.put(pos, WrapPos).

update_bullets(_, _, [], []).

update_bullets(State, Delta, [Bullet|Bullets], NewBullets) :-
    Bullet.expiry < State.time
        -> update_bullets(State, Delta, Bullets, NewBullets)

        ; [Updated|Rest] = NewBullets,
          update_bullet(State, Delta, Bullet, Updated),
          update_bullets(State, Delta, Bullets, Rest).

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
    NextShip = State.ship.put(_{
        dir: Dir,
        dx: DX,
        dy: DY,
        x: X,
        y: Y
    }),
    ship_bounds(NextShip, Bounds),
    wrap_bounds(rect(pt(0, 0), pt(State.width, State.height)), Bounds, pt(X, Y), pt(WrapX, WrapY)),
    update_bullets(State, Delta, State.bullets, NextBullets),
    NextState = State.put(_{
        bullets: NextBullets,
        ship: NextShip.put(_{
            x: WrapX,
            y: WrapY
        })
    }).

wrap_bounds(rect(pt(OutL, OutT), pt(OutR, OutB)), rect(pt(InL, InT), pt(InR, InB)), pt(X, Y), pt(WrapX, WrapY)) :-
    (InR < OutL
        -> WrapX is OutR - OutL + X + InR - InL
        ; InL > OutR
            -> WrapX is OutR + OutL + X - InR - InL
            ; WrapX = X),
    (InB < OutT 
        -> WrapY is OutB - OutT + Y + InB - InT
        ; InT > OutB
            -> WrapY is OutB + OutT + Y - InB - InT
            ; WrapY = Y).

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
    make_bullet(State.ship, Bullet),
    InputState = State.put(bullets, [Bullet|State.bullets]),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, _, State, TerminalState) :-
    update_state(Delta, State, TerminalState).

draw_state(Renderer, State) :-
    sdl_render_color(Renderer, rgba(0, 0, 0, 255)),
    sdl_render_clear(Renderer),
    draw_stars(State.time, Renderer, State.stars),
    draw_ship(Renderer, State.ship),
    draw_bullets(Renderer, State.bullets),
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

initial_star(Star, Width, Height) :-
    random_between(100, 150, R),
    random_between(100, 150, G),
    random_between(100, 150, B),
    random_between(0, Width, X),
    random_between(0, Height, Y),
    random_between(0, 50, Intensity),
    random_between(30, 200, P),
    Period is 2 * pi * (P / 100),
    Star = star{ x: X, y: Y, color: rgb(R, G, B), intensity: Intensity, period: Period }.

initial_stars([], 0, _, _).

initial_stars([Star|Stars], N, Width, Height) :-
    M is N - 1,
    initial_star(Star, Width, Height),
    initial_stars(Stars, M, Width, Height).

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

ship_bounds(Ship, rect(pt(Left, Top), pt(Right, Bottom))) :-
    ship_front(Ship, pt(X1, Y1)),
    ship_left(Ship, pt(X2, Y2)),
    ship_right(Ship, pt(X3, Y3)),
    ship_back(Ship, pt(X4, Y4)),
    Left is min(X1, min(X2, min(X3, X4))),
    Right is max(X1, max(X2, max(X3, X4))),
    Top is min(Y1, min(Y2, min(Y3, Y4))),
    Bottom is max(Y1, max(Y2, max(Y3, Y4))).

ship_front(Ship, pt(X, Y)) :-
    X is round(Ship.x + cos(Ship.dir) * Ship.size),
    Y is round(Ship.y + sin(Ship.dir) * Ship.size).

ship_left(Ship, pt(X, Y)) :-
    X is round(Ship.x + cos(Ship.dir + pi * 3 / 4) * Ship.size * 3 / 4),
    Y is round(Ship.y + sin(Ship.dir + pi * 3 / 4) * Ship.size * 3 / 4).

ship_right(Ship, pt(X, Y)) :-
    X is round(Ship.x + cos(Ship.dir - pi * 3 / 4) * Ship.size * 3 / 4),
    Y is round(Ship.y + sin(Ship.dir - pi * 3 / 4) * Ship.size * 3 / 4).

ship_back(Ship, pt(X, Y)) :-
    X is round(Ship.x + cos(Ship.dir + pi) * Ship.size * 1 / 4),
    Y is round(Ship.y + sin(Ship.dir + pi) * Ship.size * 1 / 4).

draw_ship(Renderer, Ship) :-
    HalfSize is round(Ship.size / 2),
    ship_front(Ship, A),
    ship_left(Ship, B),
    ship_back(Ship, C),
    ship_right(Ship, D),
    ((Ship.accel = true) -> 
        (
            random_between(-10, 10, Deg),
            Rad is Deg * 2 * pi / 360,
            FireX is round(Ship.x + 1.2 * Ship.size * cos(Ship.dir + pi + Rad)),
            FireY is round(Ship.y + 1.2 * Ship.size * sin(Ship.dir + pi + Rad)),
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

initial_ship(Ship, Width, Height) :-
    X is Width / 2,
    Y is Height / 2,
    Dir is pi / 2,
    Ship = ship{
        x: X,
        y: Y,
        dir: Dir,
        turn: no,
        accel: false,
        dx: 0,
        dy: 0,
        size: 18
    }.

draw_bullet(Renderer, Bullet) :-
    sdl_render_color(Renderer, rgba(255, 200, 200, 255)),
    bullet_bounds(Bullet, Rect),
    sdl_draw(Renderer, fill(Rect)).

draw_bullets(_, []).

draw_bullets(Renderer, [Bullet|Bullets]) :-
    draw_bullet(Renderer, Bullet),
    draw_bullets(Renderer, Bullets).

make_bullet(Ship, Bullet) :-
    get_time(Now),
    Expiry is Now + 2,
    ship_front(Ship, Front),
    Speed = 200,
    DX is Ship.dx + Speed * cos(Ship.dir),
    DY is Ship.dy + Speed * sin(Ship.dir),
    Bullet = bullet{
        pos: Front,
        dx: DX,
        dy: DY,
        expiry: Expiry
    }.

initial_state(State, Width, Height) :-
    initial_stars(Stars, 800, Width, Height),
    initial_ship(Ship, Width, Height),
    get_time(When),
    State = state{
        stars: Stars,
        bullets: [],
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
