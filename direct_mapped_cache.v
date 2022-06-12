
/** @module : DMapped_Word_Cache
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
module direct_mapped_cache #(parameter CORE = 0, DATA_WIDTH = 32, INDEX_BITS = 6, 
                     OFFSET_BITS = 3, ADDRESS_BITS = 20, MSG_BITS = 3) (
				     clock, reset,  
				     //Core2Cache
				     read, write, address, in_data, 
				     out_addr, out_data, valid, ready,
				     
				     //Cache2Memory
				     mem2cache_msg, 
				     mem2cache_address, mem2cache_data, 
				     
				     cache2mem_msg, 
				     cache2mem_address, cache2mem_data, 
					 report
);

input clock, reset; 
//Core2Cache
input read, write;
input [ADDRESS_BITS-1:0] address;
input [DATA_WIDTH-1:0] in_data;
output valid, ready;
output[ADDRESS_BITS-1:0] out_addr;
output[DATA_WIDTH-1:0] out_data;

//Cache2Memory
input [MSG_BITS-1:0]      mem2cache_msg; 
input [ADDRESS_BITS-1:0]  mem2cache_address; 
input [DATA_WIDTH-1:0]    mem2cache_data;
 				     
output [MSG_BITS-1:0]     cache2mem_msg; 
output [ADDRESS_BITS-1:0] cache2mem_address; 
output [DATA_WIDTH-1:0]   cache2mem_data; 
input  report;

localparam OFFSET   = 1<<OFFSET_BITS; 
localparam TAGLESS_BITS = INDEX_BITS + OFFSET_BITS; 
localparam TAG_BITS = ADDRESS_BITS - TAGLESS_BITS;
localparam CC_STATUS_BITS = 2;

wire [OFFSET_BITS-1 :0] zero_offset = 0;   
localparam MEM_NO_MSG = 0, MEM_READY = 1, MEM_SENT = 2;
localparam NO_REQ = 0, WB_REQ = 1, C_SENT = 2, C_RECV = 3, R_REQ = 4, W_REQ = 5;

localparam IDLE = 0, HIT_OR_MISS = 1, W_HIT_OR_MISS =  2, MISS = 3, 
           WRITE_BACK = 4, WB_WAIT = 5, READ_ST = 6, WRITE_ST = 7, WAIT = 8, 
           UPDATE = 9, UPDATE_DONE = 10;
reg [OFFSET_BITS :0] counter; 
reg [3:0] state;

reg SG1_read, SG1_write;
reg [ADDRESS_BITS-1:0]  SG1_address;
reg [DATA_WIDTH-1:0]    SG1_in_data;

reg SG0_read, SG0_write;
reg [ADDRESS_BITS-1:0]  SG0_address;
reg [DATA_WIDTH-1:0]    SG0_in_data;

wire [(1 + TAG_BITS + (DATA_WIDTH * OFFSET)): 0] cur_line; 
wire [(DATA_WIDTH * OFFSET)-1:0]   new_data_block;
wire [DATA_WIDTH -1:0]   r_words [0:OFFSET-1];
wire [DATA_WIDTH -1:0]   w_words [0:OFFSET-1];

reg  t_valid; 
reg [DATA_WIDTH-1:0] t_out_data;

reg [ADDRESS_BITS-1:0] wb_address; 
reg [(DATA_WIDTH * OFFSET)-1:0] wb_data_block;

reg [MSG_BITS-1:0]    t_cache2mem_msg; 
reg [ADDRESS_BITS-1:0]t_cache2mem_address; 
reg [DATA_WIDTH-1:0]  t_cache2mem_data;
 
 
wire [OFFSET_BITS-1:0]  c2c_offset  = SG1_address [OFFSET_BITS-1:0];
wire [INDEX_BITS-1:0]   c2c_index   = SG1_address [TAGLESS_BITS-1:OFFSET_BITS];
wire [TAG_BITS-1:0]     c2c_tag     = SG1_address [ADDRESS_BITS-1: TAGLESS_BITS];

wire valid_bit               = cur_line[1 + TAG_BITS + (DATA_WIDTH * OFFSET)]; 
wire dirty                   = cur_line[TAG_BITS + (DATA_WIDTH * OFFSET)];
wire [TAG_BITS-1:0]  cur_tag = cur_line[ ((TAG_BITS + (DATA_WIDTH * OFFSET)) - 1) -: TAG_BITS];  
wire [(DATA_WIDTH * OFFSET)-1:0]   cur_data_block = cur_line[(DATA_WIDTH * OFFSET)-1:0];

wire hit = ((SG1_write| SG1_read) & ((c2c_tag != cur_tag) | (valid_bit != 1)))? 0 : 1; 
wire stall = ((c2c_index == SG0_address [TAGLESS_BITS-1:OFFSET_BITS]) & (SG0_write | SG0_read) & SG1_write)?
			 1 : 0; 

wire [INDEX_BITS-1:0]   cur_index   = reset?  0: ((state == IDLE) | ((state == HIT_OR_MISS) & hit))?
												 address[TAGLESS_BITS-1:OFFSET_BITS] :
												 (state == UPDATE_DONE)?
												 SG0_address[TAGLESS_BITS-1:OFFSET_BITS]: 
												 SG1_address[TAGLESS_BITS-1:OFFSET_BITS];
												 
wire read_line                      = reset?  0: ((write | read) & ((state == IDLE) | 
												  ((state == HIT_OR_MISS) & hit & ~stall)))? 1 :
												 ((SG0_write | SG0_read) & (state == UPDATE_DONE)& ~stall)? 1:
												 ((SG1_write | SG1_read) & (state == UPDATE))? 1: 0; 		 

wire [(1 + TAG_BITS + (DATA_WIDTH * OFFSET)): 0] new_line    =  (SG1_write & (c2c_tag == cur_tag) & 
											 (valid_bit == 1))? {2'b11, cur_tag, new_data_block} : 
											 ((state == WAIT) & (mem2cache_msg == MEM_NO_MSG) & 
											 (counter == OFFSET))? {2'b10, c2c_tag, new_data_block} : 0; 
wire write_line  =  ((SG1_write & (c2c_tag == cur_tag) & (valid_bit == 1)) | 
					((state == WAIT) & (mem2cache_msg == MEM_NO_MSG) & (counter == OFFSET)))?
				     1 : 0; 
wire [INDEX_BITS-1:0] write_index =  ((SG1_write & (c2c_tag == cur_tag) & (valid_bit == 1)) |
					((state == WAIT) & (mem2cache_msg == MEM_NO_MSG) & (counter == OFFSET)))?
					c2c_index : 0; 

assign  cache2mem_msg     = reset? 0: t_cache2mem_msg; 
assign  cache2mem_address = reset? 0: t_cache2mem_address; 
assign  cache2mem_data    = reset? 0: t_cache2mem_data;					

// to collect statistical data 
reg [31: 0] total_hits;  
reg [31: 0] total_misses; 
											  
genvar i;
generate   
	for (i = 0; i < OFFSET; i=i+1) begin : LN_OUT
      	assign r_words[i] = cur_data_block [(((i + 1) *(DATA_WIDTH))-1) -: DATA_WIDTH]; 
      	assign new_data_block [(((i + 1) *(DATA_WIDTH))-1) -: DATA_WIDTH] = w_words[i];
  	end  
	
	for (i = 0; i < OFFSET; i=i+1) begin : LN_OUT2
      	assign w_words[i] = (SG1_write & (c2c_tag == cur_tag) & (valid_bit == 1) & 
							(c2c_offset == i))? SG1_in_data : 
							 ((state == WAIT) & ((mem2cache_msg == MEM_SENT) & 
							 (t_cache2mem_address == mem2cache_address)) &
							 (counter == i))? mem2cache_data : 
							 (state == WAIT)? w_words[i] : r_words[i];
  	end  
endgenerate
							
BRAM #((2 + TAG_BITS + (DATA_WIDTH * OFFSET)), INDEX_BITS) CACHE_RAM (
		.clock(clock),
    	.readEnable(read_line),
    	.readAddress(cur_index),
   		.readData(cur_line),
		
    	.writeEnable(write_line),
    	.writeAddress(write_index),
    	.writeData(new_line)
); 
  
 always @ (posedge clock) begin  
  if(reset == 1) begin 
		SG0_read    <= 0; 
		SG0_write   <= 0; 
		SG0_address <= 0;
		SG0_in_data <= 0;
		
		SG1_read    <= 0; 
		SG1_write   <= 0; 
		SG1_address <= 0;
		SG1_in_data <= 0;
		
		t_cache2mem_msg     <= 0; 
		t_cache2mem_address <= 0; 
		t_cache2mem_data    <= 0;
		
		t_valid       <= 0;  
		t_out_data    <= 0;
		
		wb_address    <= 0;  
		wb_data_block <= 0;  

		total_hits    <= 0;
		total_misses  <= 0;		
		
		counter       <= 0;
		state         <= IDLE; 
  end 
  else begin 
		  wb_address     <= valid_bit? {cur_tag, c2c_index, zero_offset} : wb_address;
		  wb_data_block  <= valid_bit? cur_data_block : wb_data_block;
          case (state)
          	IDLE: begin
				SG1_read          <= read; 
				SG1_write         <= write;
				SG1_address 	  <= address;
				SG1_in_data       <= in_data;
        		state             <= (~read & ~write)? IDLE : HIT_OR_MISS; 
          	end
          		    
			HIT_OR_MISS: begin
				if (hit) begin 
					if(stall) begin 
						SG1_read          <= 0; 
						SG1_write         <= 0;
						SG1_in_data       <= 0;
						
						SG0_read          <= read; 
						SG0_write         <= write;
						SG0_address 	  <= address;
						SG0_in_data       <= in_data;
						
						state             <= UPDATE_DONE; 
					end 
					else begin 
						SG1_read          <= read; 
						SG1_write         <= write;
						SG1_address 	  <= address;
						SG1_in_data       <= in_data;
						state             <= (~read & ~write)? IDLE : HIT_OR_MISS; 
					end 
					
					if(SG0_read | SG0_write | SG1_read | SG1_write) total_hits <= total_hits + 1;
				end
				else begin
					SG0_read          <= read; 
					SG0_write         <= write;
					SG0_address 	  <= address;
					SG0_in_data       <= in_data;
				
					state <= (dirty & valid_bit) ? WRITE_BACK 
          		           : SG1_read? READ_ST : SG1_write? WRITE_ST: HIT_OR_MISS;
					total_misses         <= total_misses + 1;
				end 
          	end
          	
            READ_ST: begin
                t_cache2mem_msg     <= R_REQ; 
			    t_cache2mem_address <= ((SG1_address >> OFFSET_BITS)<<OFFSET_BITS);  
			    counter             <= 0;
			    state               <= WAIT;
            end
                               
            WRITE_ST: begin
                t_cache2mem_msg     <= W_REQ; 
    			t_cache2mem_address <= ((SG1_address >> OFFSET_BITS)<<OFFSET_BITS);  
  			    counter             <= 0;
    		    state               <= WAIT;
            end
   
			WAIT: begin
				if ((mem2cache_msg == MEM_SENT) & (t_cache2mem_address == mem2cache_address)) begin
					if(counter < OFFSET) begin
						t_cache2mem_msg     <= C_RECV;
						counter             <= counter + 1;   
					end
					else begin
						t_cache2mem_msg     <= NO_REQ;
					end
					state                   <= WAIT;
				end
				else begin 
					if ((mem2cache_msg == MEM_NO_MSG) & (counter == OFFSET))begin 
						state               <= UPDATE; 
					end
					else begin 
						state               <= WAIT;
					end 
					t_cache2mem_msg         <= NO_REQ;
				end 
            end
			
            UPDATE: begin
        		state             <= UPDATE_DONE; 				
            end 
			
			UPDATE_DONE: begin
				if(stall) begin 
					SG1_read          <= 0; 
					SG1_write         <= 0;
					SG1_in_data       <= 0; 
					state             <= UPDATE_DONE ; 
				end 
				else begin 
					SG1_read          <= SG0_read; 
					SG1_write         <= SG0_write;
					SG1_address 	  <= SG0_address;
					SG1_in_data       <= SG0_in_data;

					SG0_read          <= 0; 
					SG0_write         <= 0;
					SG0_address 	  <= 0;
					SG0_in_data       <= 0;
					
					state             <= (~SG0_read & ~SG0_write)? IDLE : HIT_OR_MISS;	
				end 
            end 
			
            WRITE_BACK : begin
                t_cache2mem_msg     <= WB_REQ; 
			    t_cache2mem_address <= wb_address;  
			    counter             <= 0;
			    state               <= WB_WAIT;
            end 
			
            WB_WAIT: begin
                if (mem2cache_msg == MEM_READY) begin      
	                if(counter < OFFSET) begin
	                   t_cache2mem_msg     <= C_SENT;
	                   counter             <= counter + 1;
	                   t_cache2mem_address <= wb_address + counter; 
	                   t_cache2mem_data    <= wb_data_block [(((counter + 1) *(DATA_WIDTH))-1) -: DATA_WIDTH]; 
	                   state               <= WB_WAIT;     
	                 end
                	 else begin
                	   t_cache2mem_msg     <= NO_REQ;
                	   state               <= SG1_read? READ_ST : WRITE_ST;
                	 end
                end
                else state      <= WB_WAIT;                    
             end 
			 
          	default: state <= IDLE;
          endcase    
  end
 end 
 
//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
assign  out_addr = SG1_address; 
assign  valid    = (hit & (SG1_read | SG1_write))? 1 : 0; 
assign  out_data = (hit & SG1_read)? r_words[c2c_offset]: 0;
assign  ready    = (reset | (state == IDLE) | ((state == HIT_OR_MISS) & hit & ~stall))? 1 : 0;

 
// Performance data
reg [31 : 0] cycles;

always @ (posedge clock) begin
	if (reset) begin	
		cycles           <= 0;  
	end 
    else begin
		cycles           <= cycles + 1;
		if (report) begin 
			$display ("-------------------------- Cache %d: ---------------------------------", CORE);
			$display ("Total hits [%d]\t| Total misses [%d]", total_hits, total_misses);
			$display ("-------------------------------------------------------------------------------");
		end 	
	end 
end
 
/*
 always @ (posedge clock) begin      
	$display ("--------------------------------- Cache %d --------------------------------------", CORE);   
	$display ("Reset [%b]\t\t| Read [%b]\t\t| Write [%b]\t\t",reset, read, write);
	$display ("New Addr [%h]\t| New In_data [%h]", address, in_data);
	$display ("Valid [%b]\t| Addr [%h]\t| data [%h]", valid, out_addr, out_data);
	$display ("Cur_Read [%b]\t\t| Cur_Write [%b]\t\t| Ready [%b]", SG0_read, SG0_write, ready);
	$display ("Cur Addr [%h]\t| Cur In_data [%h]", SG0_address, SG0_in_data);
	$display ("SG1_Read [%b]\t\t| SG1_Write [%b]", SG1_read, SG1_write);
	$display ("SG1 Addr [%h]\t| SG1 In_data [%h]", SG1_address, SG1_in_data);
	$display ("Offset [%d]\t\t| Index [%h]\t\t| TAG [%h]\t\t", c2c_offset, c2c_index, c2c_tag);
	$display ("Valid Bit [%b]\t\t| Dirty Bit[%b]\t\t| Hit [%b]", valid_bit, dirty, hit); 
	$display ("Found TAG [%h]\t| Found DATA [%h]", cur_tag, r_words[c2c_offset]);		
	$display ("State [%d]\t\t| Counter [%d]", state, counter); 
	$display ("R_words [%h]\t| W_words [%h]", r_words[counter], w_words[counter]);
	$display ("Write Index [%h]\t| Write_line [%b]",write_index, write_line);
	$display ("New_line [%h]", new_data_block);
	$display ("Cur_Index [%h]\t| Read_line [%b]", cur_index, read_line);
	$display ("Cur_line [%h]", cur_data_block); 
	$display ("MEM2CACHE MSG [%d]\t| MEM2CACHE Add [%h]\t| MEM2CACHE DATA [%h]", 
				 mem2cache_msg, mem2cache_address, mem2cache_data);
	$display ("CACHE2MEM MSG [%d]\t| CACHE2MEM Add [%h]\t| CACHE2MEM DATA [%h]", 
				 cache2mem_msg, cache2mem_address, cache2mem_data);
	$display ("-----------------------------------------------------------------------------");
 end 	
//*/
endmodule

