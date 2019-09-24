# No PR yet
lib LibC
  {% if flag?(:linux) %}
    fun get_phys_pages : Int32
    fun getpagesize : Int32
  {% end %}

  {% if flag?(:darwin) %}
    SC_PAGESIZE   =  29
    SC_PHYS_PAGES = 200
  {% end %}
end

lib LibC
  {% if flag?(:linux) %}
    fun fallocate(fd : Int, mode : Int, offset : OffT, len : OffT) : Int
    FALLOC_FL_KEEP_SIZE      = 0x01
    FALLOC_FL_PUNCH_HOLE     = 0x02
    FALLOC_FL_NO_HIDE_STALE  = 0x04
    FALLOC_FL_COLLAPSE_RANGE = 0x08
    FALLOC_FL_ZERO_RANGE     = 0x10
    FALLOC_FL_INSERT_RANGE   = 0x20
    FALLOC_FL_UNSHARE_RANGE  = 0x40

    fun posix_fadvise(fd : Int, offset : OffT, len : OffT, advice : Int) : Int
    POSIX_FADV_NORMAL     = 0 # No further special treatment.
    POSIX_FADV_RANDOM     = 1 # Expect random page references.
    POSIX_FADV_SEQUENTIAL = 2 # Expect sequential page references.
    POSIX_FADV_WILLNEED   = 3 # Will need these pages.
    POSIX_FADV_DONTNEED   = 4 # Don't need these pages.
    POSIX_FADV_NOREUSE    = 5 # Data will be accessed once.
  {% end %}
end