#
#
# DO NOT EDIT THIS FILE, IT'S AUTOGENERATED FROM XS MODULES AND WILL BE UPDATED AUTOMATICALLY
#
#
package B {
sub CLONE;
sub address;
sub amagic_generation;
sub begin_av;
sub cast_I32;
sub cchar;
sub check_av;
sub comppadlist;
sub cstring;
sub curstash;
sub defstash;
sub diehook;
sub dowarn;
sub end_av;
sub formfeed;
sub hash;
sub inc_gv;
sub init_av;
sub main_cv;
sub main_root;
sub main_start;
sub minus_c;
sub opnumber;
sub perlstring;
sub ppname;
sub regex_padav;
sub save_BEGINs;
sub sub_generation;
sub sv_no;
sub sv_undef;
sub sv_yes;
sub svref_2object;
sub threadsv_names;
sub unitcheck_av;
sub walkoptree;
sub walkoptree_debug;
sub warnhook;
}
package B::AV {
sub ARRAY;
sub ARRAYelt;
sub FILL;
sub MAX;
}
package B::BINOP {
sub last;
}
package B::BM {
sub PREVIOUS;
sub RARE;
sub TABLE;
sub USEFUL;
}
package B::COP {
sub arybase;
sub cop_seq;
sub file;
sub filegv;
sub hints;
sub hints_hash;
sub io;
sub label;
sub line;
sub stash;
sub stashoff;
sub stashpv;
sub warnings;
}
package B::CV {
sub CONST;
sub CvFLAGS;
sub DEPTH;
sub FILE;
sub GV;
sub HSCXT;
sub NAME_HEK;
sub OUTSIDE;
sub OUTSIDE_SEQ;
sub PADLIST;
sub ROOT;
sub START;
sub STASH;
sub XSUB;
sub XSUBANY;
sub const_sv;
}
package B::Deparse {
sub main_cv;
sub main_root;
sub main_start;
sub opnumber;
sub perlstring;
sub svref_2object;
}
package B::FM {
sub LINES;
}
package B::GV {
sub AV;
sub CV;
sub CVGEN;
sub EGV;
sub FILE;
sub FILEGV;
sub FORM;
sub GP;
sub GPFLAGS;
sub GvFLAGS;
sub GvREFCNT;
sub HV;
sub IO;
sub LINE;
sub NAME;
sub STASH;
sub SV;
sub isGV_with_GP;
sub is_empty;
}
package B::HE {
sub HASH;
sub SVKEY_force;
sub VAL;
}
package B::HV {
sub ARRAY;
sub FILL;
sub KEYS;
sub MAX;
sub NAME;
sub RITER;
}
package B::INVLIST {
sub array_len;
sub get_invlist_array;
sub is_offset;
sub prev_index;
}
package B::IO {
sub BOTTOM_GV;
sub BOTTOM_NAME;
sub FMT_GV;
sub FMT_NAME;
sub IoFLAGS;
sub IoTYPE;
sub IsSTD;
sub LINES;
sub LINES_LEFT;
sub PAGE;
sub PAGE_LEN;
sub TOP_GV;
sub TOP_NAME;
}
package B::IV {
sub IV;
sub IVX;
sub RV;
sub UVX;
sub needs64bits;
sub packiv;
}
package B::LISTOP {
sub children;
}
package B::LOGOP {
sub other;
}
package B::LOOP {
sub lastop;
sub nextop;
sub redoop;
}
package B::MAGIC {
sub FLAGS;
sub LENGTH;
sub MOREMAGIC;
sub OBJ;
sub PRIVATE;
sub PTR;
sub REGEX;
sub TYPE;
sub precomp;
}
package B::METHOP {
sub first;
sub meth_sv;
sub rclass;
}
package B::NV {
sub NV;
sub NVX;
}
package B::OP {
sub desc;
sub flags;
sub folded;
sub moresib;
sub name;
sub next;
sub oplist;
sub opt;
sub parent;
sub ppaddr;
sub private;
sub savefree;
sub sibling;
sub size;
sub slabbed;
sub spare;
sub static;
sub targ;
sub type;
}
package B::PADLIST {
sub ARRAY;
sub ARRAYelt;
sub MAX;
sub NAMES;
sub REFCNT;
sub id;
sub outid;
}
package B::PADNAME {
sub COP_SEQ_RANGE_HIGH;
sub COP_SEQ_RANGE_LOW;
sub FLAGS;
sub LEN;
sub OURSTASH;
sub PARENT_FAKELEX_FLAGS;
sub PARENT_PAD_INDEX;
sub PROTOCV;
sub PV;
sub PVX;
sub REFCNT;
sub SvSTASH;
sub TYPE;
}
package B::PADNAMELIST {
sub ARRAY;
sub ARRAYelt;
sub MAX;
sub REFCNT;
}
package B::PADOP {
sub gv;
sub padix;
sub sv;
}
package B::PMOP {
sub code_list;
sub pmflags;
sub pmoffset;
sub pmregexp;
sub pmreplroot;
sub pmreplstart;
sub pmstash;
sub pmstashpv;
sub precomp;
sub reflags;
}
package B::PV {
sub CUR;
sub LEN;
sub PV;
sub PVBM;
sub PVX;
sub RV;
sub as_string;
}
package B::PVLV {
sub TARG;
sub TARGLEN;
sub TARGOFF;
sub TYPE;
}
package B::PVMG {
sub MAGIC;
sub SvSTASH;
}
package B::PVOP {
sub pv;
}
package B::REGEXP {
sub REGEX;
sub compflags;
sub precomp;
sub qr_anoncv;
}
package B::RHE {
sub HASH;
}
package B::SV {
sub FLAGS;
sub MAGICAL;
sub POK;
sub REFCNT;
sub ROK;
sub SvTYPE;
sub object_2svref;
}
package B::SVOP {
sub gv;
sub sv;
}
package B::UNOP {
sub first;
}
package B::UNOP_AUX {
sub aux_list;
sub string;
}
package Carp {
sub _maybe_isa;
sub downgrade;
sub is_utf8;
}
package Class::XSAccessor {
sub __entersub_optimized__() ;
sub _newxs_compat_accessor;
sub _newxs_compat_setter;
sub accessor;
sub array_accessor;
sub array_accessor_init;
sub array_setter;
sub array_setter_init;
sub chained_accessor;
sub chained_setter;
sub constant_false;
sub constant_true;
sub constructor;
sub defined_predicate;
sub exists_predicate;
sub getter;
sub lvalue_accessor;
sub newxs_accessor;
sub newxs_boolean;
sub newxs_constructor;
sub newxs_defined_predicate;
sub newxs_exists_predicate;
sub newxs_getter;
sub newxs_lvalue_accessor;
sub newxs_predicate;
sub newxs_setter;
sub newxs_test;
sub setter;
sub test;
}
package Class::XSAccessor::Array {
sub accessor;
sub chained_accessor;
sub chained_setter;
sub constructor;
sub getter;
sub lvalue_accessor;
sub newxs_accessor;
sub newxs_constructor;
sub newxs_getter;
sub newxs_lvalue_accessor;
sub newxs_predicate;
sub newxs_setter;
sub predicate;
sub setter;
}
package Config {
sub AUTOLOAD;
}
package Cwd {
sub CLONE;
sub abs_path;
sub fastcwd;
sub getcwd;
sub realpath;
}
package DateTime {
sub _accumulated_leap_seconds($$) ;
sub _day_has_leap_second($$) ;
sub _day_length($$) ;
sub _is_leap_year($$) ;
sub _normalize_leap_seconds($$$) ;
sub _normalize_tai_seconds($$$) ;
sub _rd2ymd($$;$) ;
sub _seconds_as_components($$;$$) ;
sub _time_as_seconds($$$$) ;
sub _ymd2rd($$$$) ;
}
package Devel::Caller {
sub _context_cv;
sub _context_op;
}
package Devel::LexAlias {
sub _lexalias;
}
package Devel::StackTrace {
sub blessed($) ;
}
package DynaLoader {
sub CLONE;
sub boot_DynaLoader;
sub dl_error;
sub dl_find_symbol;
sub dl_install_xsub;
sub dl_load_file;
sub dl_undef_symbols;
sub dl_unload_file;
}
package Email::Address::XS {
sub compose_address;
sub format_email_groups;
sub is_obj;
sub parse_email_groups;
sub split_address;
}
package Encode {
sub _utf8_off($) ;
sub _utf8_on($) ;
sub bytes2str($$;$) ;
sub decode($$;$) ;
sub decode_utf8($;$) ;
sub encode($$;$) ;
sub encode_utf8($) ;
sub from_to($$$;$) ;
sub is_utf8($;$) ;
sub onBOOT() ;
sub str2bytes($$;$) ;
}
package Encode::XS {
sub cat_decode;
sub decode;
sub encode;
sub mime_name;
sub name;
sub needs_lines;
sub perlio_ok;
sub renew;
sub renewed;
}
package Encode::utf8 {
sub decode;
sub encode;
}
package Eval::Closure {
sub reftype($) ;
}
package Exception::Class {
sub blessed($) ;
sub reftype($) ;
}
package Exception::Class::Base {
sub blessed($) ;
}
package Fcntl {
sub AUTOLOAD;
sub FCREAT() ;
sub FDEFER() ;
sub FDSYNC() ;
sub FEXCL() ;
sub FLARGEFILE() ;
sub FRSYNC() ;
sub FSYNC() ;
sub FTRUNC() ;
sub F_ALLOCSP() ;
sub F_ALLOCSP64() ;
sub F_COMPAT() ;
sub F_DUP2FD() ;
sub F_FREESP() ;
sub F_FREESP64() ;
sub F_FSYNC() ;
sub F_FSYNC64() ;
sub F_NODNY() ;
sub F_POSIX() ;
sub F_RDACC() ;
sub F_RDDNY() ;
sub F_RWACC() ;
sub F_RWDNY() ;
sub F_SHARE() ;
sub F_UNSHARE() ;
sub F_WRACC() ;
sub F_WRDNY() ;
sub O_ALIAS() ;
sub O_ALT_IO() ;
sub O_DEFER() ;
sub O_EVTONLY() ;
sub O_EXLOCK() ;
sub O_IGNORE_CTTY() ;
sub O_NOINHERIT() ;
sub O_NOLINK() ;
sub O_NOSIGPIPE() ;
sub O_NOTRANS() ;
sub O_RANDOM() ;
sub O_RAW() ;
sub O_RSRC() ;
sub O_SEQUENTIAL() ;
sub O_SHLOCK() ;
sub O_SYMLINK() ;
sub O_TEMPORARY() ;
sub O_TTY_INIT() ;
sub S_ENFMT() ;
sub S_IFMT;
sub S_IFWHT() ;
sub S_IMODE;
sub S_ISBLK;
sub S_ISCHR;
sub S_ISDIR;
sub S_ISFIFO;
sub S_ISLNK;
sub S_ISREG;
sub S_ISSOCK;
sub S_ISTXT() ;
}
package File::Find {
sub is_tainted($) ;
}
package File::ShareDir {
sub _STRING($) ;
sub firstres(&@) ;
}
package File::Spec::Unix {
sub _fn_canonpath;
sub _fn_catdir;
sub _fn_catfile;
sub canonpath;
sub catdir;
sub catfile;
}
package Hash::StoredIterator {
sub hash_get_iterator;
sub hash_init_iterator;
sub hash_set_iterator;
}
package Internals {
sub SvREADONLY(\[$%@];$) ;
sub SvREFCNT(\[$%@];$) ;
sub V;
sub getcwd() ;
sub hv_clear_placeholders(\%) ;
}
package JSON::XS {
sub CLONE;
sub DESTROY;
sub allow_blessed;
sub allow_nonref;
sub allow_tags;
sub allow_unknown;
sub ascii;
sub boolean_values;
sub canonical;
sub convert_blessed;
sub decode;
sub decode_json($) ;
sub decode_prefix;
sub encode;
sub encode_json($) ;
sub filter_json_object;
sub filter_json_single_key_object;
sub get_allow_blessed;
sub get_allow_nonref;
sub get_allow_tags;
sub get_allow_unknown;
sub get_ascii;
sub get_boolean_values;
sub get_canonical;
sub get_convert_blessed;
sub get_indent;
sub get_latin1;
sub get_max_depth;
sub get_max_size;
sub get_relaxed;
sub get_shrink;
sub get_space_after;
sub get_space_before;
sub get_utf8;
sub incr_parse;
sub incr_reset;
sub incr_skip;
sub indent;
sub latin1;
sub max_depth;
sub max_size;
sub new;
sub pretty;
sub relaxed;
sub shrink;
sub space_after;
sub space_before;
sub utf8;
}
package List::MoreUtils {
sub _XScompiled;
sub after(&@) ;
sub after_incl(&@) ;
sub all(&@) ;
sub all_u(&@) ;
sub any(&@) ;
sub any_u(&@) ;
sub apply(&@) ;
sub arrayify;
sub before(&@) ;
sub before_incl(&@) ;
sub binsert(&$\@) ;
sub bremove(&\@) ;
sub bsearch(&@) ;
sub bsearch_index(&@) ;
sub bsearch_insert(&$\@) ;
sub bsearch_remove(&\@) ;
sub bsearchidx(&@) ;
sub distinct(@) ;
sub duplicates(@) ;
sub each_array(\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
sub each_arrayref;
sub equal_range(&@) ;
sub false(&@) ;
sub first_index(&@) ;
sub first_result(&@) ;
sub first_value(&@) ;
sub firstidx(&@) ;
sub firstres(&@) ;
sub firstval(&@) ;
sub frequency(@) ;
sub indexes(&@) ;
sub insert_after(&$\@) ;
sub insert_after_string($$\@) ;
sub last_index(&@) ;
sub last_result(&@) ;
sub last_value(&@) ;
sub lastidx(&@) ;
sub lastres(&@) ;
sub lastval(&@) ;
sub listcmp(\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
sub lower_bound(&@) ;
sub mesh(\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
sub minmax(@) ;
sub minmaxstr(@) ;
sub mode(@) ;
sub natatime($@) ;
sub none(&@) ;
sub none_u(&@) ;
sub notall(&@) ;
sub notall_u(&@) ;
sub occurrences(@) ;
sub one(&@) ;
sub one_u(&@) ;
sub only_index(&@) ;
sub only_result(&@) ;
sub only_value(&@) ;
sub onlyidx(&@) ;
sub onlyres(&@) ;
sub onlyval(&@) ;
sub pairwise(&\@\@) ;
sub part(&@) ;
sub qsort(&\@) ;
sub reduce_0(&@) ;
sub reduce_1(&@) ;
sub reduce_u(&@) ;
sub samples($@) ;
sub singleton(@) ;
sub slide(&@) ;
sub slideatatime($@) ;
sub true(&@) ;
sub uniq(@) ;
sub upper_bound(&@) ;
sub zip(\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
sub zip6(\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
sub zip_unflatten(\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
}
package List::MoreUtils::XS {
sub _XScompiled;
sub _array_iterator(;$) ;
sub _slideatatime_iterator() ;
sub after(&@) ;
sub after_incl(&@) ;
sub all(&@) ;
sub all_u(&@) ;
sub any(&@) ;
sub any_u(&@) ;
sub apply(&@) ;
sub arrayify;
sub before(&@) ;
sub before_incl(&@) ;
sub binsert(&$\@) ;
sub bremove(&\@) ;
sub bsearch(&@) ;
sub bsearchidx(&@) ;
sub duplicates(@) ;
sub each_array(\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
sub each_arrayref;
sub equal_range(&@) ;
sub false(&@) ;
sub firstidx(&@) ;
sub firstres(&@) ;
sub firstval(&@) ;
sub frequency(@) ;
sub indexes(&@) ;
sub insert_after(&$\@) ;
sub insert_after_string($$\@) ;
sub lastidx(&@) ;
sub lastres(&@) ;
sub lastval(&@) ;
sub listcmp(\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
sub lower_bound(&@) ;
sub mesh(\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
sub minmax(@) ;
sub minmaxstr(@) ;
sub mode(@) ;
sub natatime($@) ;
sub none(&@) ;
sub none_u(&@) ;
sub notall(&@) ;
sub notall_u(&@) ;
sub occurrences(@) ;
sub one(&@) ;
sub one_u(&@) ;
sub onlyidx(&@) ;
sub onlyres(&@) ;
sub onlyval(&@) ;
sub pairwise(&\@\@) ;
sub part(&@) ;
sub qsort(&\@) ;
sub reduce_0(&@) ;
sub reduce_1(&@) ;
sub reduce_u(&@) ;
sub samples($@) ;
sub singleton(@) ;
sub slide(&@) ;
sub slideatatime($@) ;
sub true(&@) ;
sub uniq(@) ;
sub upper_bound(&@) ;
sub zip6(\@\@;\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@\@) ;
}
package List::MoreUtils::XS_ea {
sub DESTROY;
}
package List::MoreUtils::XS_sa {
sub DESTROY;
}
package List::Util {
sub all(&@) ;
sub any(&@) ;
sub first(&@) ;
sub head($@) ;
sub max(@) ;
sub maxstr(@) ;
sub min(@) ;
sub minstr(@) ;
sub none(&@) ;
sub notall(&@) ;
sub pairfirst(&@) ;
sub pairgrep(&@) ;
sub pairkeys(@) ;
sub pairmap(&@) ;
sub pairs(@) ;
sub pairvalues(@) ;
sub product(@) ;
sub reduce(&@) ;
sub reductions(&@) ;
sub sample($@) ;
sub shuffle(@) ;
sub sum(@) ;
sub sum0(@) ;
sub tail($@) ;
sub uniq(@) ;
sub uniqint(@) ;
sub uniqnum(@) ;
sub uniqstr(@) ;
sub unpairs(@) ;
}
package Locale::gettext {
sub LC_SYNTAX;
sub LC_TOD;
sub bind_textdomain_codeset;
sub bindtextdomain;
sub bytes2str($$;$) ;
sub constant;
sub dcgettext;
sub dcngettext;
sub decode($$;$) ;
sub decode_utf8($;$) ;
sub dgettext;
sub dngettext;
sub encode($$;$) ;
sub encode_utf8($) ;
sub gettext;
sub localeconv;
sub ngettext;
sub setlocale;
sub str2bytes($$;$) ;
sub textdomain;
}
package MIME::Charset {
sub is_utf8($;$) ;
}
package POSIX {
sub ARG_MAX() ;
sub CHILD_MAX() ;
sub CLK_TCK() ;
sub EOTHER() ;
sub EPROCLIM() ;
sub LC_SYNTAX;
sub LC_TOD;
sub LDBL_EPSILON() ;
sub LDBL_MAX() ;
sub LDBL_MIN() ;
sub LINK_MAX() ;
sub L_tmpnam;
sub OPEN_MAX() ;
sub STREAM_MAX() ;
sub S_ISBLK;
sub S_ISCHR;
sub S_ISDIR;
sub S_ISFIFO;
sub S_ISREG;
sub TZNAME_MAX() ;
sub WEXITSTATUS;
sub WIFEXITED;
sub WIFSIGNALED;
sub WIFSTOPPED;
sub WSTOPSIG;
sub WTERMSIG;
sub _exit;
sub abort;
sub abs;
sub access;
sub acos;
sub acosh;
sub alarm;
sub asctime;
sub asin;
sub asinh;
sub assert;
sub atan2;
sub atan;
sub atanh;
sub atexit;
sub atof;
sub atoi;
sub atol;
sub bsearch;
sub calloc;
sub cbrt;
sub ceil;
sub chdir;
sub chmod;
sub chown;
sub clearerr;
sub clock;
sub close;
sub closedir;
sub constant;
sub copysign;
sub cos;
sub cosh;
sub creat;
sub ctermid;
sub ctime;
sub cuserid;
sub difftime;
sub div;
sub dup2;
sub dup;
sub erf;
sub erfc;
sub errno;
sub execl;
sub execle;
sub execlp;
sub execv;
sub execve;
sub execvp;
sub exit;
sub exp2;
sub exp;
sub expm1;
sub fabs;
sub fclose;
sub fcntl;
sub fdim;
sub fdopen;
sub fegetround;
sub feof;
sub ferror;
sub fesetround;
sub fflush;
sub fgetc;
sub fgetpos;
sub fgets;
sub fileno;
sub floor;
sub fma;
sub fmax;
sub fmin;
sub fmod;
sub fopen;
sub fork;
sub fpathconf;
sub fpclassify;
sub fprintf;
sub fputc;
sub fputs;
sub fread;
sub free;
sub freopen;
sub frexp;
sub fscanf;
sub fseek;
sub fsetpos;
sub fstat;
sub fsync;
sub ftell;
sub fwrite;
sub getc;
sub getchar;
sub getcwd;
sub getegid;
sub getenv;
sub geteuid;
sub getgid;
sub getgrgid;
sub getgrnam;
sub getgroups;
sub getlogin;
sub getpayload;
sub getpgrp;
sub getpid;
sub getppid;
sub getpwnam;
sub getpwuid;
sub gets;
sub getuid;
sub gmtime;
sub hypot;
sub ilogb;
sub isatty;
sub isfinite;
sub isgreater;
sub isgreaterequal;
sub isinf;
sub isless;
sub islessequal;
sub islessgreater;
sub isnan;
sub isnormal;
sub issignaling;
sub isunordered;
sub j0;
sub j1;
sub jn;
sub kill;
sub labs;
sub lchown;
sub ldexp;
sub ldiv;
sub lgamma;
sub link;
sub localeconv;
sub localtime;
sub log10;
sub log1p;
sub log2;
sub log;
sub logb;
sub longjmp;
sub lrint;
sub lround;
sub lseek;
sub malloc;
sub mblen;
sub mbtowc;
sub memchr;
sub memcmp;
sub memcpy;
sub memmove;
sub memset;
sub mkdir;
sub mkfifo;
sub mktime;
sub modf;
sub nan;
sub nearbyint;
sub nextafter;
sub nexttoward;
sub nice;
sub offsetof;
sub open;
sub opendir;
sub pathconf;
sub pause;
sub pipe;
sub pow;
sub putc;
sub putchar;
sub puts;
sub qsort;
sub raise;
sub rand;
sub read;
sub readdir;
sub realloc;
sub remainder;
sub remove;
sub remquo;
sub rename;
sub rewind;
sub rewinddir;
sub rint;
sub rmdir;
sub round;
sub scalbn;
sub scanf;
sub setbuf;
sub setgid;
sub setjmp;
sub setlocale;
sub setpayload;
sub setpayloadsig;
sub setpgid;
sub setsid;
sub setuid;
sub setvbuf;
sub sigaction;
sub siglongjmp;
sub signbit;
sub sigpending;
sub sigprocmask;
sub sigsetjmp;
sub sigsuspend;
sub sin;
sub sinh;
sub sleep;
sub sqrt;
sub srand;
sub sscanf;
sub stat;
sub strcat;
sub strchr;
sub strcmp;
sub strcoll;
sub strcpy;
sub strcspn;
sub strerror;
sub strftime;
sub strlen;
sub strncat;
sub strncmp;
sub strncpy;
sub strpbrk;
sub strrchr;
sub strspn;
sub strstr;
sub strtod;
sub strtok;
sub strtol;
sub strtold;
sub strtoul;
sub strxfrm;
sub sysconf;
sub system;
sub tan;
sub tanh;
sub tcdrain;
sub tcflow;
sub tcflush;
sub tcgetpgrp;
sub tcsendbreak;
sub tcsetpgrp;
sub tgamma;
sub time;
sub times;
sub tmpfile;
sub tmpnam;
sub trunc;
sub ttyname;
sub tzname;
sub tzset;
sub umask;
sub uname;
sub ungetc;
sub unlink;
sub utime;
sub vfprintf;
sub vprintf;
sub vsprintf;
sub wait;
sub waitpid;
sub wctomb;
sub write;
sub y0;
sub y1;
sub yn;
}
package POSIX::SigSet {
sub addset;
sub delset;
sub emptyset;
sub fillset;
sub ismember;
sub new;
}
package POSIX::Termios {
sub getattr;
sub getcc;
sub getcflag;
sub getiflag;
sub getispeed;
sub getlflag;
sub getoflag;
sub getospeed;
sub new;
sub setattr;
sub setcc;
sub setcflag;
sub setiflag;
sub setispeed;
sub setlflag;
sub setoflag;
sub setospeed;
}
package Package::Stash {
sub add_symbol;
sub get_all_symbols;
sub get_or_add_symbol;
sub get_symbol;
sub has_symbol;
sub list_all_symbols;
sub name;
sub namespace;
sub new;
sub remove_glob;
sub remove_symbol;
}
package Package::Stash::XS {
sub add_symbol;
sub get_all_symbols;
sub get_or_add_symbol;
sub get_symbol;
sub has_symbol;
sub list_all_symbols;
sub name;
sub namespace;
sub new;
sub remove_glob;
sub remove_symbol;
}
package PadWalker {
sub _upcontext;
sub closed_over;
sub peek_my;
sub peek_our;
sub peek_sub;
sub set_closed_over;
sub var_name;
}
package Params::Util {
sub _ARRAY($) ;
sub _ARRAY0($) ;
sub _ARRAYLIKE($) ;
sub _CODE($) ;
sub _CODELIKE($) ;
sub _HASH($) ;
sub _HASH0($) ;
sub _HASHLIKE($) ;
sub _INSTANCE($$) ;
sub _NUMBER($) ;
sub _REGEX($) ;
sub _SCALAR($) ;
sub _SCALAR0($) ;
sub _STRING($) ;
sub _XScompiled;
}
package Params::Util::PP {
sub looks_like_number($) ;
}
package Params::ValidationCompiler::Compiler {
sub blessed($) ;
sub looks_like_number($) ;
sub pairkeys(@) ;
sub pairvalues(@) ;
sub perlstring;
sub reftype($) ;
sub set_subname;
}
package PerlIO {
sub get_layers(*;@) ;
}
package PerlIO::Layer {
sub NoWarnings;
sub find;
}
package Ref::Util {
sub _using_custom_ops;
sub is_arrayref($) ;
sub is_blessed_arrayref($) ;
sub is_blessed_coderef($) ;
sub is_blessed_formatref($) ;
sub is_blessed_globref($) ;
sub is_blessed_hashref($) ;
sub is_blessed_ref($) ;
sub is_blessed_refref($) ;
sub is_blessed_scalarref($) ;
sub is_coderef($) ;
sub is_formatref($) ;
sub is_globref($) ;
sub is_hashref($) ;
sub is_ioref($) ;
sub is_plain_arrayref($) ;
sub is_plain_coderef($) ;
sub is_plain_formatref($) ;
sub is_plain_globref($) ;
sub is_plain_hashref($) ;
sub is_plain_ref($) ;
sub is_plain_refref($) ;
sub is_plain_scalarref($) ;
sub is_ref($) ;
sub is_refref($) ;
sub is_regexpref($) ;
sub is_scalarref($) ;
}
package Ref::Util::XS {
sub _using_custom_ops;
sub is_arrayref($) ;
sub is_blessed_arrayref($) ;
sub is_blessed_coderef($) ;
sub is_blessed_formatref($) ;
sub is_blessed_globref($) ;
sub is_blessed_hashref($) ;
sub is_blessed_ref($) ;
sub is_blessed_refref($) ;
sub is_blessed_scalarref($) ;
sub is_coderef($) ;
sub is_formatref($) ;
sub is_globref($) ;
sub is_hashref($) ;
sub is_ioref($) ;
sub is_plain_arrayref($) ;
sub is_plain_coderef($) ;
sub is_plain_formatref($) ;
sub is_plain_globref($) ;
sub is_plain_hashref($) ;
sub is_plain_ref($) ;
sub is_plain_refref($) ;
sub is_plain_scalarref($) ;
sub is_ref($) ;
sub is_refref($) ;
sub is_regexpref($) ;
sub is_scalarref($) ;
}
package Regexp {
sub DESTROY() ;
}
package Role::Tiny {
sub _linear_isa($;$) ;
}
package Scalar::Util {
sub blessed($) ;
sub dualvar($$) ;
sub isdual($) ;
sub isvstring($) ;
sub isweak($) ;
sub looks_like_number($) ;
sub openhandle($) ;
sub readonly($) ;
sub refaddr($) ;
sub reftype($) ;
sub tainted($) ;
sub unweaken($) ;
sub weaken($) ;
}
package Specio::Constraint::AnyCan {
sub perlstring;
}
package Specio::Constraint::Enum {
sub dclone($) ;
sub refaddr($) ;
}
package Specio::Constraint::ObjectCan {
sub perlstring;
}
package Specio::Constraint::ObjectIsa {
sub perlstring;
}
package Specio::Constraint::Parameterized {
sub dclone($) ;
}
package Specio::Constraint::Role::CanType {
sub blessed($) ;
sub dclone($) ;
}
package Specio::Constraint::Role::Interface {
sub all(&@) ;
sub any(&@) ;
sub first(&@) ;
}
package Specio::Constraint::Role::IsaType {
sub blessed($) ;
sub dclone($) ;
}
package Specio::Constraint::Union {
sub all(&@) ;
sub any(&@) ;
sub dclone($) ;
}
package Specio::Exception {
sub blessed($) ;
}
package Specio::Helpers {
sub blessed($) ;
sub perlstring;
}
package Specio::OO {
sub all(&@) ;
sub dclone($) ;
sub perlstring;
sub weaken($) ;
}
package Specio::PartialDump {
sub blessed($) ;
sub looks_like_number($) ;
sub reftype($) ;
}
package Specio::TypeChecks {
sub blessed($) ;
}
package Storable {
sub dclone($) ;
sub init_perinterp() ;
sub is_retrieving() ;
sub is_storing() ;
sub last_op_in_netorder() ;
sub mretrieve($;$) ;
sub mstore($) ;
sub net_mstore($) ;
sub net_pstore($$) ;
sub pretrieve($;$) ;
sub pstore($$) ;
sub stack_depth() ;
sub stack_depth_hash() ;
}
package Sub::Identify {
sub get_code_info($) ;
sub get_code_location($) ;
sub is_sub_constant($) ;
}
package Sub::Util {
sub set_prototype;
sub set_subname;
sub subname;
}
package Test2::API {
sub blessed($) ;
sub time() ;
sub weaken($) ;
}
package Test2::API::Context {
sub blessed($) ;
sub weaken($) ;
}
package Test2::API::Instance {
sub reftype($) ;
}
package Test2::Event {
sub blessed($) ;
sub reftype($) ;
}
package Test2::Event::V2 {
sub reftype($) ;
}
package Test2::EventFacet::Trace {
sub time() ;
}
package Test2::Hub {
sub first(&@) ;
sub weaken($) ;
}
package Test2::Util::Facets2Legacy {
sub blessed($) ;
}
package Test2::Util::HashBase {
sub _isa($;$) ;
}
package Test::Builder {
sub blessed($) ;
sub reftype($) ;
sub weaken($) ;
}
package Test::LeakTrace {
sub CLONE;
sub _finish;
sub _runops_installed;
sub _start;
sub count_sv;
}
package Text::CharWidth {
sub mblen;
sub mbswidth;
sub mbwidth;
}
package Text::Iconv {
sub new($$$) ;
sub raise_error(;@) ;
}
package Text::IconvPtr {
sub DESTROY($) ;
sub convert($$) ;
sub get_attr($$) ;
sub raise_error($;@) ;
sub retval($) ;
sub set_attr($$$) ;
}
package Tie::Hash::NamedCapture {
sub CLEAR;
sub DELETE;
sub EXISTS;
sub FETCH;
sub FIRSTKEY;
sub NEXTKEY;
sub SCALAR;
sub STORE;
sub TIEHASH;
sub _tie_it;
sub flags;
}
package Time::HiRes {
sub alarm($;$) ;
sub clock() ;
sub clock_getres(;$) ;
sub clock_gettime(;$) ;
sub clock_nanosleep($$;$) ;
sub constant($) ;
sub getitimer($) ;
sub gettimeofday() ;
sub lstat(;$) ;
sub nanosleep($) ;
sub setitimer($$;$) ;
sub sleep(;@) ;
sub stat(;$) ;
sub time() ;
sub ualarm($;$) ;
sub usleep($) ;
sub utime($$@) ;
}
package Try::Tiny {
sub _subname;
}
package UNIVERSAL {
sub DOES;
sub VERSION;
sub can;
sub isa;
}
package Unicode::GCString {
sub DESTROY($) ;
sub _new($$;$) ;
sub as_array($) ;
sub as_scalarref;
sub as_string($;$;$) ;
sub chars($) ;
sub cmp($$;$) ;
sub columns;
sub concat($$;$) ;
sub copy($) ;
sub eos;
sub flag($;$;$) ;
sub item($;$) ;
sub join;
sub lbc($) ;
sub lbcext($) ;
sub lbclass($;$) ;
sub lbclass_ext($;$) ;
sub length($) ;
sub next($;$;$) ;
sub pos($;$) ;
sub substr($$;$;$) ;
}
package Unicode::LineBreak {
sub DESTROY($) ;
sub EAWidths;
sub LBClasses;
sub SOMBOK_VERSION;
sub UNICODE_VERSION;
sub _config;
sub _new($) ;
sub as_hashref;
sub as_scalarref;
sub as_string;
sub break($$) ;
sub break_partial($$) ;
sub breakingRule($$$) ;
sub copy($) ;
sub is_utf8($;$) ;
sub lbrule($$$) ;
sub reset($) ;
sub strsize($$$$$;$) ;
}
package Unicode::LineBreak::SouthEastAsian {
sub supported() ;
}
package Unicode::UTF8 {
sub decode_utf8;
sub encode_utf8;
sub valid_utf8;
}
package Variable::Magic {
sub CLONE;
sub _wizard;
sub cast(\[$@%&*]$@) ;
sub dispell(\[$@%&*]$) ;
sub getdata(\[$@%&*]$) ;
}
package XString {
sub cstring;
sub perlstring;
}
package attributes {
sub _fetch_attrs($) ;
sub _guess_stash($) ;
sub _modify_attrs;
sub reftype($) ;
}
package bytes {
sub chr(_) ;
sub index($$;$) ;
sub length(_) ;
sub ord(_) ;
sub rindex($$;$) ;
sub substr($$;$$) ;
}
package constant {
sub _make_const(\[$@]) ;
}
package indirect {
sub CLONE;
sub _global($) ;
sub _tag($) ;
}
package mro {
sub _nextcan;
sub get_isarev($) ;
sub get_linear_isa($;$) ;
sub get_mro($) ;
sub get_pkg_gen($) ;
sub invalidate_all_method_caches() ;
sub is_universal($) ;
sub method_changed_in($) ;
sub set_mro($$) ;
}
package re {
sub install;
sub is_regexp($) ;
sub optimization($) ;
sub regexp_pattern($) ;
sub regmust($) ;
sub regname(;$$) ;
sub regnames(;$) ;
sub regnames_count() ;
}
package utf8 {
sub decode;
sub downgrade;
sub encode;
sub is_utf8;
sub native_to_unicode;
sub unicode_to_native;
sub upgrade;
sub valid;
}
package version {
sub _VERSION;
sub boolean;
sub declare;
sub is_alpha;
sub is_qv;
sub new;
sub noop;
sub normal;
sub numify;
sub parse;
sub qv;
sub stringify;
sub vcmp;
}
