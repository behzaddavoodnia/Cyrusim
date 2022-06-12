/** @module : ra_core_interface
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

module ra_core_interface #(parameter CORE = 0, ID_BITS = 4, REAL_ADDR_BITS = 16, 
						 DATA_WIDTH = 32, ADDRESS_BITS = 32)(
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
					 // performance reporting
					 report
);

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

// core and cache interface
output core2cache_iRead,  core2cache_iWrite;
output [ADDRESS_BITS-1:0] core2cache_iAddr; 
output [DATA_WIDTH-1:0]   core2cache_iData;   

input [ADDRESS_BITS-1:0] cache2core_iAddr; 
input [DATA_WIDTH-1:0]   cache2core_iData;
input cache2core_iValid, cache2core_iReady;

output core2cache_dRead,  core2cache_dWrite;
output [ADDRESS_BITS-1:0] core2cache_dAddr; 
output [DATA_WIDTH-1:0]   core2cache_dData;
				     
input [ADDRESS_BITS-1:0] cache2core_dAddr; 
input [DATA_WIDTH-1:0]   cache2core_dData; 
input cache2core_dValid, cache2core_dReady;

// core and network interface
output core2net_iRead,    core2net_iWrite;
output [ADDRESS_BITS-1:0] core2net_iAddr; 
output [DATA_WIDTH-1:0]   core2net_iData;   

input [ADDRESS_BITS-1:0] net2core_iAddr; 
input [DATA_WIDTH-1:0]   net2core_iData;
input net2core_iValid,   net2core_iReady;

output core2net_dRead,    core2net_dWrite;
output [ADDRESS_BITS-1:0] core2net_dAddr; 
output [DATA_WIDTH-1:0]   core2net_dData;
				     
input [ADDRESS_BITS-1:0] net2core_dAddr; 
input [DATA_WIDTH-1:0]   net2core_dData; 
input net2core_dValid,   net2core_dReady;
input  report;

wire [ID_BITS - 1: 0] core_ID = CORE; 
// From core buffering 
wire i_mem_busy    = ((~cache2core_iReady) | (~net2core_iReady));
wire d_mem_busy    = ((~cache2core_dReady) | (~net2core_dReady));

reg  i_read_buf, i_write_buf;
reg  [ADDRESS_BITS-1:0] i_addr_buf; 
reg  [DATA_WIDTH-1:0]   i_data_buf;

reg  d_read_buf, d_write_buf;
reg  [ADDRESS_BITS-1:0] d_addr_buf; 
reg  [DATA_WIDTH-1:0]   d_data_buf;

wire i_valid_buf = (i_read_buf | i_write_buf);
wire d_valid_buf = (d_read_buf | d_write_buf);

wire i_buffer = (i_mem_busy & (i_read | i_write) & (~i_valid_buf));
wire d_buffer = (d_mem_busy & (d_read | d_write) & (~d_valid_buf));

wire  cur_i_read   = (reset | i_mem_busy)? 0 : i_valid_buf? i_read_buf  : i_read; 
wire  cur_i_write  = (reset | i_mem_busy)? 0 : i_valid_buf? i_write_buf : i_write; 
wire  [ADDRESS_BITS-1:0] cur_i_address = reset? 0 : i_valid_buf? i_addr_buf  : i_address;
wire  [DATA_WIDTH-1:0]   cur_i_in_data = reset? 0 : i_valid_buf? i_data_buf  : i_in_data;

wire  cur_d_read   = (reset | d_mem_busy)? 0 : d_valid_buf? d_read_buf  : d_read; 
wire  cur_d_write  = (reset | d_mem_busy)? 0 : d_valid_buf? d_write_buf : d_write; 
wire  [ADDRESS_BITS-1:0] cur_d_address = reset? 0 : d_valid_buf? d_addr_buf  : d_address;
wire  [DATA_WIDTH-1:0]   cur_d_in_data = reset? 0 : d_valid_buf? d_data_buf  : d_in_data;

// New logic 
wire  [ID_BITS - 1: 0] zeros = 0;
reg   [ID_BITS - 1: 0] last_i_destination; 
wire  [ID_BITS - 1: 0] i_dest  = reset? core_ID : (cur_i_address >> REAL_ADDR_BITS); 
wire  [ID_BITS - 1: 0] i_destination  = reset? core_ID : (i_dest > 0)? i_dest : last_i_destination;
wire  i_local = (i_destination == core_ID); 
wire  [ID_BITS - 1: 0] d_destination = cur_d_address >> REAL_ADDR_BITS;
wire  d_local = (d_destination == core_ID);
 	 
assign core2cache_iRead  = i_local?  cur_i_read    : 0; 
assign core2cache_iWrite = i_local?  cur_i_write   : 0; 
assign core2cache_iAddr  = i_local?  cur_i_address : 0; 
assign core2cache_iData  = i_local?  cur_i_in_data : 0; 

assign core2net_iRead    = i_local?  0 : cur_i_read; 
assign core2net_iWrite   = i_local?  0 : cur_i_write;
assign core2net_iAddr    = i_local?  0 : cur_i_address;
assign core2net_iData    = i_local?  0 : cur_i_in_data;	

assign core2cache_dRead  = d_local?  cur_d_read    : 0; 
assign core2cache_dWrite = d_local?  cur_d_write   : 0; 
assign core2cache_dAddr  = d_local?  cur_d_address : 0; 
assign core2cache_dData  = d_local?  cur_d_in_data : 0; 

assign core2net_dRead    = d_local?  0 : cur_d_read; 
assign core2net_dWrite   = d_local?  0 : cur_d_write;
assign core2net_dAddr    = d_local?  0 : cur_d_address;
assign core2net_dData    = d_local?  0 : cur_d_in_data;

// network and cache to core 
assign i_out_addr = cache2core_iValid? {i_dest, cache2core_iAddr[REAL_ADDR_BITS-1: 0]} : 
                                       {i_dest, net2core_iAddr[REAL_ADDR_BITS-1: 0]};		 
assign i_valid    = cache2core_iValid? cache2core_iValid : net2core_iValid; 
assign i_out_data = cache2core_iValid? cache2core_iData  : net2core_iData;	
assign i_ready    = (cache2core_iReady & net2core_iReady); 

assign d_out_addr = cache2core_dValid? cache2core_dAddr  : net2core_dAddr;
assign d_valid    = cache2core_dValid? cache2core_dValid : net2core_dValid; 
assign d_out_data = cache2core_dValid? cache2core_dData  : net2core_dData;
assign d_ready    = (cache2core_dReady & net2core_dReady);

 always @ (posedge clock) begin  
	last_i_destination <= reset? 0 : i_destination;
	
	i_read_buf   <= reset? 0 : i_buffer?  i_read    : (~i_mem_busy)? 0 : i_read_buf; 
	i_write_buf  <= reset? 0 : i_buffer?  i_write   : (~i_mem_busy)? 0 : i_write_buf; 
	i_addr_buf   <= reset? 0 : i_buffer?  i_address : (~i_mem_busy)? 0 : i_addr_buf; 
	i_data_buf   <= reset? 0 : i_buffer?  i_in_data : (~i_mem_busy)? 0 : i_data_buf; 
	
	d_read_buf   <= reset? 0 : d_buffer? d_read    : (~d_mem_busy)? 0 : d_read_buf; 
	d_write_buf  <= reset? 0 : d_buffer? d_write   : (~d_mem_busy)? 0 : d_write_buf; 
	d_addr_buf   <= reset? 0 : d_buffer? d_address : (~d_mem_busy)? 0 : d_addr_buf; 
	d_data_buf   <= reset? 0 : d_buffer? d_in_data : (~d_mem_busy)? 0 : d_data_buf;  
 end

reg [31:0] local_access; 
reg [31:0] remote_access; 

always @ (posedge clock) begin   
	if(reset) begin 
		local_access  <= 0; 
		remote_access <= 0; 
	end 
	else begin 
		if(core2cache_dRead | core2cache_dWrite) local_access  <= local_access + 1; 
		if(core2net_dRead | core2net_dWrite) remote_access     <= remote_access + 1; 
	end 

   if (report) begin 
	  $display ("------------------------- Core %d data back-end ------------------------------", core_ID);  
	  $display ("Local accesses [%d]  Remote services [%d]", local_access, remote_access);
	  $display ("------------------------------------------------------------------------------");
	 end 
 end
 
/* 
always @ (posedge clock) begin  
	$display ("--------------------------------Core %d front end ----------------------------------", core_ID);   
	$display ("iRead [%b]\t\t\t|tempRead [%b]\t\t|dRead [%b]\t\t|tempRead [%b]", i_read, i_read_buf, d_read, d_read_buf);
	$display ("iWrite [%b]\t\t\t|tempWrite[%b]\t\t|dWrite [%b]\t\t|tempWrite[%b]", i_write, i_write_buf, d_write, d_write_buf);
	$display ("iAddress [%h]\t\t|tempAddress [%h]\t|dAddress [%h]\t|tempAddress [%h]", i_address, i_addr_buf, d_address, d_addr_buf);
	$display ("iIn_data [%h]\t\t|tempData [%h]\t|dIn_data [%h]\t|tempData [%h]", i_in_data, i_data_buf, d_in_data, d_data_buf);
	$display ("iLocal [%b]\t\t\t\t\t\t|dLocal [%b]", i_local, d_local);
	$display ("iOut_addr [%h]\t\t\t\t\t|dOut_addr [%h]", i_out_addr, d_out_addr);
	$display ("iOut_data [%h]\t\t\t\t\t|dOut_data [%h]", i_out_data, d_out_data);
	$display ("iValid [%b]\t\t\t\t\t\t|dValid [%b]", i_valid, d_valid);
	$display ("iReady [%b]\t\t\t\t\t\t|dReady [%b]", i_ready, d_ready);
	$display ("cache2core_iValid [%b]\t\t\t\t|net2core_iValid [%b]", cache2core_iValid , net2core_iValid);
	$display ("cache2core_dValid [%b]\t\t\t\t|net2core_dValid [%b]", cache2core_dValid , net2core_dValid);
	$display ("core2cache_iRead [%b]\t\t\t\t|core2cache_iWrite [%b]", core2cache_iRead , core2cache_iWrite);
end
//*/
endmodule