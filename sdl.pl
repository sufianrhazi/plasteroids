vec2_x(vec2(X, _), X).

vec2_y(vec2(_, Y), Y).

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

vec2_eval(vec2(X, Y), unit_rad(R)) :- /* TODO: use polar coords */
    X is cos(R),
    Y is sin(R).

vec2_polar(vec2(X, Y), polar(R, Phi)) :-
    X is R * cos(Phi),
    Y is R * sin(Phi).

polar_eval(polar(R, Phi), polar(R, Phi)).

polar_eval(polar(R, Phi), A + B) :-
    polar_eval(polar(R1, P1), A),
    polar_eval(polar(R2, P2), B),
    R is R1 + R2,
    Phi is P1 + P2.

polar_eval(polar(R, Phi), A - B) :-
    polar_eval(polar(R1, P1), A),
    polar_eval(polar(R2, P2), B),
    R is R1 - R2,
    Phi is P1 - P2.

polar_eval(polar(R, Phi), A * scalar(S)) :-
    polar_eval(polar(R1, Phi), A),
    R is R1 * S.

deg_rad(Deg, Rad) :-
    Rad is Deg * 2 * pi / 360.

rand_color(RGBA) :-
    random_between(0, 255, R),
    random_between(0, 255, G),
    random_between(0, 255, B),
    random_between(0, 40, A),
    RGBA = rgba(R, G, B, A).

bullet_bounds(Bullet, rect(TopLeft, BottomRight)) :-
    vec2_eval(TopLeft, Bullet.pos - vec2(1, 1)),
    vec2_eval(BottomRight, Bullet.pos + vec2(1, 1)).

bullet_alive(State, Bullet) :-
    get_assoc(time, State, Now),
    Now < Bullet.expiry.

update_bullet(State, Delta, Bullet, NewBullet) :-
    vec2_eval(Dest, Bullet.pos + scale(Delta, Bullet.vel)),
    Moved = Bullet.put(_{
        pos: Dest
    }),
    bullet_bounds(Moved, Bounds),
    get_assoc(bounds, State, ScreenBounds),
    wrap_bounds(ScreenBounds, Bounds, Moved.pos, WrapPos),
    NewBullet = Moved.put(pos, WrapPos).

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
    get_assoc(bounds, State, ScreenBounds),
    wrap_bounds(ScreenBounds, Bounds, Pos, WrappedPos),
    NextShip = MovedShip.put(pos, WrappedPos).

update_state(Delta, State, NextState) :-
    get_assoc(ship, State, Ship),
    update_ship(State, Delta, Ship, NextShip),
    get_assoc(bullets, State, Bullets),
    include(bullet_alive(State), Bullets, LiveBullets),
    maplist(update_bullet(State, Delta), LiveBullets, NextBullets),
    put_assoc(bullets, State, NextBullets, State1),
    get_assoc(asteroids, State, Asteroids),
    maplist(update_asteroid(State, Delta), Asteroids, NextAsteroids),
    put_assoc(asteroids, State1, NextAsteroids, State2),
    put_assoc(ship, State2, NextShip, NextState).

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
    get_assoc(ship, State, Ship),
    Ship1 = Ship.put(_{turn: clockwise}),
    put_assoc(ship, State, Ship1, InputState),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Right", up, initial), State, TerminalState) :-
    get_assoc(ship, State, Ship),
    Ship1 = Ship.put(_{turn: no}),
    put_assoc(ship, State, Ship1, InputState),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Left", down, initial), State, TerminalState) :-
    get_assoc(ship, State, Ship),
    Ship1 = Ship.put(_{turn: counterclockwise}),
    put_assoc(ship, State, Ship1, InputState),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Left", up, initial), State, TerminalState) :-
    get_assoc(ship, State, Ship),
    Ship1 = Ship.put(_{turn: no}),
    put_assoc(ship, State, Ship1, InputState),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Up", down, initial), State, TerminalState) :-
    get_assoc(ship, State, Ship),
    Ship1 = Ship.put(_{accel: true}),
    put_assoc(ship, State, Ship1, InputState),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Up", up, initial), State, TerminalState) :-
    get_assoc(ship, State, Ship),
    Ship1 = Ship.put(_{accel: false}),
    put_assoc(ship, State, Ship1, InputState),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, key("Space", down, initial), State, TerminalState) :-
    get_assoc(ship, State, Ship),
    make_bullet(Ship, Bullet),
    get_assoc(bullets, State, Bullets),
    put_assoc(bullets, State, [Bullet|Bullets], InputState),
    update_state(Delta, InputState, TerminalState).

handle_event(Delta, _, State, TerminalState) :-
    update_state(Delta, State, TerminalState).

draw_state(Renderer, State) :-
    sdl_render_color(Renderer, rgba(0, 0, 0, 255)),
    sdl_render_clear(Renderer),
    get_assoc(time, State, Now),
    get_assoc(stars, State, Stars),
    maplist(draw_star(Now, Renderer), Stars),
    get_assoc(ship, State, Ship),
    draw_ship(Renderer, Ship),
    get_assoc(asteroids, State, Asteroids),
    maplist(draw_asteroid(Renderer), Asteroids),
    get_assoc(bullets, State, Bullets),
    maplist(draw_bullet(Renderer), Bullets),
    sdl_render_present(Renderer).

pump_events(EndTime, State, NextState) :-
    get_assoc(time, State, Start),
    (Start =< EndTime ->
        sdl_wait_event(Event, 2),
        get_time(Now)
    ;
        Event = timeout,
        Now = Start
    ),
    Delta is Now - Start,
    put_assoc(time, State, Now, TimeState),
    handle_event(Delta, Event, TimeState, MidState),
    ((Event = timeout; MidState = terminal) ->
        MidState = NextState
    ;
        pump_events(EndTime, MidState, NextState)
    ).

event_loop(Renderer, State) :-
    draw_state(Renderer, State),
    get_time(Now),
    Target is Now + 0.010,
    pump_events(Target, State, NextState),
    ((NextState \= terminal) -> event_loop(Renderer, NextState); true).

initial_star(Star, Width, Height) :-
    random_between(50, 150, R),
    random_between(50, 150, G),
    random_between(50, 150, B),
    random_between(0, Width, X),
    random_between(0, Height, Y),
    random_between(0, 50, Intensity),
    random_between(30, 200, P),
    Period is 2 * pi * (P / 100),
    Star = star{ pos: vec2(X, Y), color: rgb(R, G, B), intensity: Intensity, period: Period }.

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
            deg_rad(Deg, Rad),
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
    sdl_render_color(Renderer, rgba(255, 255, 255, 255)),
    bullet_bounds(Bullet, Rect),
    sdl_draw(Renderer, fill(Rect)).

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

draw_polygon(_, []).
draw_polygon(_, [_]).
draw_polygon(_, [_,_]).
draw_polygon(Renderer, [A,B,C|Rest]) :-
    sdl_draw(Renderer, line(A, B)),
    draw_polygon(Renderer, A, [B,C|Rest]).

draw_polygon(_, _, []). % should never happen

draw_polygon(Renderer, Initial, [End]) :-
    sdl_draw(Renderer, line(End, Initial)).

draw_polygon(Renderer, Terminal, [P,G|T]) :-
    sdl_draw(Renderer, line(P, G)),
    draw_polygon(Renderer, Terminal, [G|T]).

initial_asteroid_point(NumPoints, N, Point) :-
    random(Dist),
    Distance is Dist * 0.5 + 0.75,
    random_between(-50, 50, Jigger),
    JiggerRad is (Jigger / 100) * 2 * pi / NumPoints,
    Rad is JiggerRad + 2 * pi * N / NumPoints,
    Point = polar(Distance, Rad).

initial_asteroid_points(NumPoints, Points) :-
    findall(Point, (between(1, NumPoints, N), initial_asteroid_point(NumPoints, N, Point)), Points).

make_asteroid(Size, Width, Height, Asteroid) :-
    random_between(0, 360, Deg),
    deg_rad(Deg, Rad),
    Speed = 15,
    random_between(-36, 36, AngDeg),
    deg_rad(AngDeg, AngRad),
    random_between(0, Width, X),
    random_between(0, Height, Y),
    random_between(10, 15, NumPoints),
    initial_asteroid_points(NumPoints, Points),
    Asteroid = asteroid{
        size: Size,
        pos: vec2(X, Y),
        points: Points,
        vel: polar(Speed, Rad),
        rot: 0,
        angvel: AngRad
    }.

asteroid_bounds(Asteroid, Bounds) :-
    maplist(asteroid_point_vec2(Asteroid.rot, Asteroid.size, Asteroid.pos), Asteroid.points, Points),
    maplist(vec2_x, Points, XS),
    maplist(vec2_y, Points, YS),
    min_list(XS, Left),
    max_list(XS, Right),
    min_list(YS, Top),
    max_list(YS, Bottom),
    Bounds = rect(vec2(Left, Top), vec2(Right, Bottom)).

asteroid_point_vec2(Rot, Size, Pos, Polar, Vec) :-
    polar_eval(RotatedScaled, (Polar + polar(0, Rot)) * scalar(Size)),
    vec2_polar(RotatedScaledPos, RotatedScaled),
    vec2_eval(Vec, Pos + RotatedScaledPos).

draw_asteroid(Renderer, Asteroid) :-
    maplist(asteroid_point_vec2(Asteroid.rot, Asteroid.size, Asteroid.pos), Asteroid.points, Points),
    draw_polygon(Renderer, Points).

update_asteroid(State, Delta, Asteroid, NextAsteroid) :-
    vec2_polar(Vel, Asteroid.vel),
    vec2_eval(NextPos, scale(Delta, Vel) + Asteroid.pos),
    NextRot is Delta * Asteroid.angvel + Asteroid.rot,
    get_assoc(bounds, State, ScreenBounds),
    asteroid_bounds(Asteroid, AsteroidBounds),
    wrap_bounds(ScreenBounds, AsteroidBounds, NextPos, WrapPos),
    NextAsteroid = Asteroid.put(_{
        pos: WrapPos,
        rot: NextRot
    }).

initial_state(State, Width, Height) :-
    findall(Star, (between(0, 400, _), initial_star(Star, Width, Height)), Stars),
    initial_ship(Ship, Width, Height),
    findall(Asteroid, (between(1, 5, _), make_asteroid(30, Width, Height, Asteroid)), Asteroids),
    get_time(When),
    list_to_assoc([
        stars-Stars,
        bullets-[],
        asteroids-Asteroids,
        ship-Ship,
        time-When,
        dim-vec2(Width, Height),
        bounds-rect(vec2(0, 0), vec2(Width, Height))
    ], State).

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
