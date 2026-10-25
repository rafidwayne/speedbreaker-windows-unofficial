// SpeedBreaker runtime. GPL-3.0-or-later (see COPYING).
//
// Windows implementation of apu::AudioWait (see audio_wait.h for what it is for).
// Include this only from a translation unit that can take the real <windows.h>:
// audio_wait.h does that itself for a native Windows build (AudioPacingTest) and
// leaves it to audio_wait_win.cpp in the runtime build.
#pragma once
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <thread>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifdef SB_FAKE_WINDOWS_GUARD
// compat/win/win_compat.h (force-included in every runtime source) claims mingw's windows.h include
// guards so the real thing stays out. Only audio_wait_win.cpp includes this header; it needs the real
// windows.h (the runtime's own LARGE_INTEGER etc. in kernel/xdm.h clash with it elsewhere).
#undef _WINDOWS_
#undef _INC_WINDOWS
#endif
#include <windows.h>

#ifndef CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
#define CREATE_WAITABLE_TIMER_HIGH_RESOLUTION 0x00000002
#endif

namespace apu
{
namespace detail
{
    // Create on the audio thread: the scheduling it asks for is the calling
    // thread's. Until() is for that thread only.
    class AudioWaitImpl
    {
    public:
        AudioWaitImpl()
        {
            m_timer = CreateWaitableTimerExW(nullptr, nullptr, CREATE_WAITABLE_TIMER_HIGH_RESOLUTION, TIMER_ALL_ACCESS);
            if (!m_timer)
            {
                // Before Windows 10 1803: the best the system tick allows.
                // (Loaded, not linked: the exe needn't import winmm.)
                if (HMODULE winmm = LoadLibraryW(L"winmm.dll"))
                {
                    using Fn = UINT(WINAPI*)(UINT);
                    if (auto begin = reinterpret_cast<Fn>(reinterpret_cast<void*>(GetProcAddress(winmm, "timeBeginPeriod"))))
                        m_period = begin(1) == 0;
                }
            }

            // MMCSS, loaded the same way. "Pro Audio" first, then "Audio".
            if (HMODULE avrt = LoadLibraryW(L"avrt.dll"))
            {
                using Fn = HANDLE(WINAPI*)(LPCWSTR, LPDWORD);
                if (auto set = reinterpret_cast<Fn>(reinterpret_cast<void*>(GetProcAddress(avrt, "AvSetMmThreadCharacteristicsW"))))
                {
                    DWORD task = 0;
                    m_mmcss = set(L"Pro Audio", &task);
                    if (!m_mmcss)
                        m_mmcss = set(L"Audio", &task);
                }
            }
            if (!m_mmcss)
                SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_HIGHEST);
        }

        AudioWaitImpl(const AudioWaitImpl&) = delete;
        AudioWaitImpl& operator=(const AudioWaitImpl&) = delete;

        ~AudioWaitImpl()
        {
            if (m_timer)
                CloseHandle(m_timer);
        }

        void Until(std::chrono::steady_clock::time_point t)
        {
            using namespace std::chrono;
            const auto remaining = t - steady_clock::now();
            if (remaining <= steady_clock::duration::zero())
                return;
            if (m_timer)
            {
                // A negative due time is relative, in 100 ns units.
                LARGE_INTEGER due;
                due.QuadPart = -std::max<int64_t>(1, duration_cast<nanoseconds>(remaining).count() / 100);
                if (SetWaitableTimer(m_timer, &due, 0, nullptr, nullptr, FALSE))
                {
                    WaitForSingleObject(m_timer, INFINITE);
                    return;
                }
            }
            std::this_thread::sleep_until(t);
        }

        // For the log.
        const char* Describe() const
        {
            if (m_timer)
                return m_mmcss ? "high-resolution timer, MMCSS" : "high-resolution timer, thread priority";
            return m_mmcss ? (m_period ? "sleep_until at 1 ms, MMCSS" : "sleep_until at the system timer tick, MMCSS")
                           : (m_period ? "sleep_until at 1 ms, thread priority" : "sleep_until at the system timer tick, thread priority");
        }

    private:
        HANDLE m_timer = nullptr;
        HANDLE m_mmcss = nullptr;
        bool m_period = false;
    };
}
}

#endif
