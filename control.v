`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.06.2020 16:10:47
// Design Name: 
// Module Name: control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "parameters.vh"

module control(
    clk, din_ld, din_pe, din_wb, inst, dout, alumode, inmode, opmode, cea2, ceb2, usemult
    );
    
input clk;
input [`DATA_WIDTH*2-1:0] din_ld; // 32-bit data
input [`DATA_WIDTH*2-1:0] din_pe; // 32-bit data
input [`DATA_WIDTH*2-1:0] din_wb; // 32-bit data
input [`INST_WIDTH-1:0] inst; // 64-bit instruction

output [`DATA_WIDTH*2-1:0] dout; // 32-bit
output [`ALUMODE_WIDTH*4-1:0] alumode; // 4-bit * 4
output [`INMODE_WIDTH*4-1:0] inmode;   // 5-bit * 4 
output [`OPMODE_WIDTH*4-1:0] opmode;   // 7-bit * 4
output [3:0] cea2;    // 1-bit * 4
output [3:0] ceb2;    // 1-bit * 4
output [3:0] usemult; // 1-bit * 4

wire [1:0] sel;
assign sel = inst[`INST_WIDTH-1:`INST_WIDTH-2]; // The most significant 2-bit select input of the PE

reg [`DATA_WIDTH*2-1:0] dout; // 32-bit

//always @ (*) 
always @ (posedge clk) 
case (sel)
    2'b00:   dout <= din_ld; // load data
    2'b01:   dout <= din_pe; // shift data
    2'b10:   dout <= din_wb; // write back
    default: dout <= 0;
endcase
 
/***************** INSTRUCTION DECODE***************/	 
wire[2:0] opcode;
assign opcode = inst[26:24];

reg [`ALUMODE_WIDTH*4-1:0] alumode = 0; // 4-bit * 4
reg [`INMODE_WIDTH*4-1:0]  inmode = 0;  // 5-bit * 4
reg [`OPMODE_WIDTH*4-1:0]  opmode = 0;  // 7-bit * 4
reg [3:0]  cea2 =  0;
reg [3:0]  ceb2 = 0;
reg [3:0]  usemult = 0;

//always@ (*)
always @ (posedge clk) 
case (opcode[2:0])
/*`ADD*/ 3'b001: begin 
	            alumode <= 16'b0000_0000_0000_0000; 
	            inmode <= 20'b00000_00000_00000_00000; 
	            opmode <= 28'b0110011_0110011_0110011_0110011; 
	            cea2 <= 4'b1111; 
	            ceb2 <= 4'b1111; 
	            usemult <= 4'b0000; 
             end
/*`SUB*/ 3'b010: begin 
	            alumode <= 16'b0011_0011_0011_0011; 
	            inmode <= 20'b00000_00000_00000_00000; 
	            opmode <= 28'b0110011_0110011_0110011_0110011; 
	            cea2 <= 4'b1111; 
	            ceb2 <= 4'b1111; 
	            usemult <= 4'b0000; 
	         end
/*`MUL*/ 3'b011: begin 
	            alumode <= 16'b0000_0000_0000_0000; 
	            inmode <= 20'b10001_10001_10001_10001; 
	            opmode <= 28'b0000101_0000101_0000101_0000101; 
	            cea2 <= 4'b0000; 
	            ceb2 <= 4'b0000; 
	            usemult <= 4'b1111; 
	         end
/*`ADDI*/ 3'b101: begin 
	            alumode <= 16'b0000_0000_0000_0000; 
	            inmode <= 20'b00000_00000_00000_00000; 
	            opmode <= 28'b0110011_0110011_0110011_0110011; 
	            cea2 <= 4'b1111; ceb2 <= 4'b1111; usemult <= 4'b0000; 
	          end
/*`SUBI*/ 3'b110: begin 
	            alumode <= 16'b0011_0011_0011_0011; 
	            inmode <= 20'b00000_00000_00000_00000; 
	            opmode <= 28'b0110011_0110011_0110011_0110011; 
	            cea2 <= 4'b1111; ceb2 <= 4'b1111; usemult <= 4'b0000; 
	          end
/*`MULI*/ 3'b111: begin 
	            alumode <= 16'b0000_0000_0000_0000; 
	            inmode <= 20'b10001_10001_10001_10001; 
	            opmode <= 28'b0000101_0000101_0000101_0000101; 
	            cea2 <= 4'b0000; ceb2 <= 4'b0000; usemult <= 4'b1111; 
	          end
/*`LOAD*/ default: begin 
	            alumode <= 16'b0000_0000_0000_0000; 
	            inmode <= 20'b00000_00000_00000_00000; 
	            opmode <= 28'b0000000_0000000_0000000_0000000; 
	            cea2 <= 4'b0000; ceb2 <= 4'b0000; usemult <= 4'b0000; 
	          end
endcase

    
endmodule
