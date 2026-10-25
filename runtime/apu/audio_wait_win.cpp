// SpeedBreaker runtime. GPL-3.0-or-later (see COPYING).
// Out-of-line apu::AudioWait for the Windows runtime build; see audio_wait.h.
#include "audio_wait.h"

#if defined(_WIN32) && defined(SB_FAKE_WINDOWS_GUARD)
#include "audio_wait_win.h"

namespace apu
{
    AudioWait::AudioWait() : m_impl(std::make_unique<detail::AudioWaitImpl>()) {}
    AudioWait::~AudioWait() = default;
    void AudioWait::Until(std::chrono::steady_clock::time_point t) { m_impl->Until(t); }
    const char* AudioWait::Describe() const { return m_impl->Describe(); }
}
#endif
