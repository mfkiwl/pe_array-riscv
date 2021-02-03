`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 31.05.2020 13:37:06
// Design Name: 
// Module Name: pe
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Single PE with data forwarding support
// 
// Dependencies: 224 LUTs, 295 FFs, 1.5 BRAMs, 4 DSPs (meet 600MHz)
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "parameters.vh"

module pe( 
    clk, rst, din_pe_v, din_pe, din_tx_v, din_tx, inst_in_v, inst_in,  
    dout_pe_v, dout_pe, dout_tx_v, dout_tx
    );
    
input  clk;
input  rst;
input  din_pe_v;
input  [`DATA_WIDTH*2-1:0] din_pe;
input  din_tx_v;
input  [`DATA_WIDTH*2-1:0] din_tx;
input  inst_in_v;
input  [`INST_WIDTH-1:0] inst_in;
//input  alpha_v;

output reg dout_pe_v;
output reg [`DATA_WIDTH*2-1:0] dout_pe;
output reg dout_tx_v;
output reg [`DATA_WIDTH*2-1:0] dout_tx;


/*** wires for module connection ***/
wire inst_pc_v;
wire [`INST_WIDTH-1:0] inst_pc; // instructions triggered by program counter

wire [`ALUMODE_WIDTH*4-1:0] alumode; // 4-bit * 4
wire [`INMODE_WIDTH*4-1:0] inmode;   // 5-bit * 4 
wire [`OPMODE_WIDTH*4-1:0] opmode;   // 7-bit * 4
wire [3:0] cea2;    // 1-bit * 4
wire [3:0] ceb2;    // 1-bit * 4
wire [3:0] usemult; // 1-bit * 4

wire [`DATA_WIDTH*2-1:0] dout_ctrl;
wire [`DATA_WIDTH*2-1:0] rdata0, rdata1; 
wire [`DATA_WIDTH*2-1:0] dout_alu;
wire dout_alu_v;

//wire tx_flag;
//assign tx_flag = dout_alu_v ? 1 : 0; // this will be changed later

always @ (posedge clk) begin
    if (tx_v) begin // tx_flag // partial alpha forward to next PE
        dout_tx_v <= 1;
        dout_tx   <= dout_alu;
    end
    else begin
        dout_tx_v <= 0;
        dout_tx   <= 32'hxxxxxxxx; 
    end
    if (alpha_v) begin // output alpha (alpha_v = 1 when in last iteration)
        dout_pe_v <= 1;
        dout_pe   <= dout_alu; 
    end
end

//parameter DELAY = 14;
//reg shift_v = 0; 
//reg [DELAY-1:0] shift_reg_v = 0;
//always @ (posedge clk) begin 
//    shift_reg_v <= {shift_reg_v[DELAY-2:0], shift_v};
//end
//wire shift_v_d;
//assign shift_v_d = shift_reg_v[DELAY-1]; // valid signal for shift registers

// Instruction Memory
inst_mem IMEM(
    .clk(clk), 
    .rst(rst), 
    .inst_in_v(inst_in_v), 
    .inst_in(inst_in), 
    .inst_out_v(inst_pc_v),
    .inst_out(inst_pc) // instructions triggered by program counter
    ); 

reg [2:0] opcode;
always @ (posedge clk) 
    opcode <= inst_pc[31:29]; 

// Control Logics & Decoder
control CTRL(
    .clk(clk),
    .din_ld_v(din_pe_v), 
    .din_ld(din_pe), 
    .din_wb(dout_alu), 
    .inst_v(inst_pc_v),
    .opcode(opcode), 
//    .inst(inst_pc), // instructions triggered by program counter
    .dout_v(dout_alu_v),
    .dout(dout_ctrl), // data output of the controller
    .alumode(alumode), 
    .inmode(inmode), 
    .opmode(opmode), 
    .cea2(cea2), 
    .ceb2(ceb2), 
    .usemult(usemult)
    );

reg dmem_re; // register write/read enable signal to synchronize with dout_ctrl

always @ (posedge clk) begin
    if (inst_pc_v) begin
        dmem_re <= 1; // inst_pc[`INST_WIDTH-5]; 
    end    
    else begin
        dmem_re <= 0;
    end 
end

wire dout_ctrl_v;
assign dout_ctrl_v = load_v | dout_alu_v;

// Data Memory
data_mem DMEM(
    .clk(clk), 
    .rst(rst), 
    .wea(dout_ctrl_v), // valid of dout_ctrl
    .web(din_tx_v), // valid of din_tx
    .dina(dout_ctrl), // din_comp
    .dinb(din_tx), // data transmitted from previous PE
    .wben(dout_alu_v), 
    .rden(dmem_re), // re
    .inst_v(inst_pc_v),
    .inst(inst_pc), // instructions triggered by program counter
    .douta(rdata0),
    .doutb(rdata1)
    );

wire [`DATA_WIDTH*2-1:0] dout_rom;
reg en;
reg [`WN_ADDR_WIDTH-1:0] addr; 
always @ (posedge clk) begin
    if (inst_pc[`INST_WIDTH-4]) // bit 28
        en <= 1'b1;
    else 
        en <= 1'b0;
    addr <= inst_pc[27:24];
end

// ROM for Twiddle Factors
const_rom ROM(
    .clk(clk), 
    .en(en), 
    .addr(addr), 
    .data_out(dout_rom)
    );

/*** Data Memory Feedback Input Map ***/
reg  three_operand, three_operand_d1, three_operand_d2;
always @ (posedge clk) begin
    if (inst_pc[31:29] == 3'b101 | inst_pc[31:29] == 3'b110)
        three_operand <= 1; 
    else 
        three_operand <= 0; 
    three_operand_d1 <= three_operand; 
    three_operand_d2 <= three_operand_d1; // ROM requires 3-stage pipeline
end    
//wire three_operand; 
//assign three_operand = (inst_pc[31:29] == 3'b101 | inst_pc[31:29] == 3'b110) ? 1 : 0; 
wire [`DATA_WIDTH*2-1:0] din_1, din_2, din_3; 
assign din_1 = three_operand_d2 ? dout_rom : rdata0;
assign din_2 = rdata1;
assign din_3 = three_operand_d2 ? rdata0 : 0;

// ALU for Complex Data
complex_alu ALU( 
    .clk(clk), 
    .rst(rst), 
    .opcode(opcode), 
    .alumode(alumode), 
    .inmode(inmode), 
    .opmode(opmode), 
    .cea2(cea2), 
    .ceb2(ceb2), 
    .usemult(usemult), 
    .din_1(din_1), // rdata0
    .din_2(din_2), // rdata1
    .din_3(din_3), // dout_rom
    .dout(dout_alu) 
    );    

/*** Moore state machine for data transmit & alpha output ***/
   parameter IDLE = 3'b000;
   parameter LOAD = 3'b001;
   parameter COMPUTE = 3'b010;
   parameter TRANSMIT = 3'b011;
   parameter SHIFT = 3'b100;
   parameter OUTPUT = 3'b101;

   reg load_v = 0; 
   reg cmpt_v = 0;
   reg tx_v = 0;
   reg shift_v = 0;
   reg alpha_v = 0;
   
   // counters to control the state machine
   reg [6:0] iter_cnt = 0; // iteration
   reg [4:0] load_cnt = 0; // load
   reg [7:0] cmpt_cnt = 0; // compute
   reg [2:0] tx_cnt = 0;  // transmit
   reg [4:0] shift_cnt = 0; // shift
   reg [2:0] out_cnt = 0; // output
   reg [2:0] state = IDLE; // initial state

   always @(posedge clk)
      if (rst) begin
         state <= IDLE;
      end
      else
         case (state)
            IDLE : begin
               if (din_pe_v)
                  state <= LOAD;
               else
                  state <= IDLE;
            end
            LOAD : begin
               if (load_cnt == `LOAD_NUM-1) begin
                  state <= COMPUTE;
                  load_cnt <= 0;
               end
               else begin
                  state <= LOAD;
                  load_cnt <= load_cnt + 1'b1;
               end
               load_v <= 1;
               cmpt_v <= 0;
               tx_v <= 0;
               shift_v <= 0;
               alpha_v <= 0;
            end
            COMPUTE : begin
               if (cmpt_cnt == `INST_NUM-1 && iter_cnt == `ITER_NUM-1) begin
                  state <= OUTPUT;
                  cmpt_cnt <= 0;
                  iter_cnt <= 0;
               end
               else if (cmpt_cnt == `INST_NUM-1) begin
                  state <= TRANSMIT;
                  cmpt_cnt <= 0;
               end
               else begin
                  state <= COMPUTE;
                  cmpt_cnt <= cmpt_cnt + 1'b1;
               end
               load_v <= 0;
               cmpt_v <= 1;
               tx_v <= 0;
               shift_v <= 0;
               alpha_v <= 0;
            end
            TRANSMIT : begin
               if (tx_cnt == `TX_NUM-1) begin
                  state <= SHIFT;
                  tx_cnt <= 0;
               end
               else begin
                  state <= TRANSMIT;
                  tx_cnt <= tx_cnt + 1'b1;
               end
               load_v <= 0;
               cmpt_v <= 0;
               tx_v <= 1;
               shift_v <= 0;
               alpha_v <= 0;
            end
            SHIFT : begin
               if (shift_cnt == `SHIFT_NUM-1) begin
                  state <= LOAD;
                  shift_cnt <= 0;
               end
               else begin
                  state <= SHIFT;
                  shift_cnt <= shift_cnt + 1'b1;
               end 
               load_v <= 0;
               cmpt_v <= 0;
               tx_v <= 0;
               shift_v <= 1;
               alpha_v <= 0;
            end
            OUTPUT : begin
               if (out_cnt == `ALPHA_NUM-1) begin
                  state <= IDLE;
                  out_cnt <= 0; 
               end
               else begin
                  state <= OUTPUT;
                  out_cnt <= out_cnt + 1'b1;
               end 
               load_v <= 0;
               cmpt_v <= 0;
               tx_v <= 0;
               shift_v <= 0;
               alpha_v <= 1;
            end
         endcase
   
    
endmodule