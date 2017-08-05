hoop(Label, B) :-
    write(Label),
    write("\n"),
    make_myblob(A),
    make_myblob(B),
    write(A),
    write("\n"),
    write(B),
    write("\n"),
    drop_myblob(A).

main(Argv) :-
    use_foreign_library(hello),
    unify_test(rgb(4,5,6)),
    unify_test(rgb(7,8,9)),
    unify_test(rgb(R,G,B)),
    write(rgb(R,G,B)), nl.

whatever(X) :-
    hello("world"),
    hoop("One:", X),
    hoop("Two:", Y),
    write("Comparison:\n"),
    compare(L, X, Y),
    drop_myblob(X),
    drop_myblob(Y).
