/** @module : RA_Packetizer
 *  @author : Behzad Davoodnia
 *  Remote access cache protocol for both the instruction and data caches. 
 
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

module ra_packetizer #(parameter CORE = 0, DATA_WIDTH = 32, ADDRESS_BITS = 32, 
				       REAL_ADDR_BITS = 16, MEM_ADDR_BITS = 20, 
					   IN_PORTS = 1, OUT_PORTS = 1, VC_BITS = 1, VC_DEPTH_BITS = 4,
                       ID_BITS = 4, EXTRA  = 2, TYPE_BITS = 2) ( 
					
				     clock, reset, 
					// network and local cache interface	
				     net2cache_iRead, net2cache_iWrite, 
					 net2cache_iAddr, net2cache_iData, 
					 
				     cache2net_iAddr, cache2net_iData, 
					 cache2net_iValid, cache2net_iReady,
				     
				     net2cache_dRead, net2cache_dWrite, 
					 net2cache_dAddr, net2cache_dData, 
					 
				     cache2net_dAddr, cache2net_dData, 
					 cache2net_dValid, cache2net_dReady,
					 
					 // core and network interface
				     core2net_iRead, core2net_iWrite, 
					 core2net_iAddr, core2net_iData, 
					 
				     net2core_iAddr, net2core_iData, 
					 net2core_iValid, net2core_iReady,
				     
				     core2net_dRead, core2net_dWrite, 
					 core2net_dAddr, core2net_dData, 
					 
				     net2core_dAddr, net2core_dData, 
					 net2core_dValid, net2core_dReady,
					 
					 //packets
				     from_core_flit, v_from_core, 
				     from_core_empty, from_core_full,
  
  					 to_core_flit, v_to_core,
  					 to_core_empty, to_core_full  
				     
);
localparam VC_PER_PORTS  = (1 << VC_BITS); 
localparam FLOW_BITS     = (2*ID_BITS) + EXTRA;  
localparam FLIT_WIDTH    = FLOW_BITS + TYPE_BITS + VC_BITS + DATA_WIDTH;

input clock, reset; 

input core2net_iRead,    core2net_iWrite;
input [ADDRESS_BITS-1:0] core2net_iAddr; 
input [DATA_WIDTH-1:0]   core2net_iData;  
					 				     
input core2net_dRead,    core2net_dWrite;
input [ADDRESS_BITS-1:0] core2net_dAddr; 
input [DATA_WIDTH-1:0]   core2net_dData; 

input cache2net_iValid , cache2net_iReady;
input [ADDRESS_BITS-1:0] cache2net_iAddr;
input [DATA_WIDTH-1:0]   cache2net_iData;

input cache2net_dValid,  cache2net_dReady;
input [ADDRESS_BITS-1:0] cache2net_dAddr;
input [DATA_WIDTH-1:0]   cache2net_dData;

output net2cache_iRead, net2cache_iWrite;
output [ADDRESS_BITS-1:0]net2cache_iAddr; 
output [DATA_WIDTH-1:0]   net2cache_iData;
				     
output net2cache_dRead, net2cache_dWrite; 
output [ADDRESS_BITS-1:0] net2cache_dAddr;
output [DATA_WIDTH-1:0]   net2cache_dData;

output [ADDRESS_BITS-1:0] net2core_iAddr; 
output [DATA_WIDTH-1:0]   net2core_iData;
output net2core_iValid,   net2core_iReady;
				     
output [ADDRESS_BITS-1:0] net2core_dAddr; 
output [DATA_WIDTH-1:0]   net2core_dData; 
output net2core_dValid,   net2core_dReady;
	
output [(FLIT_WIDTH * IN_PORTS) -1:0] from_core_flit;
output [IN_PORTS-1: 0] v_from_core;
output [(VC_PER_PORTS * IN_PORTS) -1:0] from_core_empty;
output [(VC_PER_PORTS * IN_PORTS) -1:0] from_core_full; 
  
input  [(FLIT_WIDTH * OUT_PORTS) -1:0] to_core_flit;
input  [OUT_PORTS-1: 0] v_to_core;
input  [(VC_PER_PORTS * IN_PORTS) -1:0] to_core_empty;
input  [(VC_PER_PORTS * IN_PORTS) -1:0] to_core_full;

wire [ID_BITS - 1: 0] core_ID = CORE; 

wire [FLIT_WIDTH -1:0] p_flit_to_send;
wire pv_send_flit; 				 
wire [FLIT_WIDTH -1:0] p_flit_received; 
wire pv_rec_flit; 
wire p_ready;

wire [FLIT_WIDTH -1:0] c_flit_to_send;
wire cv_send_flit; 				 
wire [FLIT_WIDTH -1:0] c_flit_received; 
wire cv_rec_flit; 
wire c_ready;

ra_packetizer_core #(CORE, DATA_WIDTH, ADDRESS_BITS, REAL_ADDR_BITS, 
					VC_BITS, ID_BITS, EXTRA, TYPE_BITS) ra_core( 
					
				     clock, reset, 
					 
					 // core and packetizer interface
				     core2net_iRead, core2net_iWrite, 
					 core2net_iAddr, core2net_iData, 
					 
				     net2core_iAddr, net2core_iData, 
					 net2core_iValid, net2core_iReady,
				     
				     core2net_dRead, core2net_dWrite, 
					 core2net_dAddr, core2net_dData, 
					 
				     net2core_dAddr, net2core_dData, 
					 net2core_dValid, net2core_dReady,
					 
					 //packets to core
				     p_flit_to_send, pv_send_flit, 
  					 p_flit_received, pv_rec_flit, 
					 p_ready
				     
);

ra_packetizer_cache #(CORE, DATA_WIDTH, ADDRESS_BITS, VC_BITS, 
                    ID_BITS, EXTRA, TYPE_BITS) ra_cache ( 
					
				     clock, reset, 
					 
					// network and local cache interface	
				     net2cache_iRead, net2cache_iWrite, 
					 net2cache_iAddr, net2cache_iData, 
					 
				     cache2net_iAddr, cache2net_iData, 
					 cache2net_iValid, cache2net_iReady,
				     
				     net2cache_dRead, net2cache_dWrite, 
					 net2cache_dAddr, net2cache_dData, 
					 
				     cache2net_dAddr, cache2net_dData, 
					 cache2net_dValid, cache2net_dReady,
					 
					 //packets to cache
				     c_flit_to_send, cv_send_flit, 
  					 c_flit_received, cv_rec_flit, 
					 c_ready
				     
);

ra_packetizer_network #(CORE, DATA_WIDTH, ADDRESS_BITS, IN_PORTS, OUT_PORTS, VC_BITS, 
					VC_DEPTH_BITS, ID_BITS, EXTRA, TYPE_BITS) ra_network ( 
					
				     clock, reset, 

					 //packets to cache
				     c_flit_to_send,  cv_send_flit, 
  					 c_flit_received, cv_rec_flit, 
					 c_ready,
					 
					 //packets to processor
				     p_flit_to_send, pv_send_flit, 
  					 p_flit_received, pv_rec_flit, 
					 p_ready, 
					 
					 //packets to router
				     from_core_flit, v_from_core, 
				     from_core_empty, from_core_full,
  
  					 to_core_flit, v_to_core,
  					 to_core_empty, to_core_full  
				     
);

/*
// Debugging 
 always @ (posedge clock) begin 
	$display ("-----------------------------RA Packetizer Module %d-------------------------------------", core_ID);  
	$display ("--- Core 2 Network ---");  
	$display ("core2net_iRead [%b]\t| core2net_iWrite [%b]\t| core2net_iAddr [%h]\t| core2net_iData [%h]", core2net_iRead, 
	core2net_iWrite , core2net_iAddr, core2net_iData);
	$display ("core2net_dRead [%b]\t| core2net_dWrite [%b]\t| core2net_dAddr [%h]\t| core2net_dData [%h]", core2net_dRead, 
	core2net_dWrite , core2net_dAddr, core2net_dData);
	$display ("--- Cache 2 Network ---"); 
	$display ("cache2net_iReady [%b]\t| cache2net_iValid [%b]\t| cache2net_iAddr [%h]\t| cache2net_iData [%h]", 
	cache2net_iReady, cache2net_iValid , cache2net_iAddr, cache2net_iData);
	$display ("cache2net_dReady [%b]\t| cache2net_dValid [%b]\t| cache2net_dAddr [%h]\t| cache2net_dData [%h] ", 
	cache2net_dReady, cache2net_dValid , cache2net_dAddr, cache2net_dData);	
	$display (""); 
	$display ("From Core Flit [%h] ", from_core_flit);
	$display ("From Core Valid [%b] ", v_from_core);
	$display ("From Core Empty [%b]\t| From Core Full [%b] ", from_core_empty, from_core_full);
	$display (""); 
	$display ("To Core Flit [%h] ", to_core_flit);
	$display ("To Core Valid [%b] ", v_to_core);
	$display ("To Core Empty [%b]\t| To Core Full [%b] ", to_core_empty, to_core_full);
	$display (""); 
	$display ("net2core_iReady [%b]\t| net2core_iValid [%b]\t| net2core_iAddr [%h]\t| net2core_iData [%h]", 
	net2core_iReady, net2core_iValid , net2core_iAddr, net2core_iData);
	$display ("net2core_dReady [%b]\t| net2core_dValid [%b]\t| net2core_dAddr [%h]\t| net2core_dData [%h]", 
	net2core_dReady, net2core_dValid , net2core_dAddr, net2core_dData);
	$display ("net2cache_iRead [%b]\t| net2cache_iWrite [%b]\t| net2cache_iAddr [%h]\t| net2cache_iData [%h]", 
	net2cache_iRead, net2cache_iWrite , net2cache_iAddr, net2cache_iData);
	$display ("net2cache_dRead [%b]\t| net2cache_dWrite [%b]\t| net2cache_dAddr [%h]\t| net2cache_dData [%h]", 
	net2cache_dRead, net2cache_dWrite , net2cache_dAddr, net2cache_dData);
	$display ("-----------------------------------------------------------------------------------------");
 end 	
 //*/
  
endmodule