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

in_polygon(Pt, Center, Points) :-
    polygon_bounds(Points, Bounds),
    in_bounds(Bounds, Pt),
    in_polygon_center(Pt, Center, Points).
