# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2021.2 } {

   # Load Source Code
   loadSource -lib surf -dir "$::DIR_PATH/rtl"

   loadSource -path "$::DIR_PATH/ip/CoaXPressOverFiberGtyUsIp/CoaXPressOverFiberGtyUsIp.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/CoaXPressOverFiberGtyUsIp/CoaXPressOverFiberGtyUsIp.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2021.2 (or later)\n\n"
}
