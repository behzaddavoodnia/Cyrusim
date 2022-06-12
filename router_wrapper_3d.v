
/** @module : 3D router_wrapper
 *  @author : Behzad Davoodnia
 
 *  Copyright (c) 2010 Heracles (CSG/CSAIL/MIT)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.

 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */
//`include "router.v"
//`include "core_interface.v"

module router_wrapper #(parameter RT_ALG = 0, RT_WIDTH = 5, FLOW_BITS = 8, DATA_WIDTH = 32, 
						  CORE_IN_PORTS  = 1, 
						  CORE_OUT_PORTS  = 1, SWITCH_TO_SWITCH  = 1, VC_BITS = 1, 
						  VC_DEPTH_BITS = 1, ID_BITS = 4, ROW = 3, 
						  COLUMN = 3)(   // report is used to show performance statistics
  ON, clk, reset, 
  PROG, c_WEn, c_REn,
     
  core_data_in, core_valid_in, 
  s_flits_in, s_valid_in, 
  
  core_data_out, core_valid_out,  
  s_flits_out, s_valid_out, 

  core_empty_in, core_full_in,  
  s_empty_in, s_full_in, 
 
  core_empty_out, core_full_out, 
  s_empty_out, s_full_out,  
  
  router_ID, rt_flowID, rt_entry, 
  // performance reporting
  report
); 

  localparam NUM_VCS = (1 << VC_BITS); 
  input ON; 
  input clk;    
  input reset; 
  input PROG;
  input c_WEn;
  input c_REn;
     
  input [(DATA_WIDTH * CORE_IN_PORTS) - 1: 0] core_data_in;
  input [CORE_IN_PORTS - 1: 0]core_valid_in; 
  input [(DATA_WIDTH * (SWITCH_TO_SWITCH *6)) - 1: 0] s_flits_in;
  input [(SWITCH_TO_SWITCH *6) - 1: 0]s_valid_in; 
  
  output [(DATA_WIDTH * CORE_OUT_PORTS) - 1: 0] core_data_out; 
  output [CORE_OUT_PORTS - 1: 0]core_valid_out;  
  output [(DATA_WIDTH * (SWITCH_TO_SWITCH *6)) - 1: 0] s_flits_out; 
  output [(SWITCH_TO_SWITCH *6) - 1: 0] s_valid_out; 

  input [((NUM_VCS * CORE_OUT_PORTS) - 1): 0] core_empty_in;
  input [((NUM_VCS * CORE_OUT_PORTS) - 1): 0] core_full_in;  
  input [((NUM_VCS * (SWITCH_TO_SWITCH *6)) - 1): 0] s_empty_in; 
  input [((NUM_VCS * (SWITCH_TO_SWITCH *6)) - 1): 0] s_full_in; 
 
  output [((NUM_VCS * CORE_IN_PORTS) - 1): 0] core_empty_out;
  output [((NUM_VCS * CORE_IN_PORTS) - 1): 0] core_full_out; 
  output [((NUM_VCS * (SWITCH_TO_SWITCH *6)) - 1): 0] s_empty_out;
  output [((NUM_VCS * (SWITCH_TO_SWITCH *6)) - 1): 0] s_full_out;  
  
  input [(ID_BITS - 1): 0]    router_ID;
  input [(FLOW_BITS - 1): 0] rt_flowID; 
  input [RT_WIDTH - 1: 0] rt_entry;
  input report; 
 
  wire [(DATA_WIDTH * CORE_IN_PORTS) - 1: 0] c_flits_in;
  wire [CORE_IN_PORTS - 1: 0]c_valid_in;  
  wire [(DATA_WIDTH * CORE_OUT_PORTS) - 1: 0] c_flits_out; 
  wire [CORE_OUT_PORTS - 1: 0]c_valid_out;  
  
  wire [((NUM_VCS * CORE_IN_PORTS) - 1): 0] c_empty_in;
  wire [((NUM_VCS * CORE_IN_PORTS) - 1): 0] c_full_in; 
  wire [((NUM_VCS * CORE_IN_PORTS) - 1): 0] c_empty_out;
  wire [((NUM_VCS * CORE_IN_PORTS) - 1): 0] c_full_out;  
  
router #(RT_ALG, RT_WIDTH, FLOW_BITS, DATA_WIDTH, CORE_IN_PORTS, CORE_OUT_PORTS,
         SWITCH_TO_SWITCH, VC_BITS, VC_DEPTH_BITS, ID_BITS, ROW, COLUMN) RT (
	ON, clk, reset, PROG, 
	router_ID, rt_flowID, rt_entry,
	c_flits_in, c_valid_in, s_flits_in, s_valid_in, 
	c_empty_in, c_full_in, s_empty_in, s_full_in,	
	s_flits_out, s_valid_out, c_flits_out, c_valid_out, 
	c_empty_out, c_full_out, s_empty_out, s_full_out, 
	report
); 

 core_interface #(DATA_WIDTH, CORE_IN_PORTS, CORE_OUT_PORTS, NUM_VCS) CIF (
	 clk, reset, c_WEn, c_REn, 
	 core_data_in, core_valid_in, core_data_out, core_valid_out,
	 c_flits_in, c_valid_in, c_flits_out, c_valid_out, 
	 c_empty_out, c_full_out, core_empty_in, core_full_in,
	 c_empty_in, c_full_in, core_empty_out, core_full_out
 ); 
 
endmodule
