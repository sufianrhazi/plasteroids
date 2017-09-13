:- consult(vector).
:- consult(geometry).
:- use_foreign_library(sdl).

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
    Now = State.time,
    Now < Bullet.expiry.

update_bullet(State, Delta, Bullet, NewBullet) :-
    vec2_eval(Dest, Bullet.pos + scale(Delta, Bullet.vel)),
    Moved = Bullet.put(_{
        pos: Dest
    }),
    bullet_bounds(Moved, Bounds),
    ScreenBounds = State.bounds,
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
    (Ship.accel
        -> vec2_eval(Vel, Ship.vel + scale(Delta * 50, unit_rad(Ship.dir)))
        ;  Vel = Ship.vel),
    vec2_eval(Pos, Ship.pos + scale(Delta, Vel)),
    MovedShip = Ship.put(_{
        dir: Dir,
        vel: Vel,
        pos: Pos
    }),
    ship_bounds(MovedShip, Bounds),
    ScreenBounds = State.bounds,
    wrap_bounds(ScreenBounds, Bounds, Pos, WrappedPos),
    NextShip = MovedShip.put(pos, WrappedPos).

pair([A,B], A, B).

pairs(_, [], Tail, Tail).

pairs(A, [B|Bs], [Pair|Pairs], Tail) :-
    Pair = [A,B],
    pairs(A, Bs, Pairs, Tail).

cartesian_product([], _, Tail, Tail).

cartesian_product([A|As], Bs, Pairs, Tail) :-
    pairs(A, Bs, APairs, Tail),
    cartesian_product(As, Bs, Pairs, APairs),
    !.

cartesian_product(As, Bs, Pairs) :-
    cartesian_product(As, Bs, Pairs, []).

is_collision(Bullet, Asteroid) :-
    asteroid_polygon(Asteroid, Polygon),
    in_polygon(Bullet.pos, Asteroid.pos, Polygon).

split_asteroid(Asteroid, SplitAsteroids) :-
    NextSize is Asteroid.size / 2,
    (NextSize < 2 ->
        SplitAsteroids = []
    ;
        findall(NewAsteroid, (
            between(1, 4, _), 
            make_asteroid(NextSize, 0, 0, Temp),
            NewAsteroid = Temp.put(_{pos: Asteroid.pos})
        ), SplitAsteroids)
    ).

check_bullet_asteroid_collisions(Bullets, Asteroids, Nbs, Nas) :-
    cartesian_product(Bullets, Asteroids, Pairs),
    partition(apply(is_collision), Pairs, Hits, _),
    maplist(pair, Hits, HitBullets, HitAsteroids),
    subtract(Bullets, HitBullets, Nbs),
    subtract(Asteroids, HitAsteroids, LiveAsteroids),
    maplist(split_asteroid, HitAsteroids, SplitAsteroids),
    flatten(SplitAsteroids, NewAsteroids),
    append(LiveAsteroids, NewAsteroids, Nas).

update_state(_, quit, quit).

update_state(Delta, State, NextState) :-
    Ship = State.ship,
    Bullets = State.bullets,
    Asteroids = State.asteroids,
    check_bullet_asteroid_collisions(Bullets, Asteroids, HitBullets, HitAsteroids),
    update_ship(State, Delta, Ship, NextShip),
    include(bullet_alive(State), HitBullets, LiveBullets),
    maplist(update_bullet(State, Delta), LiveBullets, NextBullets),
    maplist(update_asteroid(State, Delta), HitAsteroids, NextAsteroids),
    NextState = State.put(_{
        bullets: NextBullets,
        asteroids: NextAsteroids,
        ship: NextShip
    }).

in_bounds(rect(vec2(L, T), vec2(R, B)), vec2(X, Y)) :-
    L =< X,
    X < R,
    T =< Y,
    Y < B.

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

handle_input(key("Right", down, initial), State, InputState) :-
    InputState = State.put(_{
        ship: State.ship.put(_{
            turn: clockwise
        })
    }).

handle_input(key("Right", up, initial), State, InputState) :-
    InputState = State.put(_{
        ship: State.ship.put(_{
            turn: no
        })
    }).

handle_input(key("Left", down, initial), State, InputState) :-
    InputState = State.put(_{
        ship: State.ship.put(_{
            turn: counterclockwise
        })
    }).

handle_input(key("Left", up, initial), State, InputState) :-
    InputState = State.put(_{
        ship: State.ship.put(_{turn: no})
    }).

handle_input(key("Up", down, initial), State, InputState) :-
    InputState = State.put(_{
        ship: State.ship.put(_{accel: true})
    }).

handle_input(key("Up", up, initial), State, InputState) :-
    InputState = State.put(_{
        ship: State.ship.put(_{accel: false})
    }).

handle_input(key("Space", down, initial), State, InputState) :-
    make_bullet(State.ship, Bullet),
    InputState = State.put(_{
        bullets: [Bullet|State.bullets]
    }).

handle_input(quit, _, quit).

handle_input(_, quit, quit).

handle_input(_, State, State).

draw_state(Renderer, State) :-
    sdl_render_color(Renderer, rgba(0, 0, 0, 255)),
    sdl_render_clear(Renderer),
    Now = State.time,
    Stars = State.stars,
    maplist(draw_star(Now, Renderer), Stars),
    Ship = State.ship,
    draw_ship(Renderer, Ship),
    Asteroids = State.asteroids,
    maplist(draw_asteroid(Renderer), Asteroids),
    Bullets = State.bullets,
    maplist(draw_bullet(Renderer), Bullets),
    sdl_render_present(Renderer).

process_input(quit, quit).

process_input(State, NextState) :-
    sdl_poll_events(Events),
    foldl(handle_input, Events, State, NextState).

event_loop(_, _, quit).

event_loop(Then, Renderer, State) :-
    draw_state(Renderer, State),
    process_input(State, InputState),
    get_time(Now),
    Delta is Now - Then,
    update_state(Delta, InputState, UpdatedState),
    event_loop(Now, Renderer, UpdatedState).

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

random_between(Low, Hi, Val) :-
    random(X),
    Val is floor((Hi + 1 - Low) * X + Low).

draw_star(Time, Renderer, Star) :-
    random_between(0, 100, Ra),
    random_between(0, 100, Ga),
    random_between(0, 100, Ba),
    rgb(Rb, Gb, Bb) = Star.color,
    R is Ra + Rb,
    G is Ga + Gb,
    B is Ba + Bb,
    fastsin(Time * Star.period, X),
    Alpha is 205 + round(Star.intensity * X),
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


draw_polygon(Renderer, [A,B|Rest]) :-
    sdl_draw(Renderer, line(A, B)),
    draw_polygon(Renderer, A, [B|Rest]).

draw_polygon(Renderer, Initial, [End]) :-
    sdl_draw(Renderer, line(End, Initial)).

draw_polygon(Renderer, Terminal, [P,G|T]) :-
    sdl_draw(Renderer, line(P, G)),
    draw_polygon(Renderer, Terminal, [G|T]),
    !.

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

polygon_bounds(Points, Bounds) :-
    maplist(vec2_x, Points, XS),
    maplist(vec2_y, Points, YS),
    min_list(XS, Left),
    max_list(XS, Right),
    min_list(YS, Top),
    max_list(YS, Bottom),
    Bounds = rect(vec2(Left, Top), vec2(Right, Bottom)).

asteroid_polygon(Asteroid, Points) :-
    maplist(asteroid_point_vec2(Asteroid.rot, Asteroid.size, Asteroid.pos), Asteroid.points, Points).

asteroid_bounds(Asteroid, Bounds) :-
    asteroid_polygon(Asteroid, Points),
    polygon_bounds(Points, Bounds).

asteroid_point_vec2(Rot, Size, Pos, Polar, Vec) :-
    polar_eval(RotatedScaled, (Polar + polar(0, Rot)) * scalar(Size)),
    vec2_polar(RotatedScaledPos, RotatedScaled),
    vec2_eval(Vec, Pos + RotatedScaledPos).

draw_asteroid(Renderer, Asteroid) :-
    asteroid_polygon(Asteroid, Points),
    draw_polygon(Renderer, Points).

update_asteroid(State, Delta, Asteroid, NextAsteroid) :-
    vec2_polar(Vel, Asteroid.vel),
    vec2_eval(NextPos, scale(Delta, Vel) + Asteroid.pos),
    NextRot is Delta * Asteroid.angvel + Asteroid.rot,
    ScreenBounds = State.bounds,
    asteroid_bounds(Asteroid, AsteroidBounds),
    wrap_bounds(ScreenBounds, AsteroidBounds, NextPos, WrapPos),
    NextAsteroid = Asteroid.put(_{
        pos: WrapPos,
        rot: NextRot
    }).

initial_state(State) :-
    Width = 640,
    Height = 480,
    findall(Star, (between(0, 400, _), initial_star(Star, Width, Height)), Stars),
    initial_ship(Ship, Width, Height),
    findall(Asteroid, (between(1, 5, _), make_asteroid(30, Width, Height, Asteroid)), Asteroids),
    get_time(When),
    State = state{
        stars: Stars,
        bullets: [],
        asteroids: Asteroids,
        ship: Ship,
        time: When,
        dim: vec2(Width, Height),
        bounds: rect(vec2(0, 0), vec2(Width, Height))
    }.

main(_) :-
    sdl_init([video]),
    initial_state(State),
    vec2(Width, Height) = State.dim,
    sdl_create_window("SDL Test", Width, Height, [], Window),
    sdl_create_renderer(Window, [software], Renderer),
    sdl_render_blendmode(Renderer, alpha),
    get_time(Now),
    once(event_loop(Now, Renderer, State)),
    sdl_destroy_renderer(Renderer),
    sdl_destroy_window(Window),
    sdl_terminate.
