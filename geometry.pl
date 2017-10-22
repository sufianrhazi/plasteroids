sign(Sign, vec2(Px, Py), vec2(Ax, Ay), vec2(Bx, By)) :-
    S = ((Px - Bx) * (Ay - By)) - ((Ax - Bx) * (Py - By)),
    (S < 0 -> Sign = true; Sign = false).

in_triangle(Pt, A, B, C) :-
    sign(Sign, Pt, A, B),
    sign(Sign, Pt, B, C),
    sign(Sign, Pt, C, A).

in_polygon_center(Pt, Center, [A,B]) :-
    in_triangle(Pt, Center, A, B).

in_polygon_center(Pt, Center, [A,B|Rest]) :-
    in_triangle(Pt, Center, A, B);
    in_polygon_center(Pt, Center, [B|Rest]).

polygon_bounds(Points, Bounds) :-
    maplist(vec2_x, Points, XS),
    maplist(vec2_y, Points, YS),
    min_list(XS, Left),
    max_list(XS, Right),
    min_list(YS, Top),
    max_list(YS, Bottom),
    Bounds = rect(vec2(Left, Top), vec2(Right, Bottom)).

polygon_lines([], []).

polygon_lines([_], []) :- !.

polygon_lines([A,B|Rest], [line(A,B)|Lines]) :-
    polygon_lines(A, [B|Rest], Lines).

polygon_lines(_, [], []) :- !.

polygon_lines(A, [B], [line(B,A)]) :- !.

polygon_lines(A, [B,C|Rest], [line(B,C)|Lines]) :-
    polygon_lines(A, [C|Rest], Lines).

line_eq(line(vec2(X1, Y1), vec2(X2, Y2)), Slope, YIntercept) :-
    % Y = Slope * X + YIntercept
    % YIntercept = Slope * X - Y
    % Slope * X2 - Y2 = Slope * X1 - Y1
    % Slope * X2 - Slope * X1 = Y2 - Y1 
    % Slope * (X2 - X1) = Y2 - Y1 
    % Slope = (Y2 - Y1) / (X2 - X1)
    DX is X2 - X1,
    DX = 0 -> (
        false
    ) ; (
        Slope is (Y2 - Y1) / (X2 - X1),
        YIntercept = Slope * X1 - Y1
    ).

line_cross(L1, L2, vec2(X, Y)) :-
    % Does not account for vertical lines
    line_eq(L1, A, C),
    line_eq(L2, B, D),
    A = B -> (
        false
    ) ; (
        X is (D - C) / (A - B),
        Y is A * X + C
    ).

ray_crossing(line(vec2(X1, Y1), vec2(X2, Y2)), vec2(X, Y), vec2(CrossX, CrossY)) :-
    (Y1 < Y, Y =< Y2; Y2 < Y, Y =< Y1),
    (X1 = X2) ->
        CrossX = X1,
        CrossY = Y
    ;
        Y1 = Y2 ->
            CrossX is min(X1, X2),
            CrossY = Y
            ;
            Slope is (Y2 - Y1) / (X2 - X1),
            Offset is Y1 - (Slope * X1),
            false. % need to figure out how to do this shit

in_polygon(Pt, Center, Points) :-
    polygon_lines(Points, Lines),
    findall(CrossPoint, (member(Line, Lines), ray_crossing(Line, Pt, CrossPoint)), CrossPoints).
    select(crosses(Y), Lines, Crosses),
    polygon_bounds(Points, Bounds),
    in_bounds(Bounds, Pt),
    in_polygon_center(Pt, Center, Points).

