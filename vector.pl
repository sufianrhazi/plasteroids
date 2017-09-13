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
    fastcos(R, X),
    fastsin(R, Y).

vec2_polar(vec2(X, Y), polar(R, Phi)) :-
    fastcos(Phi, A),
    fastsin(Phi, B),
    X is R * A,
    Y is R * B.

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

fastsin(T, X) :-
    D is round(T * 180 / pi) mod 360,
    sintab(D, X).

fastcos(T, X) :-
    fastsin(T + pi / 2, X).

makesintab :-
    findall(X, (
        between(0, 359, N),
        R is N * pi / 180,
        X is sin(R),
        assert(sintab(N, X))
    ), _).

:- makesintab.

