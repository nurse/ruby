#include "ruby/ruby.h"

VALUE rb_cMonitorCore;

#define GetMonitorCoreVal(obj, tobj) ((tobj) = get_monitor_core_val(obj))
#define MONITOR_CORE_INIT_P(tobj) ((tobj)->mutex)

struct monitor_core {
    VALUE owner;
    VALUE mutex;
    int count;
};

static void
monitor_core_mark(void *ptr)
{
    struct monitor_core *tobj = ptr;
    rb_gc_mark(tobj->owner);
    rb_gc_mark(tobj->mutex);
}

static size_t
monitor_core_memsize(const void *tobj)
{
    return sizeof(struct monitor_core);
}

static const rb_data_type_t monitor_core_data_type = {
    "monitor_core",
    {
	monitor_core_mark, NULL, monitor_core_memsize,
    },
#ifdef RUBY_TYPED_FREE_IMMEDIATELY
    0,
    0,
    RUBY_TYPED_FREE_IMMEDIATELY
#endif
};

static VALUE
monitor_core_s_alloc(VALUE klass)
{
    VALUE obj;
    struct monitor_core *tobj;

    obj = TypedData_Make_Struct(klass, struct monitor_core,
				&monitor_core_data_type, tobj);

    return obj;
}

static struct monitor_core *
get_monitor_core_val(VALUE obj)
{
    struct monitor_core *tobj;
    TypedData_Get_Struct(obj, struct monitor_core, &monitor_core_data_type,
			 tobj);
    if (!MONITOR_CORE_INIT_P(tobj)) {
	rb_raise(rb_eTypeError, "uninitialized %" PRIsVALUE, rb_obj_class(obj));
    }
    return tobj;
}

/*
 * @overload new
 *
 * returns MonitorCore object
 */
static VALUE
monitor_core_init(VALUE self)
{
    struct monitor_core *tobj;
    TypedData_Get_Struct(self, struct monitor_core, &monitor_core_data_type, tobj);
    tobj->owner = Qnil;
    tobj->mutex = rb_mutex_new();
    tobj->count = 0;
    return self;
}

/*
 *  call-seq:
 *     monitor_core.mon_try_enter   -> nil
 *
 * Attempts to enter exclusive section.  Returns +false+ if lock fails.
 */
VALUE
mon_try_enter(VALUE self) {
    struct monitor_core *tobj;
    VALUE th = rb_thread_current();
    GetMonitorCoreVal(self, tobj);
    if (th == tobj->owner) {
        tobj->count++;
    }
    else {
        VALUE locked = rb_mutex_trylock(tobj->mutex);
        if (!RTEST(locked)) {
            return Qfalse;
        }
        tobj->owner = th;
        tobj->count = 1;
    }
    return Qtrue;
}

/*
 *  call-seq:
 *     monitor_core.mon_enter   -> nil
 *
 *  Enters exclusive section.
 */
VALUE
mon_enter(VALUE self) {
    struct monitor_core *tobj;
    VALUE th = rb_thread_current();
    GetMonitorCoreVal(self, tobj);
    if (th == tobj->owner) {
        tobj->count++;
    }
    else {
        rb_mutex_lock(tobj->mutex);
        tobj->owner = th;
        tobj->count = 1;
    }
    return Qnil;
}

/*
 *  call-seq:
 *     monitor_core.mon_exit   -> nil
 *
 *  Leaves exclusive section.
 */
VALUE
mon_exit(VALUE self) {
    struct monitor_core *tobj;
    VALUE th = rb_thread_current();
    GetMonitorCoreVal(self, tobj);
    if (th == tobj->owner) {
        tobj->count--;
        if (tobj->count == 0) {
            tobj->owner = Qnil;
            rb_mutex_unlock(tobj->mutex);
        }
    }
    else {
        rb_raise(rb_eThreadError, "current thread not owner");
    }
    return Qnil;
}

/*
 *  call-seq:
 *     monitor_core.mon_locked?   -> nil
 *
 * Returns true if this monitor is locked by any thread
 */
VALUE
mon_locked_p(VALUE self) {
    struct monitor_core *tobj;
    GetMonitorCoreVal(self, tobj);
    return rb_mutex_locked_p(tobj->mutex);
}

/*
 *  call-seq:
 *     monitor_core.mon_owned?   -> nil
 *
 * Returns true if this monitor is locked by current thread.
 */
VALUE
mon_owned_p(VALUE self) {
    struct monitor_core *tobj;
    VALUE th = rb_thread_current();
    GetMonitorCoreVal(self, tobj);
    return rb_mutex_locked_p(tobj->mutex) && th == tobj->owner;
}

/*
 *  call-seq:
 *     monitor_core.mon_check_owner   -> nil
 *
 */
VALUE
mon_check_owner(VALUE self) {
    struct monitor_core *tobj;
    VALUE th = rb_thread_current();
    GetMonitorCoreVal(self, tobj);
    if (th != tobj->owner) {
        rb_raise(rb_eThreadError, "current thread not owner");
    }
    return Qnil;
}

/*
 *  call-seq:
 *     monitor_core.mon_enter_for_cond(count)   -> integer
 *
 */
VALUE
mon_enter_for_cond(VALUE self, VALUE count) {
    struct monitor_core *tobj;
    VALUE th = rb_thread_current();
    GetMonitorCoreVal(self, tobj);
    tobj->owner = th;
    tobj->count = FIX2INT(count);
    return count;
}

/*
 *  call-seq:
 *     monitor_core.mon_exit_for_cond   -> integer
 *
 */
VALUE
mon_exit_for_cond(VALUE self) {
    struct monitor_core *tobj;
    int count;
    GetMonitorCoreVal(self, tobj);
    count = tobj->count;
    tobj->owner = Qnil;
    tobj->count = 0;
    return INT2FIX(count);
}

/*
 *  call-seq:
 *     monitor_core.inspect   -> string
 *
 */
VALUE
mon_inspect(VALUE self) {
    VALUE ret;
    struct monitor_core *tobj;
    GetMonitorCoreVal(self, tobj);
    //VALUE cname = rb_class_name(CLASS_OF(obj));
    ret = rb_sprintf("#<%s:%p mutex:%"PRIsVALUE" owner:%"PRIsVALUE" count:%d>",
            rb_obj_classname(self), (void*)self,
            tobj->mutex, tobj->owner, tobj->count);
    //str = rb_sprintf("#<%"PRIsVALUE":%p>", cname, (void*)obj);
    return ret;
}

void
Init_monitor(void)
{
    VALUE mMonitorMixin = rb_define_module("MonitorMixin");
    VALUE rb_cMonitorCore = rb_define_class_under(mMonitorMixin, "MonitorCore", rb_cObject);
    rb_define_alloc_func(rb_cMonitorCore, monitor_core_s_alloc);
    rb_define_method(rb_cMonitorCore, "initialize", monitor_core_init, 0);
    rb_define_method(rb_cMonitorCore, "mon_try_enter", mon_try_enter, 0);
    rb_define_method(rb_cMonitorCore, "mon_enter", mon_enter, 0);
    rb_define_method(rb_cMonitorCore, "mon_exit", mon_exit, 0);
    rb_define_method(rb_cMonitorCore, "mon_locked?", mon_locked_p, 0);
    rb_define_method(rb_cMonitorCore, "mon_owned?", mon_owned_p, 0);
    rb_define_method(rb_cMonitorCore, "inspect", mon_inspect, 0);
    rb_define_private_method(rb_cMonitorCore, "mon_check_owner", mon_check_owner, 0);
    rb_define_private_method(rb_cMonitorCore, "mon_enter_for_cond", mon_enter_for_cond, 1);
    rb_define_private_method(rb_cMonitorCore, "mon_exit_for_cond", mon_exit_for_cond, 0);
}
