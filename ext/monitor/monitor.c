#include "ruby/ruby.h"

ID id_mon_owner, id_mon_count, id_mon_mutex;

/*
 *  call-seq:
 *     obj.mon_enter   -> nil
 *
 *  Enters exclusive section.
 */
VALUE
mon_enter(VALUE self) {
    VALUE th = rb_thread_current();
    VALUE mon_owner = rb_ivar_get(self, id_mon_owner);
    if (th == mon_owner) {
        long mon_count = FIX2LONG(rb_ivar_get(self, id_mon_count));
        rb_ivar_set(self, id_mon_count, LONG2FIX(mon_count + 1L));
    }
    else {
        VALUE mon_mutex = rb_ivar_get(self, id_mon_mutex);
        rb_mutex_lock(mon_mutex);
        rb_ivar_set(self, id_mon_owner, th);
        rb_ivar_set(self, id_mon_count, INT2FIX(1));
    }
    return Qnil;
}

/*
 *  call-seq:
 *     obj.mon_exit   -> nil
 *
 *  Leaves exclusive section.
 */
VALUE
mon_exit(VALUE self) {
    VALUE th = rb_thread_current();
    VALUE mon_owner = rb_ivar_get(self, id_mon_owner);
    if (th == mon_owner) {
        long mon_count = FIX2LONG(rb_ivar_get(self, id_mon_count));
        mon_count--;
        rb_ivar_set(self, id_mon_count, LONG2FIX(mon_count));
        if (mon_count == 0) {
            VALUE mon_mutex = rb_ivar_get(self, id_mon_mutex);
            rb_ivar_set(self, id_mon_owner, Qnil);
            rb_mutex_unlock(mon_mutex);
        }
    }
    else {
        rb_raise(rb_eThreadError, "current thread not owner");
    }
    return Qnil;
}

void
Init_monitor(void)
{
    VALUE mMonitorMixin = rb_define_module("MonitorMixin");
    rb_define_method(mMonitorMixin, "mon_enter", mon_enter, 0);
    rb_define_method(mMonitorMixin, "mon_exit", mon_exit, 0);

    id_mon_owner = rb_intern_const("@mon_owner");
    id_mon_count = rb_intern_const("@mon_count");
    id_mon_mutex = rb_intern_const("@mon_mutex");
}
