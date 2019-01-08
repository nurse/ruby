#include <ruby/ruby.h>
#include <stdbool.h>
#include "internal.h"
#include "timev.h"

static const char *weekday_names[] = {
    "sunday",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
};

static const char *month_names[] = {
    "january",
    "february",
    "march",
    "april",
    "may",
    "june",
    "july",
    "august",
    "september",
    "october",
    "november",
    "december",
};

static bool
scan_names(const char **restrict ss, const char **restrict names,
        int *restrict v) {
    const char **pp;
    for (pp = names; *pp; pp++) {
        const char *s = *ss;
        const char *p = *pp;
        if (p[0] == TOLOWER(s[0]) &&
            p[1] == TOLOWER(s[1]) &&
            p[2] == TOLOWER(s[2])) {
            p += 3;
            s += 3;
            *v = (int)(pp - names);
            do {
                if (!*s || *p != *s) {
                    *ss += 3;
                    return true;
                }
                p++;
                s++;
            } while (*p);
            *ss = s;
            return true;
        }
    }
    return false;
}

static bool
scan_ampm(const char **restrict ss, int *restrict vp) {
    const char *s = *ss;
    int v;
    switch (s[0]) {
      case 'a':
      case 'A':
        v = 0;
rest:
        switch (s[1]) {
          case 'm':
          case 'M':
            break;
          case '.':
            if (s[2] != 'm' || s[3] != '.') return false;
            break;
          default:
            return false;
        }
        break;
      case 'p':
      case 'P':
        v = 12;
        goto rest;
      default:
        return false;
    }
    *vp = v;
    *ss = s;
    return true;
}

static bool
parse_digits(const char **restrict ss, int width, int *vp) {
    int v;
    const char *s = *ss, *se = s + width;
    if (!ISDIGIT(*s)) return false;
    v = *s++ - '0';
    while (s < se && ISDIGIT(*s)) {
        v *= 10;
        v += *s++ - '0';
    }
    *ss = s;
    *vp = v;
    return true;
}

static bool
parse_digitsv(const char **ss, int width, VALUE *vp) {
    VALUE v = rb_int_parse_cstr(*ss, width, (char **)ss, NULL, 10, RB_INT_PARSE_SIGN);
    *vp = v;
    return !NIL_P(v);
}

struct strptime {
    VALUE tm_year;
    VALUE tm_cent;
    int tm_gmtoff; /* INT_MAX or other */
    int tm_yy;
    int tm_mon; /* 1..12 */
    int tm_mday;
    int tm_hour;
    int tm_hour12;
    int tm_min;
    int tm_sec;
    int tm_nsec;
    int tm_wday;
    int tm_yday; /* 0..366 */
    int tm_isdst;
    int tm_ampm; /* -1:unknown, 0:am, 12:pm */
};

/* `width` only affects only %C, %Y, and %N. */
static char *
ruby_strptime0(const char *restrict buf, const char *restrict format,
        struct strptime *restrict tm) {
    if (!format) return NULL;

    const char *p = format;
    const char *s = buf;
    while (*p) {
        int width = 0;
        switch (*p) {
          case '%':
                p++;
                break;
          case '\t':
          case '\n':
          case '\v':
          case '\f':
          case '\r':
          case ' ':
                while (ISSPACE(*s)) s++;
                p++;
                continue;
          default:
            if (*s++ != *p++) return NULL;
            continue;
        }

        if (ISDIGIT(*p)) {
            width = *p++ - '0';
            while (ISDIGIT(*p)) {
                width *= 10;
                width += *p++ - '0';
            }
        }

start:
        switch (*p++) {
          case '%':
            if (*s++ != '%') return NULL;
            break;
          case 'a':
          case 'A':
            if (!scan_names(&s, weekday_names, &tm->tm_wday))
                return NULL;
            break;
          case 'b':
          case 'B':
          case 'h':
            if (!scan_names(&s, month_names, &tm->tm_mon))
                return NULL;
            tm->tm_mon++;
            break;
          case 'c':
            if (!scan_names(&s, weekday_names, &tm->tm_wday))
                return NULL;
            while (ISSPACE(*s)) s++;
            if (!scan_names(&s, month_names, &tm->tm_mon))
                return NULL;
            tm->tm_mon++;
            while (ISSPACE(*s)) s++;
            if (!parse_digits(&s, 2, &tm->tm_mday)) return NULL;
            while (ISSPACE(*s)) s++;
            if (!parse_digits(&s, 2, &tm->tm_hour)) return NULL;
            if (*s++ != ':') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_min)) return NULL;
            if (*s++ != ':') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_sec)) return NULL;
            while (ISSPACE(*s)) s++;
            if (!parse_digitsv(&s, 4, &tm->tm_year)) return NULL;
            break;
          case 'C':
            if (*s == '+' || *s == '-') s++;
            if (!parse_digitsv(&s, width ? width : 2, &tm->tm_cent)) return NULL;
            break;
          case 'd':
          case 'e':
            if (!parse_digits(&s, 2, &tm->tm_mday)) return NULL;
            break;
          case 'D':
          case 'x':
            if (!parse_digits(&s, 2, &tm->tm_mon)) return NULL;
            if (*s++ != '/') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_mday)) return NULL;
            if (*s++ != '/') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_yy)) return NULL;
            break;
          case 'F':
            if (!parse_digitsv(&s, 4, &tm->tm_year)) return NULL;
            if (*s++ != ':') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_mon)) return NULL;
            if (*s++ != ':') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_mday)) return NULL;
            break;
          case 'g':
            /* TODO */
            abort();
          case 'G':
            /* TODO */
            abort();
          case 'H':
            if (!parse_digits(&s, 2, &tm->tm_hour)) return NULL;
            break;
          case 'I':
            if (!parse_digits(&s, 2, &tm->tm_hour12)) return NULL;
            break;
          case 'j':
            if (!parse_digits(&s, 3, &tm->tm_yday)) return NULL;
            break;
          case 'm':
            if (!parse_digits(&s, 2, &tm->tm_mon)) return NULL;
            break;
          case 'M':
            if (!parse_digits(&s, 2, &tm->tm_min)) return NULL;
            break;
          case 'n':
          case 't':
            while (ISSPACE(*s)) s++;
            break;
          case 'N':
            break;
          case 'p':
            scan_ampm(&s, &tm->tm_ampm);
          case 'r':
            /* TODO */
            abort();
          case 'R':
            if (!parse_digits(&s, 2, &tm->tm_hour)) return NULL;
            if (*s++ != ':') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_min)) return NULL;
            break;
          case 's':
            if (!parse_digits(&s, 2, &tm->tm_sec)) return NULL;
            break;
          case 'S':
            if (!parse_digits(&s, 2, &tm->tm_sec)) return NULL;
            break;
          case 'T':
          case 'X':
            if (!parse_digits(&s, 2, &tm->tm_hour)) return NULL;
            if (*s++ != ':') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_min)) return NULL;
            if (*s++ != ':') return NULL;
            if (!parse_digits(&s, 2, &tm->tm_sec)) return NULL;
            break;
          case 'u':
            if (!parse_digits(&s, 1, &tm->tm_wday)) return NULL;
            if (tm->tm_wday == 7) tm->tm_wday = 0;
            break;
          case 'U':
            /* TODO */
            abort();
          case 'w':
            if (!parse_digits(&s, 1, &tm->tm_wday)) return NULL;
            break;
          case 'W':
            /* TODO */
            abort();
          case 'y':
            if (!parse_digits(&s, 2, &tm->tm_yy)) return NULL;
            break;
          case 'Y':
            if (!parse_digitsv(&s, width ? width : 4, &tm->tm_year)) return NULL;
            break;
          case 'z':
            if (*s == 'Z') {
                tm->tm_gmtoff = INT_MIN;
                s++;
            }
            else {
                int sign = 1;
                int offset;
                if (*s == '+');
                else if (*s == '-') sign = -1;
                else return NULL;
                s++;
                if (!ISDIGIT(*s)) return NULL;
                offset = (*s++ - '0') * 36000;
                if (!ISDIGIT(*s)) return NULL;
                offset += (*s++ - '0') * 3600;
                if (s[0] == ':' && ISDIGIT(s[1]) && ISDIGIT(s[2])) {
                    offset += (s[1] - '0') * 600 + (s[2] - '0') * 60;
                    s += 3;
                }
                else if (ISDIGIT(s[0]) && ISDIGIT(s[1])) {
                    offset += (s[0] - '0') * 600 + (s[1] - '0') * 60;
                    s += 2;
                }
                tm->tm_gmtoff = offset * sign;
            }
            break;
          case 'Z':
            while (ISALPHA(*s)) s++;
            break;
          case 'E':
          case 'O':
          case '+':
            /* ignored */
            goto start;
          default:
            fprintf(stderr, "%d: unknown specifier '%c'\n", __LINE__, p[-1]);
            abort();
        }
    }
    return (char *)s;
}

static void
init_struct_strptime(struct strptime *tm) {
    tm->tm_year = Qnil;
    tm->tm_cent = Qnil;
    tm->tm_gmtoff = INT_MAX;
    tm->tm_yy = -1;
    tm->tm_mon = -1;
    tm->tm_mday = -1;
    tm->tm_hour = -1;
    tm->tm_hour12 = -1;
    tm->tm_min = -1;
    tm->tm_sec = -1;
    tm->tm_nsec = -1;
    tm->tm_wday = -1;
    tm->tm_yday = -1;
    tm->tm_isdst = -1;
    tm->tm_ampm = -1;
}

#define VTM_WDAY_INITVAL (7)
#define VTM_ISDST_INITVAL (3)
#define TIME_TZMODE_LOCALTIME 0
#define TIME_TZMODE_UTC 1
#define TIME_TZMODE_FIXOFF 2
#define TIME_TZMODE_UNINITIALIZED 3

int
ruby_strptime(const char *restrict str, const char *restrict format,
        struct vtm *restrict vtm) {
    struct strptime tm;
    int tzmode;
    init_struct_strptime(&tm);
    if (!ruby_strptime0(str, format, &tm)) {
        return TIME_TZMODE_UNINITIALIZED;
    }
    if (!NIL_P(tm.tm_year)) {
        vtm->year = tm.tm_year;
    }
    else if (tm.tm_yy != -1) {
        VALUE v;
        if (NIL_P(tm.tm_cent)) {
            v = INT2FIX(1900 + tm.tm_yy);
        }
        else if (FIXNUM_P(tm.tm_cent)) {
            v = rb_fix_mul_fix(tm.tm_cent, INT2FIX(100));
            v = rb_fix_plus_fix(v, INT2FIX(tm.tm_yy));
        }
        else {
            v = rb_big_mul(tm.tm_cent, rb_int2big(100));
            v = rb_big_plus(v, rb_int2big(tm.tm_yy));
        }
        vtm->year = v;
    }
    if (tm.tm_mon != -1) {
        vtm->mon = tm.tm_mon;
    }
    if (tm.tm_mday != -1) {
        vtm->mday = tm.tm_mday;
    }
    if (tm.tm_hour != -1) {
        vtm->hour = tm.tm_hour;
    }
    else if (tm.tm_hour12 != -1 && tm.tm_ampm != -1) {
        vtm->hour = tm.tm_hour12 + tm.tm_ampm;
    }
    if (tm.tm_min != -1) {
        vtm->min = tm.tm_min;
    }
    if (tm.tm_sec != -1) {
        vtm->sec = tm.tm_sec;
    }
    if (tm.tm_nsec != -1) {
        vtm->subsecx = INT2FIX(tm.tm_nsec);
    }
    else {
        vtm->subsecx = INT2FIX(0);
    }
    if (tm.tm_gmtoff == INT_MIN) {
        vtm->utc_offset = INT2FIX(0);
        tzmode = TIME_TZMODE_UTC;
    }
    else if (tm.tm_gmtoff == INT_MAX) {
        vtm->utc_offset = Qnil;
        tzmode = TIME_TZMODE_LOCALTIME;
    }
    else {
        vtm->utc_offset = INT2FIX(tm.tm_gmtoff);
        tzmode = TIME_TZMODE_FIXOFF;
    }
    vtm->wday = VTM_WDAY_INITVAL;
    vtm->isdst = VTM_ISDST_INITVAL;
    return tzmode;
}
