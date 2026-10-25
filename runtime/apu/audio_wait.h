// SpeedBreaker runtime. GPL-3.0-or-later (see COPYING).
//
// How the audio thread (apu/audio.cpp) waits for its next 5.33 ms tick.
//
// The game's voices hold only a couple of decoded frames, so the render
// callback has to run evenly, one frame per tick. A tick that wakes more than
// one interval late is followed by a catch-up burst (the next deadline has
// passed already, so the thread doesn't sleep), and every frame after the
// first two in a burst is rendered from empty voices: silence. On the output
// that is the "two frames on, one off" chop.
//
// Windows: std::this_thread::sleep_until ends up in a Sleep()/Wait with a
// millisecond timeout, which fires on the system timer tick: 15.6 ms unless
// the process has asked for better. Since Windows 10 2004 timeBeginPeriod only
// helps the process that calls it, and since Windows 11 it isn't honoured
// while the process's window is occluded, minimized or "inaudible", so SDL's
// 1 ms request (SDL_InitTicks) can't be counted on. A high-resolution
// waitable timer (Windows 10 1803+) wakes within about half a millisecond
// whatever the system tick is. The thread also joins MMCSS ("Pro Audio", as
// WASAPI's own threads do) so that a busy core doesn't hold it back.
//
// Anything older than 1803, or a refused timer, falls back to
// timeBeginPeriod(1) and sleep_until. Elsewhere this is sleep_until, as before.
#pragma once
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <memory>
#include <thread>

#ifdef _WIN32
#ifdef SB_FAKE_WINDOWS_GUARD
// The runtime build keeps <windows.h> out of its sources (compat/win/win_compat.h), so AudioWait is
// only declared here and implemented in audio_wait_win.cpp.
namespace apu
{
    namespace detail
    {
        class AudioWaitImpl;
    }

    class AudioWait
    {
    public:
        AudioWait();
        ~AudioWait();
        AudioWait(const AudioWait&) = delete;
        AudioWait& operator=(const AudioWait&) = delete;

        void Until(std::chrono::steady_clock::time_point t);
        const char* Describe() const;

    private:
        std::unique_ptr<detail::AudioWaitImpl> m_impl;
    };
}
#else
// Native Windows build (e.g. AudioPacingTest): use the implementation directly.
#include "audio_wait_win.h"
namespace apu
{
    using AudioWait = detail::AudioWaitImpl;
}
#endif
#else

namespace apu
{
    class AudioWait
    {
    public:
        void Until(std::chrono::steady_clock::time_point t) { std::this_thread::sleep_until(t); }
        const char* Describe() const { return "sleep_until"; }
    };
}

#endif
