
//@module : Real_Cores_Mesh_Wrapper
//@author : heracles-gui

/* 
 *  Using Heracles Multicore System under the copytright below:
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
 *
 */
 
 module Real_Cores_Mesh_Wrapper (
	input  clock,
    input  RST,	
	input  cmd,   
	output [31: 0] data, 
	output valid
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
//
//----------------------------------------------------
// Parameters
//----------------------------------------------------
localparam  VC_PER_PORTS    = 2;
localparam  VC_DEPTH        = 8;
localparam  COLUMN          = 2;
localparam  EXTRA           = 2;
localparam  DATA_WIDTH      = 32;
localparam  ROW             = 8;
localparam  MSG_BITS        = 0;
localparam  SWITCH_TO_SWITCH= 1;
localparam  RT_ALG          = 0;
localparam  STATS_CYCLES    = 0;
localparam  TYPE_BITS       = 2;
localparam  OUT_PORTS       = 1;
localparam  LOCAL_ADDR_BITS = 22;
localparam  INDEX_BITS      = 12;
localparam  ADDRESS_BITS    = 26;
localparam  OFFSET_BITS     = 3;

localparam  ROW_BITS     = log2(ROW);
localparam  COLUMN_BITS  = log2(COLUMN);
localparam  VC_BITS      = log2(VC_PER_PORTS);		 
localparam  ID_BITS      = ROW_BITS + COLUMN_BITS;					 
localparam  FLOW_BITS    = (2*ID_BITS) + EXTRA;  
localparam  FLIT_WIDTH   = FLOW_BITS + TYPE_BITS + VC_BITS + DATA_WIDTH;
localparam  PORTS        = OUT_PORTS + 6*(SWITCH_TO_SWITCH);
localparam  PORTS_BITS   = log2(PORTS); 
localparam  RT_WIDTH     = PORTS_BITS + VC_BITS + 1;

//----------------------------------------------------
// Unit under test inputs and outputs
//----------------------------------------------------    
reg [31:0]               prog_address;	
reg [3: 0]               operation;   
reg                      reset;
reg                      start;
reg                      PROG; 
reg                      ON;
reg [ID_BITS-1: 0]       core_ID; 
reg [(FLOW_BITS - 1): 0] route_table_address; 
reg [RT_WIDTH - 1: 0]    route_table_data; 
wire [ID_BITS-1: 0]      origin;
wire [31: 0]             data_out; 
wire                     valid_out; 


reg [63:0] fault_status_all=0;
//  localparam HEIGHT=COLUMN;
//    localparam CORES_PER_PLANE = ROW;
//  localparam COLUMNS_PER_PLANE=COLUMN;

//----------------------------------------------------
// Connect the DUT
//----------------------------------------------------
real_cores_mesh #(.ROW(ROW), .COLUMN(COLUMN),
				 .VC_PER_PORTS(VC_PER_PORTS),.VC_DEPTH(VC_DEPTH),
				 .INDEX_BITS(INDEX_BITS),.OFFSET_BITS(OFFSET_BITS),
				 .RT_ALG(RT_ALG), .EXTRA(EXTRA), .DATA_WIDTH(DATA_WIDTH), 
				 .LOCAL_ADDR_BITS(LOCAL_ADDR_BITS), 
				 .ADDRESS_BITS(ADDRESS_BITS), .MSG_BITS(MSG_BITS), 
				 .STATS_CYCLES(STATS_CYCLES)) U (
		  clock, 
		  RST, 
		  start, 
		  prog_address, 
		  operation, 
		  ON, 
		  core_ID, 
		  reset, 
		  PROG, 
		  route_table_address, 
		  route_table_data, 
		  origin, 
		  data_out, 
		  valid_out, fault_status_all 
);  

//----------------------------------------------------
// Output buffering 
//----------------------------------------------------
wire          full; 
wire          empty; 
wire          read_valid;
wire [31: 0]  read_data; 
reg           rdEn;
reg  [5:0]    state;
wire peek                = 1'b0; 
wire mesh_valid          = valid_out && ~full;
wire [31: 0] mesh_data   = data_out;   

fifo  #(32, 8, 0) buffer (
			clock, RST, mesh_data, 
			mesh_valid, rdEn, peek, 
			read_data, read_valid, full, empty 
);  
	  
//--------------Code Starts Here----------------------- 
always @ (posedge clock) begin
	if(~RST && cmd && ~empty && ~rdEn) begin 
		rdEn <= 1; 
	end 
	else rdEn <= 0;
end


always @ (posedge clock) begin 
	if (RST == 1) begin 
		state        <= 0;   
		reset 	     <= 0;
		PROG         <= 0; 
		ON           <= 0; 
		core_ID      <= 0;
		start        <= 0;	 
		prog_address <= 0;	 
	end 
	else  begin
		case (state)
			0: begin
			   state   <= state + 1;
			end	
			1: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 0;
				state   <= state + 1;
			end
			2: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 1;
				state   <= state + 1;
			end
			3: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 2;
				state   <= state + 1;
			end
			4: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 3;
				state   <= state + 1;
			end
			//
			5: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 4;
				state   <= state + 1;
			end
			//
			6: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 5;
				state   <= state + 1;
			end		
			//
			7: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 6;
				state   <= state + 1;
			end	
			8: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 7;
				state   <= state + 1;
			end	
			9: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 8;
				state   <= state + 1;
			end
			10: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 9;
				state   <= state + 1;
			end	
			11: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 10;
				state   <= state + 1;
			end
			12: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 11;
				state   <= state + 1;
			end
			13: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 12;
				state   <= state + 1;
			end	
			14: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 13;
				state   <= state + 1;
			end		
			15: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 14;
				state   <= state + 1;
			end	
			16: begin
				operation             <= 4'b0011;
				ON                    <= 1;
				reset                 <= 1;
				core_ID               <= 15;
				state   <= state + 1;
			end			
			17: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 0;
				start                 <= 1;
				prog_address          <= 'h10;
				state   <= state + 1;
			end
			18: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 1;
				start                 <= 1;
				prog_address          <= 'h400010;
				state   <= state + 1;
			end
			19: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 2;
				start                 <= 1;
				prog_address          <= 'h800010;
				state   <= state + 1;
			end
			20: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 3;
				start                 <= 1;
				prog_address          <= 'hc00010;
				state   <= state + 1;
			end
			21: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 4;
				start                 <= 1;
				prog_address          <= 'h1000010;
				state   <= state + 1;
			end
			22: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 5;
				start                 <= 1;
				prog_address          <= 'h1400010;
				state   <= state + 1;
			end		
			23: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 6;
				start                 <= 1;
				prog_address          <= 'h1800010;
				state   <= state + 1;
			end		
			24: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 7;
				start                 <= 1;
				prog_address          <= 'h1c00010;
				state   <= state + 1;
			end			
			25: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 8;
				start                 <= 1;
				prog_address          <= 'h2000010;
				state   <= state + 1;
			end		
			26: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 9;
				start                 <= 1;
				prog_address          <= 'h2400010;
				state   <= state + 1;
			end			
			27: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 10;
				start                 <= 1;
				prog_address          <= 'h2800010;
				state   <= state + 1;
			end			
			28: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 11;
				start                 <= 1;
				prog_address          <= 'h2c00010;
				state   <= state + 1;
			end			
			29: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 12;
				start                 <= 1;
				prog_address          <= 'h3000010;
				state   <= state + 1;
			end			
			30: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 13;
				start                 <= 1;
				prog_address          <= 'h3400010;
				state   <= state + 1;
			end			
			31: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 14;
				start                 <= 1;
				prog_address          <= 'h3800010;
				state   <= state + 1;
			end			
			32: begin
				operation             <= 4'b1010;
				reset                 <= 0;
				core_ID               <= 15;
				start                 <= 1;
				prog_address          <= 'h3c00010;
				state   <= state + 1;
			end			
			33: begin
				operation             <= 4'b0000;
				state   <= state + 1;
			end

			default:  begin
			   state    <= state; 
			end
		endcase 
	end
end
		
//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
 assign data  = read_data;
 assign valid = read_valid;
 
endmodule
        