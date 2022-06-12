/** @module : RA_Mem_System_Wrapper
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
// Mem_System_Wrapper for local memory and network 
module ra_mem_system_wrapper #(parameter CORE = 0, ID_BITS = 4, REAL_ADDR_BITS = 16, 
							DATA_WIDTH = 32, INDEX_BITS = 6, OFFSET_BITS = 3, 
							ADDRESS_BITS = 32, INIT_FILE = "memory.mem",IN_PORTS = 1, 
							OUT_PORTS = 1, VC_BITS = 1, VC_DEPTH_BITS = 4,
                            MSG_BITS = 3, EXTRA  = 2, TYPE_BITS = 2)( // report is used to show  
						                                              // performance statistics
             		 clock, reset,  
				     i_read, i_write, 
					 i_address, i_in_data, 
					 
				     i_out_addr, i_out_data, 
					 i_valid, i_ready,
				     
				     d_read, d_write, 
					 d_address, d_in_data, 
					 
				     d_out_addr, d_out_data, 
					 d_valid, d_ready, 
				     
				     from_core_flit, v_from_core, 
				     from_core_empty, from_core_full,
  
  					 to_core_flit, v_to_core,
  					 to_core_empty, to_core_full, 
					 // performance reporting
					 report
);

localparam VC_PER_PORTS    = (1 << VC_BITS); 
localparam FLOW_BITS       = (2*ID_BITS) + EXTRA;
localparam FLIT_WIDTH      = FLOW_BITS + TYPE_BITS + VC_BITS + DATA_WIDTH;
localparam NUM_CACHES      = 2;
localparam TOTAL_CORES     = 1 << ID_BITS; 
localparam MEM_ADDR_BITS   = REAL_ADDR_BITS + ID_BITS;
localparam TOTAL_MEM_SPACE = 1 << MEM_ADDR_BITS; 
localparam LOCAL_MEM_SIZE  = 1 << (MEM_ADDR_BITS - ID_BITS); 

input clock, reset;
input  i_read, i_write;
input  [ADDRESS_BITS-1:0] i_address;
input  [DATA_WIDTH-1:0] i_in_data;

output i_valid, i_ready;
output [DATA_WIDTH-1:0] i_out_data;
output [ADDRESS_BITS-1:0] i_out_addr;

input  d_read, d_write;
input  [ADDRESS_BITS-1:0] d_address;
input  [DATA_WIDTH-1:0] d_in_data;

output d_valid, d_ready;
output [DATA_WIDTH-1:0] d_out_data;
output [ADDRESS_BITS-1:0] d_out_addr;

output [(FLIT_WIDTH * IN_PORTS) -1:0] from_core_flit;
output [IN_PORTS-1: 0] v_from_core;
output [(VC_PER_PORTS * IN_PORTS) -1:0] from_core_empty;
output [(VC_PER_PORTS * IN_PORTS) -1:0] from_core_full; 
  
input  [(FLIT_WIDTH * OUT_PORTS) -1:0] to_core_flit;
input  [OUT_PORTS-1: 0] v_to_core;
input  [(VC_PER_PORTS * IN_PORTS) -1:0] to_core_empty;
input  [(VC_PER_PORTS * IN_PORTS) -1:0] to_core_full;
input  report;

wire [ID_BITS - 1: 0] core_ID = CORE; 
//cache - memory 
wire  [(MSG_BITS * NUM_CACHES)-1:0]    cache2mem_msg; 
wire [(ADDRESS_BITS * NUM_CACHES)-1:0] cache2mem_address; 
wire [(DATA_WIDTH * NUM_CACHES)-1:0]   cache2mem_data;

wire [(MSG_BITS * NUM_CACHES)-1:0]     mem2cache_msg; 
wire [(ADDRESS_BITS * NUM_CACHES)-1:0] mem2cache_address; 
wire [(DATA_WIDTH * NUM_CACHES)-1:0]   mem2cache_data;

// core front end
wire  core2cache_iRead, core2cache_iWrite;
wire  [ADDRESS_BITS-1:0] core2cache_iAddr; 
wire  [DATA_WIDTH-1:0]   core2cache_iData;  

wire  [ADDRESS_BITS-1:0] cache2core_iAddr; 
wire  [DATA_WIDTH-1:0]   cache2core_iData;
wire  cache2core_iValid, cache2core_iReady;

wire  core2cache_dRead, core2cache_dWrite;
wire  [ADDRESS_BITS-1:0] core2cache_dAddr; 
wire  [DATA_WIDTH-1:0]   core2cache_dData;  
				     
wire  [ADDRESS_BITS-1:0] cache2core_dAddr; 
wire  [DATA_WIDTH-1:0]   cache2core_dData; 
wire  cache2core_dValid, cache2core_dReady;

//packetizer
wire  net2cache_iRead, net2cache_iWrite;
wire  [ADDRESS_BITS-1:0]net2cache_iAddr; 
wire  [DATA_WIDTH-1:0]   net2cache_iData;

wire [ADDRESS_BITS-1:0] cache2net_iAddr; 
wire [DATA_WIDTH-1:0] cache2net_iData;
wire cache2net_iValid, cache2net_iReady;

wire  net2cache_dRead, net2cache_dWrite; 
wire  [ADDRESS_BITS-1:0] net2cache_dAddr;
wire  [DATA_WIDTH-1:0]   net2cache_dData;

wire [ADDRESS_BITS-1:0] cache2net_dAddr; 
wire [DATA_WIDTH-1:0] cache2net_dData;
wire cache2net_dValid, cache2net_dReady;

wire  core2net_iRead, core2net_iWrite;
wire  [ADDRESS_BITS-1:0] core2net_iAddr; 
wire  [DATA_WIDTH-1:0]   core2net_iData;  

wire  [ADDRESS_BITS-1:0] net2core_iAddr; 
wire  [DATA_WIDTH-1:0]   net2core_iData;
wire  net2core_iValid, net2core_iReady;

wire  core2net_dRead, core2net_dWrite;
wire  [ADDRESS_BITS-1:0] core2net_dAddr; 
wire  [DATA_WIDTH-1:0]   core2net_dData;  
				     
wire  [ADDRESS_BITS-1:0] net2core_dAddr; 
wire  [DATA_WIDTH-1:0]   net2core_dData; 
wire  net2core_dValid, net2core_dReady;

// cache 
wire [1:0] read, write;	  
wire [(2*ADDRESS_BITS)-1:0] address;	 
wire [(2*DATA_WIDTH)-1:0] in_data; 

wire [1:0] valid, ready;
wire[(2*DATA_WIDTH)-1:0] out_data;
wire[(2*ADDRESS_BITS)-1:0] out_address;	


ra_core_interface #(CORE, ID_BITS, REAL_ADDR_BITS, DATA_WIDTH, ADDRESS_BITS) core_inter(
             		 clock, reset, 
				     i_read, i_write, 
					 i_address, i_in_data, 
					 
				     i_out_addr, i_out_data, 
					 i_valid, i_ready,
				     
				     d_read, d_write, 
					 d_address, d_in_data, 
					 
				     d_out_addr, d_out_data, 
					 d_valid, d_ready, 
					 
					// core and cache interface
					core2cache_iRead, core2cache_iWrite, 
					core2cache_iAddr, core2cache_iData, 

					cache2core_iAddr, cache2core_iData, 
					cache2core_iValid, cache2core_iReady,

					core2cache_dRead, core2cache_dWrite, 
					core2cache_dAddr, core2cache_dData, 

					cache2core_dAddr, cache2core_dData, 
					cache2core_dValid, cache2core_dReady, 
					 
					// core and network interface
				     core2net_iRead, core2net_iWrite, 
					 core2net_iAddr, core2net_iData, 
					 
				     net2core_iAddr, net2core_iData, 
					 net2core_iValid, net2core_iReady,
				     
				     core2net_dRead, core2net_dWrite, 
					 core2net_dAddr, core2net_dData, 
					 
				     net2core_dAddr, net2core_dData, 
					 net2core_dValid, net2core_dReady, 
					 report
);

ra_cache_interface #(CORE, ID_BITS, REAL_ADDR_BITS, DATA_WIDTH, ADDRESS_BITS) cache_inter (
             		 clock, reset,

					// core and cache interface
					core2cache_iRead, core2cache_iWrite, 
					core2cache_iAddr, core2cache_iData, 

					cache2core_iAddr, cache2core_iData, 
					cache2core_iValid, cache2core_iReady,

					core2cache_dRead, core2cache_dWrite, 
					core2cache_dAddr, core2cache_dData, 

					cache2core_dAddr, cache2core_dData, 
					cache2core_dValid, cache2core_dReady, 
		
					// network and cache interface	
				     net2cache_iRead, net2cache_iWrite, 
					 net2cache_iAddr, net2cache_iData, 
					 
				     cache2net_iAddr, cache2net_iData, 
					 cache2net_iValid, cache2net_iReady,
				     
				     net2cache_dRead, net2cache_dWrite, 
					 net2cache_dAddr, net2cache_dData, 
					 
				     cache2net_dAddr, cache2net_dData, 
					 cache2net_dValid, cache2net_dReady, 
					 
					 // cache system
					 read, write, address, in_data, 
				     out_address, out_data, valid, ready, 
					 report
);

ra_packetizer #(CORE, DATA_WIDTH, ADDRESS_BITS, REAL_ADDR_BITS, 
             MEM_ADDR_BITS, IN_PORTS, OUT_PORTS, VC_BITS, VC_DEPTH_BITS,
             ID_BITS, EXTRA, TYPE_BITS) network_packetizer (
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

unified_caches #(CORE, DATA_WIDTH, INDEX_BITS, OFFSET_BITS, ADDRESS_BITS, MSG_BITS) 
             unified (
				     clock, reset,
				       
				     read, write, address, in_data, 
				     out_address, out_data, valid, ready,
				     
				     mem2cache_msg, 
				     mem2cache_address, mem2cache_data, 
				     
				     cache2mem_msg, 
				     cache2mem_address, cache2mem_data, 
					 report
); 

main_memory #(CORE, DATA_WIDTH, ADDRESS_BITS, REAL_ADDR_BITS, NUM_CACHES, MSG_BITS, OFFSET_BITS, INIT_FILE) 
              m_memory (
				     clock, reset,  
				     				     
				     cache2mem_msg, 
				     cache2mem_address, cache2mem_data,
				     
				     mem2cache_msg, 
				     mem2cache_address, mem2cache_data
);

/*
 always @ (posedge clock) begin   
	$display ("--------------------------------System Wrapper Core %d ----------------------------------", core_ID);  
	$display ("iRead [%b]\t\t\t|dRead [%b]", i_read, d_read);
	$display ("iWrite [%b]\t\t\t|dWrite [%b]", i_write, d_write);
	$display ("iAddress [%h]\t\t|dAddress [%h]", i_address, d_address);
	$display ("iIn_data [%h]\t\t|dIn_data [%h]", i_in_data, d_in_data);
	$display ("|");
	$display ("iOut_addr [%h]\t\t|dOut_addr [%h]", i_out_addr, d_out_addr);
	$display ("iOut_data [%h]\t\t|dOut_data [%h]", i_out_data, d_out_data);
	$display ("iValid [%b]\t\t\t|dValid [%b]", i_valid, d_valid);
	$display ("iReady [%b]\t\t\t|dReady [%b]", i_ready, d_ready);
	$display ("|");	
	$display ("Core2Cache iRead [%b]\t\t|Core2Cache dRead [%b]", core2cache_iRead, core2cache_dRead);
	$display ("Core2Cache iWrite [%b]\t\t|Core2Cache dWrite [%b]", core2cache_iWrite, core2cache_dWrite);
	$display ("Core2Cache iAddress [%h]\t|Core2Cache dAddress [%h]", core2cache_iAddr, core2cache_dAddr);  
	$display ("Core2Cache iData [%h]\t|Core2Cache dData [%h]", core2cache_iData, core2cache_dData);
	$display ("|");
	$display ("Cache2Core iAddress [%h]\t|Cache2Core dAddress [%h]", cache2core_iAddr, cache2core_dAddr);  
	$display ("Cache2Core iData [%h]\t|Cache2Core dData [%h]", cache2core_iData, cache2core_dData);
	$display ("Cache2Core iValid [%b]\t\t|Cache2Core dValid [%b]", cache2core_iValid, cache2core_dValid);
	$display ("Cache2Core iReady [%b]\t\t|Cache2Core dReady [%b]", cache2core_iReady, cache2core_dReady);
	$display ("|");
	$display ("Core2Net iRead [%b]\t\t|Core2Net dRead [%b]", core2net_iRead, core2net_dRead);
	$display ("Core2Net iWrite [%b]\t\t|Core2Net dWrite [%b]", core2net_iWrite, core2net_dWrite);
	$display ("Core2Net iAddress [%h]\t|Core2Net dAddress [%h]", core2net_iAddr, core2net_dAddr);  
	$display ("Core2Net iData [%h]\t|Core2Net dData [%h]", core2net_iData, core2net_dData);
	$display ("|");
	$display ("Net2Core iAddress [%h]\t|Net2Core dAddress [%h]", net2core_iAddr, net2core_dAddr);  
	$display ("Net2Core iData [%h]\t|Net2Core dData [%h]", net2core_iData, net2core_dData);
	$display ("Net2Core iValid [%b]\t\t|Net2Core dValid [%b]", net2core_iValid, net2core_dValid);
	$display ("Net2Core iReady [%b]\t\t|Net2Core dReady [%b]", net2core_iReady, net2core_dReady);
	$display ("|");
	$display ("Net2Cache iRead [%b]\t\t|Net2Cache dRead [%b]", net2cache_iRead, net2cache_dRead);
	$display ("Net2Cache iWrite [%b]\t\t|Net2Cache dWrite [%b]", net2cache_iWrite, net2cache_dWrite);
	$display ("Net2Cache iAddress [%h]\t|Net2Cache dAddress [%h]", net2cache_iAddr, net2cache_dAddr);  
	$display ("Net2Cache iData [%h]\t|Net2Cache dData [%h]", net2cache_iData, net2cache_dData);
	$display ("|");
	$display ("Cache2Net iAddress [%h]\t|Cache2Net dAddress [%h]", cache2net_iAddr, cache2net_dAddr);  
	$display ("Cache2Net iData [%h]\t|Cache2Net dData [%h]", cache2net_iData, cache2net_dData);
	$display ("cache2Net iValid [%b]\t\t|Cache2Net dValid [%b]", cache2net_iValid, cache2net_dValid);
	$display ("Cache2Net iReady [%b]\t\t|Cache2Net dReady [%b]", cache2net_iReady, cache2net_dReady);
	$display ("--- Cache ---");
	$display ("iRead [%b]\t\t\t|dRead [%b]", read[0], read[1]);
	$display ("iWrite [%b]\t\t\t|dWrite [%b]", write[0], write[1]);
	$display ("iAddress [%h]\t\t|dAddress [%h]", address[ADDRESS_BITS-1:0], address[(2*ADDRESS_BITS)-1 -:ADDRESS_BITS]);
	$display ("iIn_data [%h]\t\t|dIn_data [%h]", in_data[DATA_WIDTH-1 :0], in_data[(2*DATA_WIDTH)-1 -:DATA_WIDTH]);
	$display ("iOut_Addr [%h]\t\t|dOut_Addr [%h]", out_address[ADDRESS_BITS-1:0], out_address[(2*ADDRESS_BITS)-1 -:ADDRESS_BITS]);
	$display ("iOut_data [%h]\t\t|dOut_data [%h]", out_data[DATA_WIDTH-1 :0], out_data[(2*DATA_WIDTH)-1 -:DATA_WIDTH]);
	$display ("iValid [%b]\t\t\t|dValid [%b]", valid[0], valid[1]);
	$display ("iReady [%b]\t\t\t|dReady [%b]", ready[0], ready[1]);
	$display ("----------------------------------------------------------------------------------------");
 end 
//*/
endmodule