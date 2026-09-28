#pragma once

// Select user-visible modules at build time. Shared transport and host
// compatibility code remains linked for every source profile.
#ifndef OPENIO_TODO
#define OPENIO_TODO 1
#endif
#ifndef OPENIO_CUE
#define OPENIO_CUE 1
#endif
#ifndef OPENIO_RUN
#define OPENIO_RUN 1
#endif

#if OPENIO_RUN && !TIO_WORKOUT_OTA
#error Running dashboard requires the TWK1-enabled build profile.
#endif
