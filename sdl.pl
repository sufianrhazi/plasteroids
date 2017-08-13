vec2_eval(vec2(X, Y), vec2(X, Y)).

vec2_eval(vec2(X, Y), A + B) :-
    vec2_eval(vec2(AX, AY), A),
    vec2_eval(vec2(BX, BY), B),
    X is AX + BX,
    Y is AY + BY.

vec2_eval(vec2(X, Y), A - B) :-
    vec2_eval(vec2(AX, AY), A),
    vec2_eval(vec2(BX, BY), B),
    X is AX - BX,
    Y is AY - BY.

vec2_eval(vec2(X, Y), scale(S, V)) :-
    vec2_eval(vec2(VX, VY), V),
    X is VX * S,
    Y is VY * S.

vec2_eval(vec2(X, Y), unit_rad(R)) :-
    X is cos(R),
    Y is sin(R).

rand_color(RGBA) :-
    random_between(0, 255, R),
    random_between(0, 255, G),
    random_between(0, 255, B),
    random_between(0, 40, A),
    RGBA = rgba(R, G, B, A).

bullet_bounds(Bullet, rect(TopLeft, BottomRight)) :-
    vec2_eval(TopLeft, Bullet.pos - vec2(1, 1)),
    vec2_eval(BottomRight, Bullet.pos + vec2(1, 1)).

update_bullet(State, Delta, Bullet, NewBullet) :-
    vec2_eval(Dest, Bullet.pos + scale(Delta, Bullet.vel)),
    Moved = Bullet.put(_{
        pos: Dest
    }),
    bullet_bounds(Moved, Bounds),
    wrap_bounds(rect(vec2(0, 0), vec2(State.width, State.height)), Bounds, Moved.pos, WrapPos),
    NewBullet = Moved.put(pos, WrapPos).

update_bullets(_, _, [], []).

update_bullets(State, Delta, [Bullet|Bullets], NewBullets) :-
    Bullet.expiry < State.time
        -> update_bullets(State, Delta, Bullets, NewBullets)

        ; [Updated|Rest] = NewBullets,
          update_bullet(State, Delta, Bullet, Updated),
          update_bullets(State, Delta, Bullets, Rest).

update_ship(State, Delta, Ship, NextShip) :-
    (Ship.turn = clockwise
        -> Dir is Ship.dir + pi * Delta
        ; true),
    (Ship.turn = counterclockwise
        -> Dir is Ship.dir - pi * Delta
        ; true),
    (Ship.turn = no
        -> Dir = Ship.dir
        ; true),
    (Ship.accel = false
        -> Vel = Ship.vel
        ; true),
    (Ship.accel = true
        -> vec2_eval(Vel, Ship.vel + scale(Delta * 50, unit_rad(Ship.dir)))
        ; true),
    vec2_eval(Pos, Ship.pos + scale(Delta, Vel)),
    MovedShip = Ship.put(_{
        dir: Dir,
        vel: Vel,
        pos: Pos
    }),
    ship_bounds(MovedShip, Bounds),
    wrap_bounds(rect(vec2(0, 0), vec2(State.width, State.height)), Bounds, Pos, WrappedPos),
    NextShip = MovedShip.put(pos, WrappedPos).

update_state(Delta, State, NextState) :-
    update_ship(State, Delta, State.ship, NextShip),
    update_bullets(State, Delta, State.bullets, NextBullets),
    NextState = State.put(_{
        bullets: NextBullets,
        ship: NextShip
    }).

wrap_bounds(rect(vec2(OutL, OutT), vec2(OutR, OutB)), rect(vec2(InL, InT), vec2(InR, InB)), vec2(X, Y), vec2(WrapX, WrapY)) :-
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

handle_event(_, _, terminal, terminal).

handle_event(_, quit, _, terminal).

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
    (Start =< EndTime
        ->
            MaxWait is round(1000 * (EndTime - Start)),
            sdl_wait_event(Event, MaxWait),
            get_time(Now)
        ; Event = timeout, Now = Start),
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
    Star = star{ pos: vec2(X, Y), color: rgb(R, G, B), intensity: Intensity, period: Period }.

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
    sdl_draw(Renderer, Star.pos).

draw_stars(_, _, []).

draw_stars(Time, Renderer, [Star|Stars]) :-
    draw_star(Time, Renderer, Star),
    draw_stars(Time, Renderer, Stars).

ship_bounds(Ship, rect(vec2(Left, Top), vec2(Right, Bottom))) :-
    ship_front(Ship, vec2(X1, Y1)),
    ship_left(Ship, vec2(X2, Y2)),
    ship_right(Ship, vec2(X3, Y3)),
    ship_back(Ship, vec2(X4, Y4)),
    Left is min(X1, min(X2, min(X3, X4))),
    Right is max(X1, max(X2, max(X3, X4))),
    Top is min(Y1, min(Y2, min(Y3, Y4))),
    Bottom is max(Y1, max(Y2, max(Y3, Y4))).

ship_front(Ship, FrontPos) :-
    vec2_eval(FrontPos, Ship.pos + scale(Ship.size, unit_rad(Ship.dir))).

ship_left(Ship, WingPos) :-
    vec2_eval(WingPos, Ship.pos + scale(Ship.size * 3 / 4, unit_rad(Ship.dir + pi * 3 / 4))).

ship_right(Ship, WingPos) :-
    vec2_eval(WingPos, Ship.pos + scale(Ship.size * 3 / 4, unit_rad(Ship.dir - pi * 3 / 4))).

ship_back(Ship, ExhaustPos) :-
    vec2_eval(ExhaustPos, Ship.pos + scale(Ship.size * 1 / 4, unit_rad(Ship.dir + pi))).

draw_ship(Renderer, Ship) :-
    HalfSize is round(Ship.size / 2),
    ship_front(Ship, ShipFront),
    ship_left(Ship, ShipLeft),
    ship_back(Ship, ShipBack),
    ship_right(Ship, ShipRight),
    ((Ship.accel = true) -> 
        (
            random_between(-10, 10, Deg),
            Rad is Deg * 2 * pi / 360,
            vec2_eval(FireTip, Ship.pos + scale(Ship.size * 1.2, unit_rad(Ship.dir + pi + Rad))),
            vec2_eval(FireLeft, Ship.pos + scale(HalfSize, unit_rad(Ship.dir + pi * 3 / 4))),
            vec2_eval(FireRight, Ship.pos + scale(HalfSize, unit_rad(Ship.dir - pi * 3 / 4))),
            sdl_render_color(Renderer, rgba(255, 255, 0, 255)),
            sdl_draw(Renderer, line(FireLeft, FireTip)),
            sdl_draw(Renderer, line(FireRight, FireTip))
        ); true),
    sdl_render_color(Renderer, rgba(255, 255, 255, 255)),
    sdl_draw(Renderer, line(ShipFront, ShipLeft)),
    sdl_draw(Renderer, line(ShipLeft, ShipBack)),
    sdl_draw(Renderer, line(ShipBack, ShipRight)),
    sdl_draw(Renderer, line(ShipRight, ShipFront)).

initial_ship(Ship, Width, Height) :-
    X is Width / 2,
    Y is Height / 2,
    Dir is pi / 2,
    Ship = ship{
        pos: vec2(X, Y),
        vel: vec2(0, 0),
        dir: Dir,
        turn: no,
        accel: false,
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
    ship_front(Ship, Pos),
    Speed = 200,
    vec2_eval(Vel, Ship.vel + scale(Speed, unit_rad(Ship.dir))),
    Bullet = bullet{
        pos: Pos,
        vel: Vel,
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
