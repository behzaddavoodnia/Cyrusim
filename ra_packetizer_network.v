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

module ra_packetizer_network #(parameter CORE = 0, DATA_WIDTH = 32, ADDRESS_BITS = 32, 
							  IN_PORTS = 1, OUT_PORTS = 1, VC_BITS = 1, VC_DEPTH_BITS = 4,
                              ID_BITS = 4, EXTRA  = 2, TYPE_BITS = 2) ( 
					
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
localparam VC_PER_PORTS  = (1 << VC_BITS); 
localparam FLOW_BITS     = (2*ID_BITS) + EXTRA;  
localparam FLIT_WIDTH    = FLOW_BITS + TYPE_BITS + VC_BITS + DATA_WIDTH;

input clock, reset; 

input [FLIT_WIDTH -1:0] c_flit_to_send;
input cv_send_flit; 
					 
output [FLIT_WIDTH -1:0] c_flit_received; 
output cv_rec_flit; 
output c_ready; 

input [FLIT_WIDTH -1:0] p_flit_to_send;
input pv_send_flit; 
					 
output [FLIT_WIDTH -1:0] p_flit_received; 
output pv_rec_flit; 
output p_ready;

output [(FLIT_WIDTH * IN_PORTS) -1:0] from_core_flit;
output [IN_PORTS-1: 0] v_from_core;
output [(VC_PER_PORTS * IN_PORTS) -1:0] from_core_empty;
output [(VC_PER_PORTS * IN_PORTS) -1:0] from_core_full; 
  
input  [(FLIT_WIDTH * OUT_PORTS) -1:0] to_core_flit;
input  [OUT_PORTS-1: 0] v_to_core;
input  [(VC_PER_PORTS * IN_PORTS) -1:0] to_core_empty;
input  [(VC_PER_PORTS * IN_PORTS) -1:0] to_core_full;

wire  [ID_BITS - 1: 0] core_ID = CORE; 
reg [FLIT_WIDTH -1:0] t_from_core_flit [0 : IN_PORTS-1];
reg [IN_PORTS-1: 0] t_v_from_core;
wire [VC_PER_PORTS -1:0] t_from_core_empty [0 : IN_PORTS-1];
wire [VC_PER_PORTS -1:0] t_from_core_full [0 : IN_PORTS-1]; 

wire  [FLIT_WIDTH -1:0] t_to_core_flit [0 : OUT_PORTS-1];
wire  [OUT_PORTS-1: 0] t_v_to_core;
wire  [VC_PER_PORTS -1:0] t_to_core_empty [0 : OUT_PORTS-1];
wire  [VC_PER_PORTS -1:0] t_to_core_full [0 : OUT_PORTS-1];

reg [FLIT_WIDTH - 1:0] p_in_flit0 [0:IN_PORTS-1]; 
reg p_En0 [0:IN_PORTS-1];
reg [FLIT_WIDTH - 1:0] p_in_flit1 [0:IN_PORTS-1]; 
reg p_En1 [0:IN_PORTS-1];
reg received_all [0:IN_PORTS-1];      

reg [FLIT_WIDTH - 1:0] c_in_flit [0:IN_PORTS-1];
reg [VC_BITS - 1:0] c_in_vc [0:IN_PORTS-1]; 
reg c_WEn [0:IN_PORTS-1];
   
reg [VC_BITS - 1:0] c_read_vc [0:IN_PORTS-1];
reg c_REn [0:IN_PORTS-1];
reg c_PeekEn [0:IN_PORTS-1];
  
wire [FLIT_WIDTH - 1:0] c_out_flit [0:IN_PORTS-1];
wire [VC_BITS - 1:0] c_out_vc [0:IN_PORTS-1];
wire c_valid [0:IN_PORTS-1];
  
wire [VC_PER_PORTS -1:0] c_empty [0:IN_PORTS-1];
wire [VC_PER_PORTS - 1:0] c_full [0:IN_PORTS-1]; 

wire  [EXTRA - 1: 0]     sub_flow  [0 : OUT_PORTS-1];
wire  [TYPE_BITS - 1: 0] flow_type [0 : OUT_PORTS-1];
wire core_traffic [0 : OUT_PORTS-1];
wire cache_traffic [0 : OUT_PORTS-1];

reg [FLIT_WIDTH -1:0] c_flit_received; 
reg cv_rec_flit; 
reg c_ready; 

reg [FLIT_WIDTH -1:0] p_flit_received; 
reg pv_rec_flit; 
reg p_ready; 

reg to_core_process;
reg [IN_PORTS-1: 0] p_cur_port;


reg [FLIT_WIDTH -1:0] c_flit_to_send0,  c_flit_to_send1; 
reg cv_send_flit0, cv_send_flit1;

reg [FLIT_WIDTH -1:0] p_flit_to_send0,  p_flit_to_send1; 
reg pv_send_flit0, pv_send_flit1;

reg c_to_send_ready, p_to_send_ready;
reg send_turn; 

reg [1:0] mState;
reg [2:0] cState;
reg  pState;

reg  found; 
reg [VC_BITS - 1:0]    free_vc; 
reg [IN_PORTS-1 :0]    free_port; 
reg [IN_PORTS - 1:0]   c_cur_port;
reg [VC_BITS- 1:0]     c_cur_vc;

localparam HEAD = 'b10, BODY = 'b00, TAIL = 'b01, ALL= 'b11;
localparam IDLE = 0, SEND = 1;
localparam SEARCH = 1, READY =  2, READY2 =  3; 
localparam CHECK_VC = 1, CHECK_AGAIN = 2, READ_DELAY = 3, READ = 4, WAIT_RESP = 5; 

integer index, vc;     
genvar j;
 generate
	// network 2 cache
	for (j=0; j < IN_PORTS; j=j+1) begin : IN_CACHE_PORTS
		buffer_port #(FLIT_WIDTH, VC_BITS, VC_DEPTH_BITS) INP (
		  clock, reset, 
		  c_WEn[j], c_in_flit[j], c_in_vc [j], 
		  c_REn[j], c_PeekEn[j], c_read_vc[j],  
		  c_out_flit[j], c_out_vc[j], c_valid[j], 
		  c_empty[j], c_full[j]
		);
	end

	for (j = 0; j < OUT_PORTS; j = j+1) begin : OUT_CPORTS
		assign t_to_core_flit[j]    = to_core_flit[((FLIT_WIDTH *(j + 1))-1) -: FLIT_WIDTH];
		assign t_to_core_empty[j]   = to_core_empty[((VC_PER_PORTS *(j + 1))-1) -: VC_PER_PORTS]; 
		assign t_to_core_full[j]    = to_core_full[((VC_PER_PORTS *(j + 1))-1) -: VC_PER_PORTS]; 
	end  
	assign t_v_to_core = v_to_core; 

	for (j = 0; j < IN_PORTS; j = j+1) begin : IN_CPORTS
		assign from_core_flit [(((j + 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH]  = t_from_core_flit[j];
		assign from_core_empty[(((j + 1) *(VC_PER_PORTS))-1) -: VC_PER_PORTS] = t_from_core_empty[j];
		assign from_core_full [(((j + 1) *(VC_PER_PORTS))-1) -: VC_PER_PORTS] = t_from_core_full[j];
	end 	
	assign v_from_core = t_v_from_core;

	for (j = 0; j < IN_PORTS; j = j+1) begin : EF_CPORTS
		assign t_from_core_empty[j] = c_empty[j]; 
		assign t_from_core_full[j]  = c_full[j]; 
	end   	
	
	for (j = 0; j < IN_PORTS; j = j+1) begin : SUB_CPORTS
		assign sub_flow[j]      = t_to_core_flit[j][(FLIT_WIDTH-(2*ID_BITS)-1) -: EXTRA];
		assign flow_type[j]     = t_to_core_flit[j][((FLIT_WIDTH - FLOW_BITS) -1) -: TYPE_BITS];	
		assign core_traffic[j]  = (t_v_to_core[j] & ((sub_flow[j] == 2) | (sub_flow[j] == 3))); 
		assign cache_traffic[j] = (t_v_to_core[j] & ((sub_flow[j] == 0) | (sub_flow[j] == 1)));
	end	
 endgenerate 
 
// Buffering of traffic to the caches
always @ (posedge clock) begin
	if (reset) begin 
		// Resetting 
		for(index= 0; index < IN_PORTS; index = index+1) begin    
			c_PeekEn[index]    <= 0;
			c_WEn[index]       <= 0;
		end
	end
	else begin    
		// read in input ports 
		for(index= 0; index < IN_PORTS; index = index+1) begin
			c_WEn[index]       <= cache_traffic[index]? 1 : 0; 
			c_in_flit[index]   <= cache_traffic[index]? t_to_core_flit[index] : 0;
			c_in_vc [index]    <= cache_traffic[index]? (t_to_core_flit[index] >> DATA_WIDTH) : 0; 
		end
	end
end

// Buffering of traffic to the core
always @ (posedge clock) begin
	if (reset) begin 
		// Resetting
		for(index= 0; index < IN_PORTS; index = index+1) begin    
			p_in_flit0[index]	 <= 0;
			p_En0[index]         <= 0;
			p_in_flit1[index]	 <= 0;
			p_En1[index]         <= 0;
			received_all[index]  <= 0;
		end
	end
	else begin    
		// read in input ports 
		for(index= 0; index < IN_PORTS; index = index+1) begin
			p_En0[index]        <= (core_traffic[index] & ((flow_type[index] == ALL ) | (flow_type[index] == HEAD)))? 1: 
							       to_core_process? 0 : p_En0[index]; 	   
			p_in_flit0[index]   <= (core_traffic[index] & ((flow_type[index] == ALL ) | (flow_type[index] == HEAD)))? 
								   t_to_core_flit[index]: to_core_process? 0 : p_in_flit0 [index]; 
								   
			p_En1[index]        <= (core_traffic[index] & (flow_type[index] == TAIL))? 1: to_core_process? 0 : p_En1[index]; 
			p_in_flit1[index]   <= (core_traffic[index] & (flow_type[index] == TAIL))? t_to_core_flit[index]: 
								   to_core_process? 0 : p_in_flit1 [index];
			received_all[index] <= to_core_process? 0 : (v_to_core & ((flow_type[index] == ALL ) | (flow_type[index] == TAIL)))? 1 : 
								   received_all[index];
		end
	end
end

// Send traffic to core 
always @ (posedge clock) begin
    if(reset == 1) begin 
		p_flit_received  <= 0; 
		pv_rec_flit      <= 0;
		p_ready          <= 1; 
					
		p_cur_port       <= 0;  
		to_core_process  <= 1; 
		pState           <= IDLE;
    end 
    else begin
		case (pState)
			IDLE: begin
				p_cur_port          <=(p_En0[p_cur_port] | p_En1[p_cur_port])? p_cur_port : 
									  (p_cur_port == (IN_PORTS -1))? 0 : (p_cur_port +1);
									  
				p_flit_received     <= received_all[p_cur_port]? p_in_flit0 [p_cur_port] : 0; 
				pv_rec_flit         <= received_all[p_cur_port]? 1 : 0; 
				p_ready             <= p_En1[p_cur_port]? 0 : 1; // need to rework this 
				
				to_core_process     <= (received_all[p_cur_port])? 1 : 0;
				pState              <= (received_all[p_cur_port] & p_En1[p_cur_port])? SEND : IDLE;
			end
			SEND: begin
				p_flit_received     <= p_in_flit1 [p_cur_port]; 
				pv_rec_flit         <= 1;
				p_ready             <= 1; 
				
				to_core_process     <= 1;
				pState              <= IDLE;
			end
			default: pState <= IDLE;
		endcase  
	
	end 
end 

wire [TYPE_BITS-1: 0] c_flow_type = c_out_flit[c_cur_port] >> (VC_BITS + DATA_WIDTH);		  
wire c_write_req = 	(c_flow_type == HEAD); 

wire c_sent = reset? 0 : (((mState == READY) & (c_to_send_ready & (~cv_send_flit1))) | 
						 ((mState == READY2) & (send_turn == 0)))? 1 : 0;
wire p_sent = reset? 0 : (((mState == READY) & (p_to_send_ready & (~pv_send_flit1) & 
						 (~c_to_send_ready))) | ((mState == READY2) & send_turn))? 1 : 0;
	  
// Send traffic to cache 
always @ (posedge clock) begin
    if(reset == 1) begin 
		// Resetting 
		for(index= 0; index < IN_PORTS; index = index+1) begin    
			c_REn[index]       <= 0;
			c_read_vc[index]   <= 0; 			
		end
		c_cur_port       <= 0; 
		c_cur_vc 	     <= 0; 
		
		c_flit_received  <= 0; 
		cv_rec_flit      <= 0;
		c_ready          <= 0; 
					
		cState           <= IDLE;	
    end 
    else begin
		case (cState)
			IDLE: begin
				c_cur_port          <= (c_cur_port == (IN_PORTS -1))? 0 : (c_cur_port +1);
				c_cur_vc            <= (c_cur_vc == (VC_PER_PORTS -1))? 0 : (c_cur_vc + 1);
				c_ready             <= 0;				
				cState              <= CHECK_VC;       		
			end

			CHECK_VC: begin	     
				if(c_empty[c_cur_port][c_cur_vc]== 0) begin
					c_REn[c_cur_port]     <= 1;  
					c_read_vc[c_cur_port] <= c_cur_vc; 
					cState                <= READ_DELAY; 
				end   
				else cState               <= IDLE;
			end 
			
			CHECK_AGAIN: begin	     
				c_flit_received		   <= 0; 		   
				cv_rec_flit            <= 0;
				if(c_empty[c_cur_port][c_cur_vc]== 0) begin
					c_REn[c_cur_port]     <= 1;  
					c_read_vc[c_cur_port] <= c_cur_vc; 
					cState                <= READ_DELAY; 
				end   
			end
			
      	   READ_DELAY: begin	     
				cState                 <= READ; 
				c_REn[c_cur_port]      <= 0;
      	   end 
		   
      	   READ: begin	   
				if(c_valid[c_cur_port]) begin 
					c_flit_received		   <= c_out_flit[c_cur_port]; 		   
					cv_rec_flit            <= 1;
					c_ready                <= 1;
				end
				else begin
					$display("ERROR!!! READ ERROR MEM PROBLEM!!!!"); 
				end
				cState <= c_write_req? CHECK_AGAIN : WAIT_RESP; 
      	   end 
		   
		   WAIT_RESP: begin 
				c_flit_received		   <= 0; 		   
				cv_rec_flit            <= 0;
				cState <=  c_sent? IDLE : WAIT_RESP; 
		   end 
		   
			default: cState <= IDLE;
		endcase  
	
	end 
end 


//Traffic to send out from cache and core
wire [TYPE_BITS-1: 0] c_send_type    = c_flit_to_send[((FLIT_WIDTH - FLOW_BITS) -1) -: TYPE_BITS];
wire [TYPE_BITS-1: 0] p_send_type    = p_flit_to_send[((FLIT_WIDTH - FLOW_BITS) -1) -: TYPE_BITS];

always @ (posedge clock) begin
    if(reset == 1) begin 
		c_flit_to_send0 <= 0; 
		cv_send_flit0   <= 0; 

		c_flit_to_send1 <= 0; 
		cv_send_flit1   <= 0; 
		c_to_send_ready <= 0; 

		p_flit_to_send0 <= 0; 
		pv_send_flit0   <= 0; 

		p_flit_to_send1 <= 0; 
		pv_send_flit1   <= 0;
		p_to_send_ready <= 0; 
	end 
	else begin 
		c_flit_to_send0 <= ((c_send_type == ALL) | (c_send_type == HEAD))? c_flit_to_send : c_sent? 0 : c_flit_to_send0; 
		cv_send_flit0   <= ((c_send_type == ALL) | (c_send_type == HEAD))? 1 : c_sent? 0 : cv_send_flit0; 

		c_flit_to_send1 <= (c_send_type == TAIL)? c_flit_to_send : c_sent? 0 : c_flit_to_send1; 
		cv_send_flit1   <= (c_send_type == TAIL)? 1 : c_sent? 0 : cv_send_flit1; 
		c_to_send_ready <= ((c_send_type == ALL) | (c_send_type == TAIL))? 1 : c_sent? 0 : c_to_send_ready;

		p_flit_to_send0 <= ((p_send_type == ALL) | (p_send_type == HEAD))? p_flit_to_send : p_sent? 0 : p_flit_to_send0; 
		pv_send_flit0   <= ((p_send_type == ALL) | (p_send_type == HEAD))? 1 : p_sent? 0 : pv_send_flit0; 

		p_flit_to_send1 <= (p_send_type == TAIL)? p_flit_to_send : p_sent? 0 : p_flit_to_send1; 
		pv_send_flit1   <= (p_send_type == TAIL)? 1 : p_sent? 0 : pv_send_flit1;
		p_to_send_ready <= ((p_send_type == ALL) | (p_send_type == TAIL))? 1 : p_sent? 0 : p_to_send_ready;
	end 
end 
	
//Flit sending arbitration 
  always @ (posedge clock) begin  
	if(reset == 1) begin
		mState          <= IDLE; 
		found           <= 0;
		free_vc         <= 0; 
		free_port       <= 0; 

		send_turn       <= 0; 	
		for(index= 0; index < IN_PORTS; index = index+1) begin
			t_from_core_flit[index]  <= 0;
			t_v_from_core[index]     <= 0; 
		end
	end 
	else begin 
		case (mState)
			IDLE: begin
				for(index= 0; index < IN_PORTS; index = index+1) begin
					t_from_core_flit[index]  <= 0;
					t_v_from_core[index]     <= 0; 
				end
				mState                       <= SEARCH;
				found                        <= 0;
				send_turn                    <= 0; 				
			end
			SEARCH: begin
				for(index= 0; index < IN_PORTS; index = index+1) begin
					if((t_to_core_empty [index] > 0) & (~found)) begin
					   for(vc= 0; vc < VC_PER_PORTS; vc = vc+1) begin 
							if (t_to_core_empty [index][vc]) free_vc <= vc; 
					   end 
					   free_port   <= index;
					   found       <= 1; 
					end 
				end
				mState     <= found? READY : SEARCH;
			end
			READY: begin
				mState                       <= ((c_to_send_ready & cv_send_flit1) | 
												 (p_to_send_ready & pv_send_flit1))? READY2 : 
												 (c_to_send_ready | p_to_send_ready)? IDLE : READY;
				
				t_from_core_flit[free_port]  <= c_to_send_ready? 
												{c_flit_to_send0[(FLIT_WIDTH-1) -: (FLOW_BITS + TYPE_BITS)], 
												free_vc, c_flit_to_send0[DATA_WIDTH-1: 0]} : 
												p_to_send_ready? 
												{p_flit_to_send0[(FLIT_WIDTH-1) -: (FLOW_BITS + TYPE_BITS)], 
												free_vc, p_flit_to_send0[DATA_WIDTH-1: 0]} : 0; 
												
				t_v_from_core[free_port]     <= (c_to_send_ready | p_to_send_ready)? 1 : 0; 
				send_turn                    <= (p_to_send_ready & (~c_to_send_ready))? 1 : 0; 
			end
			READY2: begin
				mState                       <= IDLE;
				
				t_from_core_flit[free_port]  <= send_turn? 
												{p_flit_to_send1[(FLIT_WIDTH-1) -: (FLOW_BITS + TYPE_BITS)], 
												free_vc, p_flit_to_send1[DATA_WIDTH-1: 0]} : 
												{c_flit_to_send1[(FLIT_WIDTH-1) -: (FLOW_BITS + TYPE_BITS)], 
												free_vc, c_flit_to_send1[DATA_WIDTH-1: 0]}; 
												
				t_v_from_core[free_port]     <= 1; 
			end
			
			default: mState <= IDLE;
		endcase 
	end 
end 

/*
// Debugging 
 always @ (posedge clock) begin 
	$display ("-----------------------------RA Packetizer Network %d-------------------------------------", core_ID);  
	$display ("C State [%d]\t\t| P State [%d]", cState, pState);
	$display ("M State [%d]\t\t| free_vc[%b]\t\t| free_port  [%b]\t| found [%b]", mState, free_vc, free_port , found);
	$display ("");
	for(index= 0; index < IN_PORTS; index = index+1) begin
		if(cache_traffic[index] | c_WEn[index]) begin 
			$display ("Write [%b]\t\t| vc [%d]\t| flit [%h]", c_WEn[index], c_in_vc [index] , c_in_flit[index]);
		end  
		if((cState == READ_DELAY) | (cState == READ) | c_REn[index] | c_valid[index]) begin 
			$display ("Read [%b]\t\t| vc [%d]\t\t| flit [%h]\t| vc-out [%b] \t\t| valid [%b]", c_REn[index], c_read_vc [index] , c_out_flit[index], c_out_vc[index], c_valid[index]);
		end 
	end
	$display ("Cur_vc[%b]\t\t| Cur_port  [%b]\t| c_empty [%b]", c_cur_vc, c_cur_port , c_empty[c_cur_port][c_cur_vc]);		
	$display ("Port to send flit [%h]", c_out_flit[c_cur_port]);
	$display ("Port Valid [%b] ", c_valid[c_cur_port]);
	$display (""); 
	$display ("C to send flit [%h]", c_flit_to_send);
	$display ("C Valid [%b] ", cv_send_flit);
	$display ("0-C to send flit [%h]", c_flit_to_send0);
	$display ("0-C Valid [%b] ", cv_send_flit0);
	$display ("1-C to send flit [%h]", c_flit_to_send1);
	$display ("1-C Valid [%b] ", cv_send_flit1);
	$display ("C Ready [%b]\t| Sent [%b]", c_ready, c_sent);
	$display ("C received flit [%h]", c_flit_received);
	$display ("C rec Valid [%b]", cv_rec_flit);
	$display ("");
	$display ("P to send flit [%h]", p_flit_to_send);
	$display ("P Valid [%b] ", pv_send_flit);
	$display ("0-P to send flit [%h]", p_flit_to_send0);
	$display ("0-P Valid [%b] ", pv_send_flit0);
	$display ("1-P to send flit [%h]", p_flit_to_send1);
	$display ("1-P Valid [%b] ", pv_send_flit1);
	$display ("");
	$display ("P received flit [%h]", p_flit_received);
	$display ("P rec Valid [%b]", pv_rec_flit);
	$display ("To core process [%b]\t| Rec All [%b]\t| P Ready [%b]\t| Sent [%b]", to_core_process, received_all[p_cur_port], p_ready, p_sent);
	for(index= 0; index < IN_PORTS; index = index+1) begin
		$display ("Port[%d]\t\t| in flit0 [%h]\t| En0 [%b]", index, p_in_flit0[index], p_En0[index]);
		$display ("Port[%d]\t\t| in flit1 [%h]\t| En1 [%b]", index, p_in_flit1[index], p_En1[index]);
	end
	$display (""); 
	$display ("P To Send [%b]\t\t| C To Send [%b]", p_to_send_ready, c_to_send_ready);
	$display ("");
	$display ("From Core Flit [%h] ", from_core_flit);
	$display ("From Core Valid [%b] ", v_from_core);
	$display ("From Core Empty [%b]\t| From Core Full [%b] ", from_core_empty, from_core_full);
	$display ("To Core Flit [%h] ", to_core_flit);
	$display ("To Core Valid [%b] ", v_to_core);
	$display ("To Core Empty [%b]\t| To Core Full [%b] ", to_core_empty, to_core_full);
	$display ("-----------------------------------------------------------------------------------------");
 end 	
 //*/

 
endmodule