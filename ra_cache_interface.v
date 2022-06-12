/** @module : ra_cache_interface
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
 
module ra_cache_interface #(parameter CORE = 0, ID_BITS = 4, REAL_ADDR_BITS = 16, 
							DATA_WIDTH = 32, ADDRESS_BITS = 32 )(
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
					 // performance reporting
					 report
);

input clock, reset; 

// core and cache interface
input core2cache_iRead,  core2cache_iWrite;
input [ADDRESS_BITS-1:0] core2cache_iAddr; 
input [DATA_WIDTH-1:0]   core2cache_iData;   

output [ADDRESS_BITS-1:0] cache2core_iAddr; 
output [DATA_WIDTH-1:0]   cache2core_iData;
output cache2core_iValid, cache2core_iReady;

input core2cache_dRead,  core2cache_dWrite;
input [ADDRESS_BITS-1:0] core2cache_dAddr; 
input [DATA_WIDTH-1:0]   core2cache_dData;
				     
output [ADDRESS_BITS-1:0] cache2core_dAddr; 
output [DATA_WIDTH-1:0]   cache2core_dData; 
output cache2core_dValid, cache2core_dReady;

// network and cache interface
input net2cache_iRead, net2cache_iWrite;
input [ADDRESS_BITS-1:0]net2cache_iAddr; 
input [DATA_WIDTH-1:0]   net2cache_iData;

output cache2net_iValid , cache2net_iReady;
output [ADDRESS_BITS-1:0] cache2net_iAddr;
output [DATA_WIDTH-1:0]   cache2net_iData;

input net2cache_dRead, net2cache_dWrite; 
input [ADDRESS_BITS-1:0] net2cache_dAddr;
input [DATA_WIDTH-1:0]   net2cache_dData;

output cache2net_dValid,  cache2net_dReady;
output [ADDRESS_BITS-1:0] cache2net_dAddr;
output [DATA_WIDTH-1:0]   cache2net_dData;

// cahce system 
output [1:0] read, write;
output [(2*ADDRESS_BITS)-1:0] address;
output [(2*DATA_WIDTH)-1:0] in_data;

input [1:0] valid, ready;
input [(2*ADDRESS_BITS)-1:0] out_address;
input[(2*DATA_WIDTH)-1:0] out_data;
input  report;

wire [ID_BITS - 1: 0] core_ID = CORE;
wire i_read,  d_read; 
wire i_write, d_write; 
wire [ADDRESS_BITS-1:0]  i_address, d_address;
wire [DATA_WIDTH-1:0]    i_in_data, d_in_data; 

wire i_valid = valid[0]; 
wire d_valid = valid[1]; 
wire i_ready = ready[0]; 
wire d_ready = ready[1]; 

wire  [ID_BITS - 1: 0] zeros = 0;
wire [ADDRESS_BITS-1:0]  i_out_addr  = out_address[(ADDRESS_BITS-1) -: ADDRESS_BITS];
wire [ADDRESS_BITS-1:0]  d_out_addr  = out_address[((2*ADDRESS_BITS)-1) -: ADDRESS_BITS];
wire [ADDRESS_BITS-1:0]  i_out_address  = {core_ID, i_out_addr[REAL_ADDR_BITS-1: 0]};
wire [ADDRESS_BITS-1:0]  d_out_address  = {core_ID, d_out_addr[REAL_ADDR_BITS-1: 0]};
	
wire [DATA_WIDTH-1:0]    i_out_data  = out_data[(DATA_WIDTH-1) -: DATA_WIDTH];
wire [DATA_WIDTH-1:0]    d_out_data  = out_data[((2*DATA_WIDTH)-1) -: DATA_WIDTH];
				 
assign read    = {d_read, i_read}; 
assign write   = {d_write, i_write}; 
assign address = {zeros,d_address[REAL_ADDR_BITS-1: 0],zeros,i_address[REAL_ADDR_BITS-1: 0]}; 
assign in_data = {d_in_data, i_in_data}; 

reg  i_net_read_buf, i_net_write_buf;
reg  [ADDRESS_BITS-1:0] i_net_addr_buf; 
reg  [DATA_WIDTH-1:0]   i_net_data_buf;

reg  d_net_read_buf, d_net_write_buf;
reg  [ADDRESS_BITS-1:0] d_net_addr_buf; 
reg  [DATA_WIDTH-1:0]   d_net_data_buf;

reg  i_core_read_buf, i_core_write_buf;
reg  [ADDRESS_BITS-1:0] i_core_addr_buf; 
reg  [DATA_WIDTH-1:0]   i_core_data_buf;

reg  d_core_read_buf, d_core_write_buf;
reg  [ADDRESS_BITS-1:0] d_core_addr_buf; 
reg  [DATA_WIDTH-1:0]   d_core_data_buf;

reg  i_core_service, d_core_service;
reg  [ADDRESS_BITS-1:0] i_core_address, d_core_address; 

reg  i_net_service, d_net_service;
reg  [ADDRESS_BITS-1:0] i_net_address, d_net_address; 

reg p_i_busy, p_i_op; 
reg p_d_busy, p_d_op; 

wire i_op = (i_read | i_write); 
wire d_op = (d_read | d_write); 

wire i_core_op = (core2cache_iRead | core2cache_iWrite); 
wire d_core_op = (core2cache_dRead | core2cache_dWrite);

wire i_core_buffer = (i_core_read_buf | i_core_write_buf);
wire d_core_buffer = (d_core_read_buf | d_core_write_buf);

wire i_net_op  = (net2cache_iRead | net2cache_iWrite); 
wire d_net_op  = (net2cache_dRead | net2cache_dWrite); 

wire i_net_buffer = (i_net_read_buf | i_net_write_buf);
wire d_net_buffer = (d_net_read_buf | d_net_write_buf);

wire i_core_valid = i_valid & (i_core_address == i_out_address) & i_core_service; 
wire d_core_valid = d_valid & (d_core_address == d_out_address) & d_core_service;

wire i_net_valid = i_valid & (i_net_address == i_out_address) & i_net_service; 
wire d_net_valid = d_valid & (d_net_address == d_out_address) & d_net_service;

wire i_core_clear = (i_core_valid & (i_out_address == i_core_addr_buf)); 
wire d_core_clear = (d_core_valid & (d_out_address == d_core_addr_buf)); 

wire i_net_clear = (i_net_valid & (i_out_address == i_net_addr_buf)); 
wire d_net_clear = (d_net_valid & (d_out_address == d_net_addr_buf)); 

wire i_busy = reset? 0 : (p_i_busy | p_i_op) & (~i_valid); 
wire d_busy = reset? 0 : (p_d_busy | p_d_op) & (~d_valid); 


assign i_read      = reset? 0 : i_busy? 0: (i_core_buffer & ~(i_core_clear))? i_core_read_buf  : 
                     i_core_op? core2cache_iRead  : (i_net_buffer & ~(i_net_clear))? i_net_read_buf  : 
					 i_net_op? net2cache_iRead : 0;  
assign i_write     = reset? 0 : i_busy? 0 : (i_core_buffer & ~(i_core_clear))? i_core_write_buf : 
                     i_core_op? core2cache_iWrite : (i_net_buffer & ~(i_net_clear))? i_net_write_buf : 
					 i_net_op? net2cache_iWrite: 0; 
assign i_address   = reset? 0 : i_busy? 0 : (i_core_buffer & ~(i_core_clear))? i_core_addr_buf  : 
                     i_core_op? core2cache_iAddr  : (i_net_buffer & ~(i_net_clear))? i_net_addr_buf  : 
					 i_net_op? net2cache_iAddr : 0; 
assign i_in_data   = reset? 0 : i_busy? 0 : (i_core_buffer & ~(i_core_clear))? i_core_data_buf  : 
                     i_core_op? core2cache_iData  : (i_net_buffer & ~(i_net_clear))? i_net_data_buf  : 
					 i_net_op? net2cache_iData : 0; 

assign d_read      = reset? 0 : d_busy? 0 : (d_core_buffer & ~(d_core_clear))? d_core_read_buf  : 
                     d_core_op? core2cache_dRead  : (d_net_buffer & ~(d_net_clear))? d_net_read_buf  : 
					 d_net_op? net2cache_dRead : 0; 
assign d_write     = reset? 0 : d_busy? 0 : (d_core_buffer & ~(d_core_clear))? d_core_write_buf : 
                     d_core_op? core2cache_dWrite : (d_net_buffer & ~(d_net_clear))? d_net_write_buf : 
					 d_net_op? net2cache_dWrite: 0; 
assign d_address   = reset? 0 : d_busy? 0 : (d_core_buffer & ~(d_core_clear))? d_core_addr_buf  : 
                     d_core_op? core2cache_dAddr  : (d_net_buffer & ~(d_net_clear))? d_net_addr_buf  : 
					 d_net_op? net2cache_dAddr : 0; 
assign d_in_data   = reset? 0 : d_busy? 0 : (d_core_buffer & ~(d_core_clear))? d_core_data_buf  : 
                     d_core_op? core2cache_dData  : (d_net_buffer & ~(d_net_clear))? d_net_data_buf  : 
					 d_net_op? net2cache_dData : 0;  

// Cache outputs 
assign cache2core_iAddr  = i_core_valid? i_out_address : 0; 
assign cache2core_iData  = i_core_valid? i_out_data    : 0; 
assign cache2core_iValid = i_core_valid? i_valid       : 0;
assign cache2core_iReady = (i_ready & (~i_net_buffer) & (~i_net_op)); 

assign cache2core_dAddr  = d_core_valid? d_out_address : 0; 
assign cache2core_dData  = d_core_valid? d_out_data    : 0; 
assign cache2core_dValid = d_core_valid? d_valid       : 0;
assign cache2core_dReady = (d_ready & (~d_net_buffer) & (~d_net_op));
		
assign cache2net_iAddr   = i_net_valid? i_out_address  : 0;
assign cache2net_iData   = i_net_valid? i_out_data     : 0;
assign cache2net_iValid  = i_net_valid? i_valid        : 0;
assign cache2net_iReady  = (i_ready & (~i_net_buffer) & (~i_core_op)); 

assign cache2net_dAddr   = d_net_valid? d_out_address  : 0;
assign cache2net_dData   = d_net_valid? d_out_data     : 0;
assign cache2net_dValid  = d_net_valid? d_valid        : 0;
assign cache2net_dReady  = (d_ready & (~d_net_buffer)& (~d_core_op)); 

always @ (posedge clock) begin 
	p_i_busy  <= reset? 0 : i_busy; 
	p_i_op    <= reset? 0 : i_op; 
	p_d_busy  <= reset? 0 : d_busy; 
	p_d_op    <= reset? 0 : d_op; 
	
	i_core_service <= reset? 0 : (i_op & ((i_core_addr_buf == i_address) | (core2cache_iAddr == i_address))) ? 1: 
	                              i_core_valid? 0 : i_core_service; 
	i_core_address <= reset? 0 : (i_op & (i_core_addr_buf == i_address))? i_core_addr_buf: 
								 (i_op & (core2cache_iAddr == i_address))? core2cache_iAddr : 
	                              i_core_valid? 0 : i_core_address; 
	d_core_service <= reset? 0 : (d_op & ((d_core_addr_buf == d_address) | (core2cache_dAddr == d_address))) ? 1: 
	                              d_core_valid? 0 : d_core_service; 
	d_core_address <= reset? 0 : (d_op & (d_core_addr_buf == d_address))? d_core_addr_buf: 
								 (d_op & (core2cache_dAddr == d_address))? core2cache_dAddr : 
	                              d_core_valid? 0 : d_core_address; 
								  
	i_net_service <= reset? 0 : (i_op & ((i_net_addr_buf == i_address) | (net2cache_iAddr == i_address))) ? 1: 
	                             i_net_valid? 0 : i_net_service; 
	i_net_address <= reset? 0 : (i_op & (i_net_addr_buf == i_address))? i_net_addr_buf: 
							    (i_op & (net2cache_iAddr == i_address))? net2cache_iAddr : 
	                             i_net_valid? 0 : i_net_address; 
	d_net_service <= reset? 0 : (d_op & ((d_net_addr_buf == d_address) | (net2cache_dAddr == d_address))) ? 1: 
	                             d_net_valid? 0 : d_net_service; 
	d_net_address <= reset? 0 : (d_op & (d_net_addr_buf == d_address))? d_net_addr_buf: 
								(d_op & (net2cache_dAddr == d_address))? net2cache_dAddr : 
	                             d_net_valid? 0 : d_net_address;  						 
	
 	i_core_read_buf   <= reset? 0 : i_core_clear? 0 : (i_busy & i_core_op)?  core2cache_iRead  : i_core_read_buf; 
	i_core_write_buf  <= reset? 0 : i_core_clear? 0 : (i_busy & i_core_op)?  core2cache_iWrite : i_core_write_buf; 
	i_core_addr_buf   <= reset? 0 : i_core_clear? 0 : (i_busy & i_core_op)?  core2cache_iAddr  : i_core_addr_buf; 
	i_core_data_buf   <= reset? 0 : i_core_clear? 0 : (i_busy & i_core_op)?  core2cache_iData  : i_core_data_buf; 
	
	d_core_read_buf   <= reset? 0 : d_core_clear? 0 : (d_busy & d_core_op)?  core2cache_dRead  : d_core_read_buf; 
	d_core_write_buf  <= reset? 0 : d_core_clear? 0 : (d_busy & d_core_op)?  core2cache_dWrite : d_core_write_buf; 
	d_core_addr_buf   <= reset? 0 : d_core_clear? 0 : (d_busy & d_core_op)?  core2cache_dAddr  : d_core_addr_buf; 
	d_core_data_buf   <= reset? 0 : d_core_clear? 0 : (d_busy & d_core_op)?  core2cache_dData  : d_core_data_buf; 
	
 	i_net_read_buf   <= reset? 0 : i_net_clear? 0 : (i_busy & i_net_op)?  net2cache_iRead  : i_net_read_buf; 
	i_net_write_buf  <= reset? 0 : i_net_clear? 0 : (i_busy & i_net_op)?  net2cache_iWrite : i_net_write_buf; 
	i_net_addr_buf   <= reset? 0 : i_net_clear? 0 : (i_busy & i_net_op)?  net2cache_iAddr  : i_net_addr_buf; 
	i_net_data_buf   <= reset? 0 : i_net_clear? 0 : (i_busy & i_net_op)?  net2cache_iData  : i_net_data_buf; 
	
	d_net_read_buf   <= reset? 0 : d_net_clear? 0 : (d_busy & d_net_op)?  net2cache_dRead  : d_net_read_buf; 
	d_net_write_buf  <= reset? 0 : d_net_clear? 0 : (d_busy & d_net_op)?  net2cache_dWrite : d_net_write_buf; 
	d_net_addr_buf   <= reset? 0 : d_net_clear? 0 : (d_busy & d_net_op)?  net2cache_dAddr  : d_net_addr_buf; 
	d_net_data_buf   <= reset? 0 : d_net_clear? 0 : (d_busy & d_net_op)?  net2cache_dData  : d_net_data_buf; 
	
end 

reg [31:0] local_request; 
reg [31:0] remote_request; 

always @ (posedge clock) begin   
	if(reset) begin 
		local_request  <= 0; 
		remote_request <= 0; 
	end 
	else begin 
		if(cache2core_dValid) local_request  <= local_request + 1; 
		if(cache2net_dValid) remote_request  <= remote_request + 1; 
	end 

 if (report) begin 
	  $display ("------------------------ Core %d D-Cache front-end  ---------------------------", core_ID);  
	  $display ("Local requests [%d]  Remote requests [%d]", local_request, remote_request);
	  $display ("------------------------------------------------------------------------------");
	 end 
 end

 /*
 always @ (posedge clock) begin
	$display ("--------------------------------Cache Interface Core %d ----------------------------------", core_ID);  
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
	$display ("Net2Cache iRead [%b]\t\t|Net2Cache dRead [%b]", net2cache_iRead, net2cache_dRead);
	$display ("Net2Cache iWrite [%b]\t\t|Net2Cache dWrite [%b]", net2cache_iWrite, net2cache_dWrite);
	$display ("Net2Cache iAddress [%h]\t|Net2Cache dAddress [%h]", net2cache_iAddr, net2cache_dAddr);  
	$display ("Net2Cache iData [%h]|Net2Cache dData [%h]", net2cache_iData, net2cache_dData);
	$display ("|");
 	$display ("Cache2Net iAddress [%h]\t|Cache2Net dAddress [%h]", cache2net_iAddr, cache2net_dAddr);  
	$display ("Cache2Net iData [%h]|Cache2Net dData [%h]", cache2net_iData, cache2net_dData);
	$display ("cache2Net iValid [%b]\t\t|Cache2Net dValid [%b]", cache2net_iValid, cache2net_dValid);
	$display ("Cache2Net iReady [%b]\t\t|Cache2Net dReady [%b]", cache2net_iReady, cache2net_dReady);
	$display ("|");
	$display ("i_core_op [%b]\t\t\t\t|d_core_op [%b]", i_core_op, d_core_op);
	$display ("i_core_service [%b]\t\t|i_core_address [%h]", i_core_service, i_core_address);
	$display ("d_core_service [%b]\t\t|d_core_address [%h]", d_core_service, d_core_address);
	$display ("|");
	$display ("i_net_op [%b]\t\t\t\t|d_net_op [%b]", i_net_op, d_net_op);
	$display ("i_net_service [%b]\t\t\t|i_net_address [%h]", i_net_service, i_net_address);
	$display ("d_net_service [%b]\t\t\t|d_net_address [%h]", d_net_service, d_net_address);
	$display ("|");
	$display ("i_core_read_buf [%b]\t\t|i_core_write_buf [%b]", i_core_read_buf, i_core_write_buf);
	$display ("i_core_addr_buf [%h]\t|i_core_data_buf [%h]", i_core_addr_buf, i_core_data_buf);
	$display ("d_core_read_buf [%b]\t\t|d_core_write_buf [%b]", d_core_read_buf, d_core_write_buf);
	$display ("d_core_addr_buf [%h]\t|d_core_data_buf [%h]", d_core_addr_buf, d_core_data_buf);
	$display ("|");
	$display ("i_net_read_buf [%b]\t\t|i_net_write_buf [%b]", i_net_read_buf, i_net_write_buf);
	$display ("i_net_addr_buf [%h]\t\t|i_net_data_buf [%h]", i_net_addr_buf, i_net_data_buf);
	$display ("d_net_read_buf [%b]\t\t|d_net_write_buf [%b]", d_net_read_buf, d_net_write_buf);
	$display ("d_net_addr_buf [%h]\t\t|d_net_data_buf [%h]", d_net_addr_buf, d_net_data_buf);
	$display ("|");
	$display ("i_core_buffer [%b]\t\t\t|d_core_buffer [%b]", i_core_buffer, d_core_buffer);
	$display ("i_core_clear [%b]\t\t\t|d_core_clear [%b]", i_core_clear, d_core_clear);
	$display ("i_net_buffer [%b]\t\t\t|d_net_buffer [%b]", i_net_buffer, d_net_buffer);
	$display ("i_net_clear [%b]\t\t\t|d_net_clear [%b]", i_net_clear, d_net_clear);
	$display ("|");	
	$display ("--- Cache ---");
	$display ("iRead [%b]\t\t\t\t|dRead [%b]", read[0], read[1]);
	$display ("iWrite [%b]\t\t\t|dWrite [%b]", write[0], write[1]);
	$display ("iAddress [%h]\t\t|dAddress [%h]", address[ADDRESS_BITS-1:0], address[(2*ADDRESS_BITS)-1 -:ADDRESS_BITS]);
	$display ("iIn_data [%h]\t|dIn_data [%h]", in_data[DATA_WIDTH-1 :0], in_data[(2*DATA_WIDTH)-1 -:DATA_WIDTH]);
	$display ("iOut_Addr [%h]\t\t|dOut_Addr [%h]", out_address[ADDRESS_BITS-1:0], out_address[(2*ADDRESS_BITS)-1 -:ADDRESS_BITS]);
	$display ("iOut_data [%h]\t|dOut_data [%h]", out_data[DATA_WIDTH-1 :0], out_data[(2*DATA_WIDTH)-1 -:DATA_WIDTH]);
	$display ("iValid [%b]\t\t\t|dValid [%b]", valid[0], valid[1]);
	$display ("iReady [%b]\t\t\t|dReady [%b]", ready[0], ready[1]);
end
//*/

endmodule