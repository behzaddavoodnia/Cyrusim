
/** @module : Main_Memory
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

// Parameterized main memory, which can support n-number of caches. 
// It round-robin service each of the caches. 

module main_memory #(parameter CORE = 0, DATA_WIDTH = 32, ADDRESS_BITS = 20, 
					 REAL_ADDR_BITS = 16, NUM_CACHES = 2, MSG_BITS = 3, 
					 OFFSET_BITS = 3, INIT_FILE = "memory.mem") (
	 clock, reset,  
						 
	 cache2mem_msg, 
	 cache2mem_address, cache2mem_data,
	 mem2cache_msg, 
	 mem2cache_address, mem2cache_data
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

input clock, reset; 				     
input [(MSG_BITS * NUM_CACHES)-1:0]     cache2mem_msg; 
input [(ADDRESS_BITS * NUM_CACHES)-1:0] cache2mem_address; 
input [(DATA_WIDTH * NUM_CACHES)-1:0]   cache2mem_data;

output [(MSG_BITS * NUM_CACHES)-1:0]     mem2cache_msg; 
output [(ADDRESS_BITS * NUM_CACHES)-1:0] mem2cache_address; 
output [(DATA_WIDTH * NUM_CACHES)-1:0]   mem2cache_data;

//Number of bits to represent cache number. 
localparam ID_BITS = log2(NUM_CACHES);
localparam OFFSETS = (1<<OFFSET_BITS); 
  
localparam MEM_NO_MSG = 0, MEM_READY = 1, MEM_SENT = 2;
localparam NO_REQ = 0, WB_REQ = 1, C_SENT = 2, C_RECV = 3, R_REQ = 4, W_REQ = 5;
localparam IDLE = 0, READING = 1, READ_OUT = 2, WRITING = 3; 
				     
wire [MSG_BITS-1:0]     w_cache2mem_msg     [0: (NUM_CACHES-1)]; 
wire [ADDRESS_BITS-1:0] w_cache2mem_address [0: (NUM_CACHES-1)]; 
wire [DATA_WIDTH-1:0]   w_cache2mem_data    [0: (NUM_CACHES-1)];

reg [MSG_BITS-1:0]      t_cache2mem_msg     [0: (NUM_CACHES-1)]; 
reg [ADDRESS_BITS-1:0]  t_cache2mem_address [0: (NUM_CACHES-1)]; 
reg [DATA_WIDTH-1:0]    t_cache2mem_data    [0: (NUM_CACHES-1)];

reg [MSG_BITS-1:0]      t_mem2cache_msg      [0: (NUM_CACHES-1)];
reg [ADDRESS_BITS-1:0]  t_mem2cache_address  [0: (NUM_CACHES-1)]; 
reg [DATA_WIDTH-1:0]    t_mem2cache_data     [0: (NUM_CACHES-1)];

reg    read, write; 
reg    [ADDRESS_BITS-1:0] address;
reg    [DATA_WIDTH-1:0]   data_in;
wire   [DATA_WIDTH-1:0]   data_out;

reg [ID_BITS-1:0]  serving; 
reg [OFFSET_BITS :0] counter;  
integer index;
reg [1:0] state;

BRAM #(DATA_WIDTH, REAL_ADDR_BITS) RAM_Block(
	.clock(clock),
	.readEnable(read),
	.readAddress(address[(REAL_ADDR_BITS -1) -: REAL_ADDR_BITS]),
	.readData(data_out),
	.writeEnable(write),
	.writeAddress(address[(REAL_ADDR_BITS -1) -: REAL_ADDR_BITS]),
	.writeData(data_in)
);
 
genvar i;
generate   
	for (i = 0; i < NUM_CACHES; i=i+1) begin : C_CONNECTIONS
		assign mem2cache_msg[(((i + 1) *(MSG_BITS))-1) -: MSG_BITS] = t_mem2cache_msg[i]; 
		assign mem2cache_address[(((i + 1) *(ADDRESS_BITS))-1) -: ADDRESS_BITS] = t_mem2cache_address[i]; 
		assign mem2cache_data[(((i + 1) *(DATA_WIDTH))-1) -: DATA_WIDTH]= t_mem2cache_data[i];
		
		assign w_cache2mem_msg[i]     = cache2mem_msg[(((i + 1) *(MSG_BITS))-1) -: MSG_BITS];
		assign w_cache2mem_address[i] = cache2mem_address[(((i + 1) *(ADDRESS_BITS))-1) -: ADDRESS_BITS];
		assign w_cache2mem_data[i]    = cache2mem_data[(((i + 1) *(DATA_WIDTH))-1) -: DATA_WIDTH];
	end 
endgenerate      

always @(posedge clock)
	if(reset==1)begin 
	     serving <= 0;
	     counter <= 0; 
	     read    <= 0; 
	     write   <= 0; 
	     data_in <= 0;
	     address <= 0;
	     state   <= IDLE;
	     for (index = 0; index < NUM_CACHES; index=index+1) begin
	          t_mem2cache_msg     [index]   <=  MEM_NO_MSG;
	     	  t_mem2cache_data    [index]   <=  0; 
	     	  t_mem2cache_address [index]   <=  0; 
	     end 
		 
	     for (index = 0; index < NUM_CACHES; index=index+1) begin
	          t_cache2mem_msg     [index]   <=  NO_REQ;
	     	  t_cache2mem_data    [index]   <=  0; 
	     	  t_cache2mem_address [index]   <=  0; 
	     end
	end 
    else begin
	
	     for (index = 0; index < NUM_CACHES; index=index+1) begin
			  if(w_cache2mem_msg     [index]   !=  NO_REQ) begin
				  t_cache2mem_msg     [index]   <=  w_cache2mem_msg     [index];
				  t_cache2mem_data    [index]   <=  w_cache2mem_data    [index]; 
				  t_cache2mem_address [index]   <=  w_cache2mem_address [index]; 
			  end
	     end 
		 
		 case (state)
		   IDLE: begin
				 if((t_mem2cache_msg[serving] == MEM_SENT)|| (t_mem2cache_msg[serving] == MEM_READY)) begin
					 t_mem2cache_msg[serving]     <= MEM_NO_MSG;
                                         t_mem2cache_address[serving] <= 0;
					 serving <= ((serving +1)== NUM_CACHES)? 0 : serving + 1;
					 state   <= IDLE;
				 end
				 else
				 if(t_cache2mem_msg[serving] == R_REQ) begin
					 t_mem2cache_msg[serving]     <= MEM_NO_MSG; 
                                         t_mem2cache_address[serving] <= t_cache2mem_address[serving];
					 counter                  <= 0;
					 address                  <= t_cache2mem_address[serving];
					 read                     <= 1;
					 state                    <= READING;
				 end
				 else if(t_cache2mem_msg[serving] == W_REQ) begin 
						 t_mem2cache_msg[serving]     <= MEM_NO_MSG;
                                                 t_mem2cache_address[serving] <= t_cache2mem_address[serving];
						 counter                  <= 0;
						 address                  <= t_cache2mem_address[serving];
						 read                     <= 1;  
						 state                    <= READING;
					  end
					  else begin 
							  if(t_cache2mem_msg[serving] == WB_REQ) begin 
									   t_mem2cache_msg[serving]     <= MEM_READY;
									   t_mem2cache_address[serving] <= t_cache2mem_address[serving];                                                           
									   counter                  <= 0; 
									   state                    <= WRITING;
							   end
							   else begin
									t_mem2cache_msg[serving]     <=  MEM_NO_MSG; 
									t_mem2cache_address[serving] <= 0; 
									serving <= ((serving +1)== NUM_CACHES)? 0 : serving + 1;
									state                    <= IDLE;
							   end
					  end 
		   end
		   
		   READING: begin
			   if((counter == 0) || ((counter < (OFFSETS-1)) && 
				 (w_cache2mem_msg[serving]  == C_RECV))) begin
					 address        <= address + 1;
					 counter        <= counter + 1;
					 state          <= READ_OUT;   
			  end     
				else begin 
					 if ((counter == (OFFSETS-1)) && 
						(w_cache2mem_msg[serving]  == C_RECV )) begin
						  counter                      <= counter + 1;
						  read                         <= 0;
						  state                        <= READ_OUT;   
					end
					else begin
						  state                       <= READING; 
					end
				 end
				 t_mem2cache_msg[serving]  <= MEM_NO_MSG;
		   end
										  
		   READ_OUT: begin
				t_mem2cache_address[serving] <= t_mem2cache_address[serving]; 
				t_mem2cache_data[serving]    <= data_out;
				t_mem2cache_msg[serving]     <= MEM_SENT;
				 
				 if (counter == OFFSETS) begin
					 state       <= IDLE;
				end 
				else state       <= READING; 
		   end
		   
		   WRITING: begin
				 t_mem2cache_address[serving] <= w_cache2mem_address[serving]; 
				 if(counter < OFFSETS) begin
					state       <= WRITING;
					if(w_cache2mem_msg[serving]  == C_SENT )begin
						address        <= w_cache2mem_address[serving];
						data_in        <= w_cache2mem_data[serving]; 
						write          <= 1;
						counter        <= counter + 1;   
					end
					else begin
						 write         <= 0;
					end        
				 end
				 else begin
					write           <= 0;
					if(w_cache2mem_msg[serving]  != C_SENT )begin
						state       <= IDLE;
					end 
					else state  <= WRITING;  
				 end
		   end
		endcase    
    end

/*
always @ (posedge clock) begin  
	$display ("--------------------------- MAIN MEMORY %d --------------------------------------", CORE); 
	$display ("Read [%b]\t\t| Write [%b]", read, write);
	$display ("Address [%h]\t\t| Data_In [%h]\t\t| Data_Out [%h]", address, data_in, data_out);
	$display ("State [%d]\t\t| Serving [%d]\t\t\t| Counter[%d]", state, serving, counter);
	$display ("WACHE2MEM MSG [%d]\t| WACHE2MEM Add [%h]\t| WACHE2MEM DATA [%h]", 
	w_cache2mem_msg[serving], w_cache2mem_address[serving], w_cache2mem_data[serving]);
	$display ("TACHE2MEM MSG [%d]\t| TACHE2MEM Add [%h]\t| TACHE2MEM DATA [%h]", 
	t_cache2mem_msg[serving], t_cache2mem_address[serving], t_cache2mem_data[serving]);
	$display ("MEM2CACHE MSG [%d]\t| MEM2CACHE Add [%h]\t| MEM2CACHE DATA [%h]", 
				 mem2cache_msg[(((serving + 1) *(MSG_BITS))-1) -: MSG_BITS], 
				 mem2cache_address[(((serving + 1) *(ADDRESS_BITS))-1) -: ADDRESS_BITS], 
				 mem2cache_data[(((serving + 1) *(DATA_WIDTH))-1) -: DATA_WIDTH]);
	$display ("CACHE2MEM MSG [%d]\t| CACHE2MEM Add [%h]\t| CACHE2MEM DATA [%h]", 
				 cache2mem_msg[(((serving + 1) *(MSG_BITS))-1) -: MSG_BITS], 
				 cache2mem_address[(((serving + 1) *(ADDRESS_BITS))-1) -: ADDRESS_BITS], 
				 cache2mem_data[(((serving + 1) *(DATA_WIDTH))-1) -: DATA_WIDTH]);
	$display ("------------------------------------------------------------------------------------");
end 
 //*/
endmodule
