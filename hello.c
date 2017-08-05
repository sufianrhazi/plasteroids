#include <SWI-Stream.h>
#include <SWI-Prolog.h>
#include <stdio.h>
#include <string.h>

PL_blob_t myblob;

int pl_test_release(atom_t a) {
    size_t len;
    PL_blob_t *type;
    void *data = PL_blob_data(a, &len, &type);
    int *num = data;
    printf("release myblob:%d:%p\n", *num, data);
    return TRUE;
}

int pl_test_compare(atom_t a, atom_t b) {
    size_t alen;
    PL_blob_t *atype;
    void *adata = PL_blob_data(a, &alen, &atype);
    size_t blen;
    PL_blob_t *btype;
    void *bdata = PL_blob_data(b, &blen, &btype);
    int *anum = adata;
    int *bnum = bdata;
    if (*anum < *bnum) {
        printf("compare myblob:%d:%p < myblob:%d:%p\n", *anum, adata, *bnum, bdata);
        return -1;
    } else if (*anum > *bnum) {
        printf("compare myblob:%d:%p > myblob:%d:%p\n", *anum, adata, *bnum, bdata);
        return 1;
    } else {
        printf("compare myblob:%d:%p == myblob:%d:%p\n", *anum, adata, *bnum, bdata);
        return 0;
    }
}

int pl_test_write(IOSTREAM *s, atom_t a, int flags) {
    size_t len;
    PL_blob_t *type;
    void *data = PL_blob_data(a, &len, &type);
    int *num = data;
    size_t bufflen = snprintf(NULL, 0, "myblob:%d:%p", *num, data);
    char *string = malloc(bufflen);
    snprintf(string, bufflen, "myblob:%d:%p", *num, data);
    Sfputs(string, s);
    free(string);
    PL_succeed;
}

void pl_test_acquire(atom_t a) {
    size_t len;
    PL_blob_t *type;
    void *data = PL_blob_data(a, &len, &type);
    int *num = data;
    printf("acquire myblob:%d:%p\n", *num, data);
}

static foreign_t pl_hello(term_t term) {
    char *str;
    size_t len;
    if (!PL_is_string(term) || !PL_get_string_chars(term, &str, &len)) {
        PL_fail;
    }
    printf("Hello, %s!\n", str);
    PL_succeed;
}

static foreign_t pl_make_myblob(term_t term) {
    static int num = 0;
    size_t size = sizeof(int);
    int *ptr = malloc(size);
    *ptr = ++num;
    if (PL_unify_blob(term, ptr, size, &myblob)) {
        printf("Used existing blob\n");
    } else {
        printf("Allocated a blob\n");
    }
    PL_succeed;
}

static foreign_t pl_drop_myblob(term_t term) {
    size_t len;
    PL_blob_t *type;
    if (PL_is_blob(term, &type)) {
        printf("It's a blob! %s\n", type->name);
    } else {
        printf("It's totally not a blob!\n");
        PL_succeed;
    }
    void *data;
    if (!PL_get_blob(term, &data, &len, &type)) {
        printf("It's totally not a blob!\n");
        PL_fail;
    };
    printf("free %s\n", type->name);
    if (strcmp(type->name, "myblob") == 0) {
        int *num = data;
        printf("free myblob:%d:%p\n", *num, data);
        free(num);
    } else {
        PL_succeed;
    }
    PL_succeed;
}

foreign_t pl_unify_test(term_t a) {
    term_t r = PL_new_term_ref();
    term_t g = PL_new_term_ref();
    term_t b = PL_new_term_ref();
    functor_t rgb_f = PL_new_functor(PL_new_atom("rgb"), 3);
    term_t rgb = PL_new_term_ref();
    PL_put_functor(rgb, rgb_f);
    fid_t fid = PL_open_foreign_frame();
    int result = PL_unify(rgb, a);
    if (!result) {
        PL_rewind_foreign_frame(fid);
        return FALSE;
    }
    PL_close_foreign_frame(fid);
    PL_get_arg(1, rgb, r);
    PL_get_arg(2, rgb, g);
    PL_get_arg(3, rgb, b);
    long rint = 1, gint = 2, bint = 3;
    if (PL_is_variable(r) && PL_is_variable(g) && PL_is_variable(b)) {
        printf("Need output\n");
        PL_put_integer(r, rint);
        PL_put_integer(g, gint);
        PL_put_integer(b, bint);
        PL_cons_functor(rgb, rgb_f, r, g, b);
        return PL_unify(rgb, a);
        printf("Wrote rgb: %ld, %ld, %ld\n", rint, gint, bint);
    } else if (PL_is_integer(r) && PL_is_integer(g) && PL_is_integer(b)) {
        printf("Got Input\n");
        PL_get_long(r, &rint);
        PL_get_long(g, &gint);
        PL_get_long(b, &bint);
        printf("Got rgb: %ld, %ld, %ld\n", rint, gint, bint);
    }
    return result;
}


install_t install() {
    printf("Installing hello\n");
    myblob.magic = PL_BLOB_MAGIC;
    myblob.flags = 0;
    myblob.name = "myblob";
    myblob.release = pl_test_release;
    myblob.compare = pl_test_compare;
    myblob.write = pl_test_write;
    myblob.acquire = pl_test_acquire;
    PL_register_foreign("hello", 1, pl_hello, 0);
    PL_register_foreign("make_myblob", 1, pl_make_myblob, 0);
    PL_register_foreign("drop_myblob", 1, pl_drop_myblob, 0);
    PL_register_foreign("unify_test", 1, pl_unify_test, 0);
}

install_t uninstall() {
    printf("Uninstalling hello\n");
}
