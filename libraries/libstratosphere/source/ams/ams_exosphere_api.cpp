/*
 * Copyright (c) 2018-2019 Atmosphère-NX
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stratosphere.hpp>
#include <stratosphere/spl.hpp>
#include <stratosphere/spl/smc/spl_smc.hpp>

namespace ams::exosphere {

    ApiInfo GetApiInfo() {
        u64 exosphere_cfg;
        if (spl::smc::GetConfig(&exosphere_cfg, 1, SplConfigItem_ExosphereApiVersion) != spl::smc::Result::Success) {
            R_ASSERT(ResultNotPresent());
        }

        return ApiInfo{ util::BitPack64(exosphere_cfg) };
    }

    void ForceRebootToRcm() {
        R_ASSERT(spl::smc::ConvertResult(spl::smc::SetConfig(SplConfigItem_ExosphereNeedsReboot, 1)));
    }

    void ForceRebootToIramPayload() {
        R_ASSERT(spl::smc::ConvertResult(spl::smc::SetConfig(SplConfigItem_ExosphereNeedsReboot, 2)));
    }

    void ForceShutdown() {
        R_ASSERT(spl::smc::ConvertResult(spl::smc::SetConfig(SplConfigItem_ExosphereNeedsShutdown, 1)));
    }

    void CopyToIram(uintptr_t iram_dst, const void *dram_src, size_t size) {
        spl::smc::AtmosphereCopyToIram(iram_dst, dram_src, size);
    }

    void CopyFromIram(void *dram_dst, uintptr_t iram_src, size_t size) {
        spl::smc::AtmosphereCopyFromIram(dram_dst, iram_src, size);
    }

    namespace {

        inline Result GetRcmBugPatched(bool *out) {
            u64 tmp = 0;
            R_TRY(spl::smc::ConvertResult(spl::smc::GetConfig(&tmp, 1, SplConfigItem_ExosphereHasRcmBugPatch)));
            *out = (tmp != 0);
            return ResultSuccess();
        }

    }

    bool IsRcmBugPatched() {
        bool rcm_bug_patched;
        R_ASSERT(GetRcmBugPatched(&rcm_bug_patched));
        return rcm_bug_patched;
    }

}
