
puts {
  Cyrusim Desiger

}

# set library_list {
	# design_library {

		# ../sourceCode/modules/memory/default/bram.v
		# ../sourceCode/modules/memory/default/unified_caches.v		

		# ../sourceCode/modules/memory/default/main_memory.v 
		# ../sourceCode/modules/memory/default/direct_mapped_cache.v
		# ../sourceCode/modules/memory/default/cache_wrapper.v
		# ../sourceCode/modules/memory/remote_access/ra_mem_system_wrapper.v  
		# ../sourceCode/modules/memory/remote_access/ra_memory_router_system.v   
		# ../sourceCode/modules/memory/remote_access/ra_packetizer.v 
		# ../sourceCode/modules/memory/remote_access/ra_core_interface.v
		# ../sourceCode/modules/memory/remote_access/ra_cache_interface.v
		# ../sourceCode/modules/memory/remote_access/ra_packetizer_core.v  
		# ../sourceCode/modules/memory/remote_access/ra_packetizer_cache.v   
		# ../sourceCode/modules/memory/remote_access/ra_packetizer_network.v 

		# ../sourceCode/modules/router/arbiter.v
		# ../sourceCode/modules/router/buffer_port.v
		# ../sourceCode/modules/router/core_interface.v   
		# ../sourceCode/modules/router/crossbar.v  
		# ../sourceCode/modules/router/fifo.v  
		# ../sourceCode/modules/router/router.v     
		# ../sourceCode/modules/router/router_wrapper.v  

		# ../sourceCode/modules/mips_core/two_threads/7_Stage_2_Thread_MIPS_Core.v
		# ../sourceCode/modules/mips_core/two_threads/two_inst_decoder.v
		# ../sourceCode/modules/mips_core/ALU.v  
		# ../sourceCode/modules/mips_core/real_cores_mesh.v  
		# ../sourceCode/modules/mips_core/regFile.v  

	# }
	# test_library {

		# ../sourceCode/testbench/tb_Real_Cores_Mesh_top.v
		# {C:\Program Files\Heracles Designer\userSystemRTL\mips.v}
	# }
# }

set top_level  work.tb_Real_Cores_Mesh_top
set cores 16
set application_list0 {
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c0_c0.mem} {0}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c1_c1.mem} {1}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c2_c2.mem} {2}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c3_c3.mem} {3}
	
}

set application_list {
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c4_c4.mem} {4}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c5_c5.mem} {5}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c6_c6.mem} {6}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c7_c7.mem} {7}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c8_c8.mem} {8}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c9_c9.mem} {9}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c10_c10.mem} {10}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c11_c11.mem} {11}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c12_c12.mem} {12}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c13_c13.mem} {13}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c14_c14.mem} {14}
	{C:\Users\BEHZAD\Desktop\NoC_router_attack\681012\matrix_c15_c15.mem} {15}
}


set wave_patterns {
                           /*
}
set wave_radices {
                           hexadecimal {data q}
}

# After sourcing the script from ModelSim for the
# first time use these commands to recompile.

proc r  {} {uplevel #0 source heracles.tcl}
proc rr {} {global last_compile_time
            set last_compile_time 0
            r                            }
proc q  {} {quit -force                  }

#Does this installation support Tk?
set tk_ok 1
if [catch {package require Tk}] {set tk_ok 0}

# Prefer a fixed point font for the transcript
set PrefMain(font) {Courier 10 roman normal}

# # Compile out of date files
# set time_now [clock seconds]
# if [catch {set last_compile_time}] {
  # set last_compile_time 0
# }
# foreach {library file_list} $library_list {
  # vlib $library
  # vmap work $library
  # foreach file $file_list {
    # if { $last_compile_time < [file mtime $file] } {
      # if [regexp {.vhdl?$} $file] {
        # vcom -93 $file
      # } else {
        # vlog $file
      # }
      # set last_compile_time 0
    # }
  # }
# }
# set last_compile_time $time_now

# Load the simulation
eval vsim -novopt $top_level
# If waves are required
if [llength $wave_patterns] {
  noview wave
  foreach pattern $wave_patterns {
    add wave $pattern
  }
  configure wave -signalnamewidth 1
  foreach {radix signals} $wave_radices {
    foreach signal $signals {
      catch {property wave -radix $radix $signal}
    }
  }
  if $tk_ok {
	set waveWinName [view wave -dock]
	set waveTopLevel [winfo toplevel $waveWinName]
  }
}


# Zeroing out the cache structures
set top_part  {/tb_Real_Cores_Mesh_top/TB_M/U/MESH_NODE[}

set icache {]/NODES/memory_sub_system/mem_packetizer/unified/ICache/CACHE/CACHE_RAM/ram}
set dcache {]/NODES/memory_sub_system/mem_packetizer/unified/DCache/CACHE/CACHE_RAM/ram}

for {set i 4} {$i< $cores} {incr i} {
	mem load -filltype value -filldata 0 -fillradix symbolic -skip 0 $top_part$i$icache
	mem load -filltype value -filldata 0 -fillradix symbolic -skip 0 $top_part$i$dcache
}

set mem_part {]/NODES/memory_sub_system/mem_packetizer/m_memory/RAM_Block/ram}
# Loading memories with applications 
foreach {application core} $application_list {
	mem load -i $application -format hex $top_part$core$mem_part
}


#added----------------------------------------------------------------------------------

set top_part0  {/tb_Real_Cores_Mesh_top/TB_M/U/MESH_NODE0[}

set icache {]/NODES/memory_sub_system/mem_packetizer/unified/ICache/CACHE/CACHE_RAM/ram}
set dcache {]/NODES/memory_sub_system/mem_packetizer/unified/DCache/CACHE/CACHE_RAM/ram}

for {set i 0} {$i< 4} {incr i} {
	mem load -filltype value -filldata 0 -fillradix symbolic -skip 0 $top_part0$i$icache
	mem load -filltype value -filldata 0 -fillradix symbolic -skip 0 $top_part0$i$dcache
}

set mem_part {]/NODES/memory_sub_system/mem_packetizer/m_memory/RAM_Block/ram}
# Loading memories with applications 
foreach {application core} $application_list0 {
	mem load -i $application -format hex $top_part0$core$mem_part
}
#0----------------------------------------------------------------------------------------


view mem -dock

# Run the simulation
view transcript
run -all


puts {
  Script commands are:

  r = Recompile changed and dependent files
 rr = Recompile everything
  q = Quit without confirmation
}

# How long since project began?
if {[file isfile start_time.txt] == 0} {
  set f [open start_time.txt w]
  puts $f "Start time was [clock seconds]"
  close $f
} else {
  set f [open start_time.txt r]
  set line [gets $f]
  close $f
  regexp {\d+} $line start_time
  set total_time [expr ([clock seconds]-$start_time)/60]
  #puts "Project time is $total_time minutes"
}
