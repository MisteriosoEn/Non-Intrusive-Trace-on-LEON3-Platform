
#ifndef CONFIG_FTAHBRAM_ENABLE
#define CONFIG_FTAHBRAM_ENABLE 0
#endif

#ifndef CONFIG_FTAHBRAM_START
#define CONFIG_FTAHBRAM_START A00
#endif

#if defined CONFIG_FTAHBRAM_SZ1
#define CONFIG_FTAHBRAM_SZ 1
#elif CONFIG_FTAHBRAM_SZ2
#define CONFIG_FTAHBRAM_SZ 2
#elif CONFIG_FTAHBRAM_SZ4
#define CONFIG_FTAHBRAM_SZ 4
#elif CONFIG_FTAHBRAM_SZ8
#define CONFIG_FTAHBRAM_SZ 8
#elif CONFIG_FTAHBRAM_SZ16
#define CONFIG_FTAHBRAM_SZ 16
#elif CONFIG_FTAHBRAM_SZ32
#define CONFIG_FTAHBRAM_SZ 32
#elif CONFIG_FTAHBRAM_SZ64
#define CONFIG_FTAHBRAM_SZ 64
#elif CONFIG_FTAHBRAM_SZ128
#define CONFIG_FTAHBRAM_SZ 128
#elif CONFIG_FTAHBRAM_SZ256
#define CONFIG_FTAHBRAM_SZ 256
#else
#define CONFIG_FTAHBRAM_SZ 1
#endif

#if defined CONFIG_FTAHBRAM_EDAC_NONE
#define CONFIG_FTAHBRAM_EDAC 0
#elif CONFIG_FTAHBRAM_EDAC_BCH1
#define CONFIG_FTAHBRAM_EDAC 1
#elif CONFIG_FTAHBRAM_EDAC_BCH2
#define CONFIG_FTAHBRAM_EDAC 2
#elif CONFIG_FTAHBRAM_EDAC_TECHSPEC
#define CONFIG_FTAHBRAM_EDAC 3
#endif

#ifndef CONFIG_FTAHBRAM_PIPE
#define CONFIG_FTAHBRAM_PIPE 0
#else
#define CONFIG_FTAHBRAM_EDAC 1
#define CONFIG_FTAHBRAM_AUTOSCRUB 0
#define CONFIG_FTAHBRAM_ERRORCNTR 1
#define CONFIG_FTAHBRAM_CNTBITS 7
#endif

#ifndef CONFIG_FTAHBRAM_EDAC
#define CONFIG_FTAHBRAM_EDAC 0
#endif

#ifndef CONFIG_FTAHBRAM_AUTOSCRUB
#define CONFIG_FTAHBRAM_AUTOSCRUB 0
#endif

#ifndef CONFIG_FTAHBRAM_ERRORCNTR
#define CONFIG_FTAHBRAM_ERRORCNTR 0
#endif

#ifndef CONFIG_FTAHBRAM_CNTBITS
#define CONFIG_FTAHBRAM_CNTBITS 1
#endif