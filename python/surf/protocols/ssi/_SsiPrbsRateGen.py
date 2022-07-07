#-----------------------------------------------------------------------------
# Description:
# PyRogue SsiPrbsTx
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class SsiPrbsRateGen(pr.Device):
    def __init__(self, clock_freq=125.0e6, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteCommand(
            name         = "StatReset",
            description  = "",
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            function     = lambda cmd: cmd.toggle,
            hidden       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = "PacketLength",
            description  = "",
            offset       = 0x04,
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RawPeriod",
            description  = "",
            offset       = 0x08,
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        def get_conv(var):
            return clock_freq / (self.RawPeriod.value()+1)

        def set_conv(value, write):
            if value <= 0:
                self.RawPeriod.set(0xFFFFFFFF, write=write)
            else:
                v = int(clock_freq / value)-1
                if v > 0xFFFFFFFF:
                    v = 0xFFFFFFFF
                self.RawPeriod.set(v, write=write)

        self.add(pr.LinkVariable(
            name = 'TxRate',
            dependencies = [self.RawPeriod],
            units = 'Hz',
            disp = '{:0.3f}',
            linkedGet = get_conv,
            linkedSet = set_conv))



        self.add(pr.RemoteVariable(
            name         = "TxEn",
            description  = "",
            offset       = 0x0C,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteCommand(
            name         = "OneShot",
            description  = "",
            offset       = 0x0C,
            bitSize      = 1,
            bitOffset    = 1,
            base         = pr.UInt,
            function     = pr.BaseCommand.toggle,
            hidden       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = "Missed",
            description  = "",
            offset       = 0x10,
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.UInt,
            disp = '{:d}',            
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "FrameRate",
            description  = "",
            offset       = 0x14,
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.UInt,
            units = 'Hz',
            disp = '{:d}',
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "FrameRateMax",
            description  = "",
            offset       = 0x18,
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.UInt,
            disp = '{:d}',            
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "FrameRateMin",
            description  = "",
            offset       = 0x1C,
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.UInt,
            disp = '{:d}',            
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "BandWidth",
            description  = "",
            offset       = 0x20,
            bitSize      = 64,
            bitOffset    = 0,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "BandWidthMax",
            description  = "",
            offset       = 0x28,
            bitSize      = 64,
            bitOffset    = 0,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "BandWidthMin",
            description  = "",
            offset       = 0x30,
            bitSize      = 64,
            bitOffset    = 0,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(
            name         = "FrameCount",
            description  = "",
            offset       = 0x40,
            bitSize      = 64,
            bitOffset    = 0,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))
