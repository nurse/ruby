#include "internal.h"

#ifdef true
static VALUE
test_bool(VALUE klass)
{
    if (!FIXABLE(true)) return LONG2FIX(__LINE__);
    if (!FIXABLE(false)) return LONG2FIX(__LINE__);
    return Qnil;
}
#endif

static VALUE
test_float(VALUE klass)
{
    if (FIXABLE((float)NAN)) return LONG2FIX(__LINE__);
    if (FIXABLE((float)INFINITY)) return LONG2FIX(__LINE__);
    if (!FIXABLE(0.0f)) return LONG2FIX(__LINE__);
    /* if (!FIXABLE(FIXNUM_MAX-1.0f)) return LONG2FIX(__LINE__); */
    /* if (!FIXABLE(FIXNUM_MAX+0.0f)) return LONG2FIX(__LINE__); */
    /* if (!FIXABLE(FIXNUM_MAX+0.9f)) return LONG2FIX(__LINE__); */
    if (FIXABLE(FIXNUM_MAX+1.0f)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MIN-0.0f)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MIN-0.9f)) return LONG2FIX(__LINE__);
    /* if (FIXABLE(FIXNUM_MIN-1.0f)) return LONG2FIX(__LINE__); */
    return Qnil;
}
static VALUE
test_double(VALUE klass)
{
    if (FIXABLE((double)NAN)) return LONG2FIX(__LINE__);
    if (FIXABLE((double)INFINITY)) return LONG2FIX(__LINE__);
    if (!FIXABLE(0.0)) return LONG2FIX(__LINE__);
    /* if (!FIXABLE(FIXNUM_MAX-1.0)) return LONG2FIX(__LINE__); */
    /* if (!FIXABLE(FIXNUM_MAX+0.0)) return LONG2FIX(__LINE__); */
    /* if (!FIXABLE(FIXNUM_MAX+0.9)) return LONG2FIX(__LINE__); */
    if (FIXABLE(FIXNUM_MAX+1.0)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MIN+1.0)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MIN-0.0)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MIN-0.9)) return LONG2FIX(__LINE__);
    /* if (FIXABLE(FIXNUM_MIN-1.0)) return LONG2FIX(__LINE__); */
    return Qnil;
}
static VALUE
test_long_double(VALUE klass)
{
    if (FIXABLE((long double)NAN)) return LONG2FIX(__LINE__);
    if (FIXABLE((long double)INFINITY)) return LONG2FIX(__LINE__);
    if (!FIXABLE(0.0L)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MAX-1.0L)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MAX+0.0L)) return LONG2FIX(__LINE__);
    /* if (!FIXABLE(FIXNUM_MAX+0.9L)) return LONG2FIX(__LINE__); */
    if (FIXABLE(FIXNUM_MAX+1.0L)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MIN+1.0L)) return LONG2FIX(__LINE__);
    if (!FIXABLE(FIXNUM_MIN-0.0L)) return LONG2FIX(__LINE__);
    if (FIXABLE(FIXNUM_MIN-0.9L)) return LONG2FIX(__LINE__);
    if (FIXABLE(FIXNUM_MIN-1.0L)) return LONG2FIX(__LINE__);
    return Qnil;
}
static VALUE
test_long(VALUE klass)
{
    if (!FIXABLE(0L)) return LONG2FIX(__LINE__);
    if (!FIXABLE((long)FIXNUM_MAX-1)) return LONG2FIX(__LINE__);
    if (!FIXABLE((long)FIXNUM_MAX)) return LONG2FIX(__LINE__);
    if (FIXABLE((long)FIXNUM_MAX+1.0)) return LONG2FIX(__LINE__);
    if (!FIXABLE((long)FIXNUM_MIN+1.0)) return LONG2FIX(__LINE__);
    if (!FIXABLE((long)FIXNUM_MIN)) return LONG2FIX(__LINE__);
    if (FIXABLE((long)FIXNUM_MIN-1)) return LONG2FIX(__LINE__);
    return Qnil;
}
static VALUE
test_ulong(VALUE klass)
{
    if (!FIXABLE(0UL)) return LONG2FIX(__LINE__);
    if (!FIXABLE((unsigned long)FIXNUM_MAX-1)) return LONG2FIX(__LINE__);
    if (!FIXABLE((unsigned long)FIXNUM_MAX)) return LONG2FIX(__LINE__);
    if (FIXABLE((unsigned long)FIXNUM_MAX+1.0)) return LONG2FIX(__LINE__);
    return Qnil;
}
static VALUE
test_int128(VALUE klass)
{
#ifdef HAVE_INT128_T
    if (!FIXABLE((int128_t)0)) return LONG2FIX(__LINE__);
    if (!FIXABLE((int128_t)FIXNUM_MAX-1)) return LONG2FIX(__LINE__);
    if (!FIXABLE((int128_t)FIXNUM_MAX)) return LONG2FIX(__LINE__);
    if (FIXABLE((int128_t)FIXNUM_MAX+1.0)) return LONG2FIX(__LINE__);
    if (!FIXABLE((int128_t)FIXNUM_MIN+1.0)) return LONG2FIX(__LINE__);
    if (!FIXABLE((int128_t)FIXNUM_MIN)) return LONG2FIX(__LINE__);
    if (FIXABLE((int128_t)FIXNUM_MIN-1)) return LONG2FIX(__LINE__);
#endif
    return Qnil;
}
static VALUE
test_uint128(VALUE klass)
{
#ifdef HAVE_INT128_T
    if (!FIXABLE((uint128_t)0)) return LONG2FIX(__LINE__);
    if (!FIXABLE((uint128_t)FIXNUM_MAX-1)) return LONG2FIX(__LINE__);
    if (!FIXABLE((uint128_t)FIXNUM_MAX)) return LONG2FIX(__LINE__);
    if (FIXABLE((uint128_t)FIXNUM_MAX+1.0)) return LONG2FIX(__LINE__);
#endif
    return Qnil;
}

void
Init_fixable(VALUE klass)
{
    rb_define_singleton_method(klass, "test_bool", test_bool, 0);
    rb_define_singleton_method(klass, "test_float", test_float, 0);
    rb_define_singleton_method(klass, "test_double", test_double, 0);
    rb_define_singleton_method(klass, "test_long_double", test_long_double, 0);
    rb_define_singleton_method(klass, "test_long", test_long, 0);
    rb_define_singleton_method(klass, "test_ulong", test_ulong, 0);
    rb_define_singleton_method(klass, "test_int128", test_int128, 0);
    rb_define_singleton_method(klass, "test_uint128", test_uint128, 0);
}
