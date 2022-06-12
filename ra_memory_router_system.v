
/** @module : MemoryRouterSystem
 *  @author : Behzad Davoodnia
 
 *  Copyright (c) 2012 Heracles (CSG/CSAIL/MIT)
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
module memory_router_system #(parameter CORE = 0, ID_BITS = 4, REAL_ADDR_BITS = 16, DATA_WIDTH = 32, INDEX_BITS = 6, 
                            OFFSET_BITS = 3, ADDRESS_BITS = 20, INIT_FILE = "memory.mem",
                            IN_PORTS = 1, OUT_PORTS = 1, VC_BITS = 1, VC_DEPTH_BITS = 4, MSG_BITS = 3, 
                            EXTRA  = 2, TYPE_BITS = 2 , SWITCH_TO_SWITCH  = 1, RT_ALG = 0, ROW = 3,
							COLUMN = 3)( // STATS is used to set number of cycles to collect  
						                   // performance data
             	  	 clock, reset,
				     i_read, i_write, i_address, i_in_data, 
				     i_out_addr, i_out_data, i_valid, i_ready,
				     
				     d_read, d_write, d_address, d_in_data, 
				     d_out_addr, d_out_data, d_valid, d_ready, 
				     
				     ON, PROG, WEn, REn,
				     router_ID, rt_flowID, rt_entry, 

  				     s_flits_in, s_valid_in, 
  					 s_flits_out, s_valid_out, 

  					 s_empty_in, s_full_in, 
					 s_empty_out, s_full_out,
					// performance reporting
					report, fault_status
);

//define the log2 function
function integer log2;
	input integer num;
	integer i, result;
	begin
		for (i = 0; 2 ** i < num; i = i + 1)
			result = i + 1;
		log2 = result;
	end
endfunction

localparam  VC_PER_PORTS  = (1 << VC_BITS); 
localparam  FLOW_BITS = (2*ID_BITS) + EXTRA;  
localparam  FLIT_WIDTH = FLOW_BITS + TYPE_BITS + VC_BITS + DATA_WIDTH;

localparam  PORTS = OUT_PORTS + 4*(SWITCH_TO_SWITCH);
localparam  PORTS_BITS = log2(PORTS); 
localparam  RT_WIDTH = PORTS_BITS + VC_BITS + 1; 

localparam  RA_MSG_BITS = 3; 

input clock, reset;
input  i_read, i_write;
input  [ADDRESS_BITS-1:0] i_address;
input  [DATA_WIDTH-1:0] i_in_data;

input [3:0] fault_status;

output i_valid, i_ready;
output [DATA_WIDTH-1:0] i_out_data;
output [ADDRESS_BITS-1:0] i_out_addr;

input  d_read, d_write;
input  [ADDRESS_BITS-1:0] d_address;
input  [DATA_WIDTH-1:0] d_in_data;

output d_valid, d_ready;
output [DATA_WIDTH-1:0] d_out_data;
output [ADDRESS_BITS-1:0] d_out_addr;

input ON, PROG, WEn, REn;
 
input [(FLIT_WIDTH * (SWITCH_TO_SWITCH *4)) - 1: 0] s_flits_in;
input [(SWITCH_TO_SWITCH *4) - 1: 0]s_valid_in; 

output [(FLIT_WIDTH * (SWITCH_TO_SWITCH *4)) - 1: 0] s_flits_out; 
output [(SWITCH_TO_SWITCH *4) - 1: 0] s_valid_out;

input [((VC_PER_PORTS * (SWITCH_TO_SWITCH *4)) - 1): 0] s_empty_in; 
input [((VC_PER_PORTS * (SWITCH_TO_SWITCH *4)) - 1): 0] s_full_in; 

output [((VC_PER_PORTS * (SWITCH_TO_SWITCH *4)) - 1): 0] s_empty_out;
output [((VC_PER_PORTS * (SWITCH_TO_SWITCH *4)) - 1): 0] s_full_out;  

input [(ID_BITS - 1): 0]    router_ID;
input [(FLOW_BITS - 1): 0] rt_flowID; 
input [RT_WIDTH - 1: 0] rt_entry;
input report;

wire [(FLIT_WIDTH * IN_PORTS) -1:0] from_core_flit;
wire [IN_PORTS-1: 0] v_from_core;
wire [(VC_PER_PORTS * IN_PORTS) -1:0] from_core_empty;
wire [(VC_PER_PORTS * IN_PORTS) -1:0] from_core_full; 

wire  [(FLIT_WIDTH * OUT_PORTS) -1:0] to_core_flit;
wire  [OUT_PORTS-1: 0] v_to_core;
wire  [(VC_PER_PORTS * IN_PORTS) -1:0] to_core_empty;
wire  [(VC_PER_PORTS * IN_PORTS) -1:0] to_core_full;

wire [(ID_BITS - 1): 0]    core_ID = router_ID;
					  
ra_mem_system_wrapper #(CORE, ID_BITS, REAL_ADDR_BITS, DATA_WIDTH, INDEX_BITS, 
					  OFFSET_BITS, ADDRESS_BITS, INIT_FILE,IN_PORTS, OUT_PORTS, 
					  VC_BITS, VC_DEPTH_BITS, RA_MSG_BITS, EXTRA, TYPE_BITS)
                      mem_packetizer (
					 clock, reset, 
					 
				     i_read, i_write, i_address, i_in_data, 
				     i_out_addr, i_out_data, i_valid, i_ready,
				     
				     d_read, d_write, d_address, d_in_data, 
				     d_out_addr, d_out_data, d_valid, d_ready, 
				     
				     from_core_flit, v_from_core, 
				     from_core_empty, from_core_full,
  
  					  to_core_flit, v_to_core,
  					  to_core_empty, to_core_full, 
					  report
);

router_wrapper #(RT_ALG, RT_WIDTH, FLOW_BITS, FLIT_WIDTH, IN_PORTS, 
						  OUT_PORTS, SWITCH_TO_SWITCH, VC_BITS, 
						  VC_DEPTH_BITS, ID_BITS, ROW, COLUMN) network_Interface (
  ON, clock, reset, PROG, WEn, REn,
     
  from_core_flit, v_from_core, 
  s_flits_in, s_valid_in, 
  
  to_core_flit, v_to_core,  
  s_flits_out, s_valid_out, 

  from_core_empty, from_core_full, 
  s_empty_in, s_full_in, 
  to_core_empty, to_core_full, 
  s_empty_out, s_full_out,  
  
  router_ID, rt_flowID, rt_entry, 
  report,fault_status
);

endmodule
