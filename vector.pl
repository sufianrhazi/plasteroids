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
